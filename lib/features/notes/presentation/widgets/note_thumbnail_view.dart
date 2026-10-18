import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/documents/document_provider.dart';
import '../../../../core/pdf/pdf_page_renderer.dart';
import '../../../../core/storage/app_storage_path_resolver.dart';
import '../../domain/note_metadata_extractor.dart';

/// High-performance two-tiered (L1 RAM + L2 Persistent Disk) cache and request deduplicator
/// for note list thumbnails.
///
/// Ensures instant cold starts and smooth 60fps/120fps scrolling by:
/// 1. Caching rasterized PDF first-page PNGs and decrypted image assets in RAM (L1) and on disk (L2).
/// 2. Persisting thumbnails across app restarts so previews never have to be re-rasterized or re-decrypted.
/// 3. Deduplicating concurrent in-flight disk read/decryption/rasterization requests.
/// 4. Providing synchronous instant access for items already in memory.
abstract final class NoteThumbnailCache {
  static const int maxEntries = 500;
  static final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  static final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  /// Optional custom directory for tests or overrides.
  @visibleForTesting
  static Directory? customDirectory;

  /// Resolves the app-private directory for persisted thumbnails on disk.
  static Future<Directory> getThumbnailsDirectory() async {
    if (customDirectory != null) {
      if (!await customDirectory!.exists()) {
        await customDirectory!.create(recursive: true);
      }
      return customDirectory!;
    }
    final dataDir = await AppStoragePathResolver.getDataDirectory();
    final dir = Directory(p.join(dataDir.path, 'thumbnails'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Hashes a URI into a deterministic filesystem-safe filename.
  static String getDiskFileName(String uri) {
    final digest = sha256.convert(utf8.encode(uri.trim())).toString();
    return '$digest.thumb';
  }

  /// Retrieves cached thumbnail bytes if present in L1 RAM, refreshing LRU position.
  static Uint8List? get(String uri) {
    if (uri.isEmpty) return null;
    final cached = _cache.remove(uri);
    if (cached != null) {
      _cache[uri] = cached;
      return cached;
    }
    return null;
  }

  /// Whether the L1 in-memory cache contains a thumbnail for [uri].
  static bool containsKey(String uri) => _cache.containsKey(uri);

  /// Stores thumbnail bytes in the L1 RAM cache and persists to L2 disk cache.
  static Future<void> put(String uri, Uint8List bytes, {bool persistToDisk = true}) async {
    if (uri.isEmpty || bytes.isEmpty) return;
    _cache.remove(uri);
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[uri] = bytes;

    if (persistToDisk) {
      await _writeToDisk(uri, bytes);
    }
  }

  /// Asynchronously writes thumbnail bytes to persistent disk cache.
  static Future<void> _writeToDisk(String uri, Uint8List bytes) async {
    try {
      final dir = await getThumbnailsDirectory();
      final fileName = getDiskFileName(uri);
      final file = File(p.join(dir.path, fileName));
      final tmpFile = File(p.join(dir.path, '$fileName.tmp'));
      await tmpFile.writeAsBytes(bytes, flush: true);
      if (await tmpFile.exists()) {
        await tmpFile.rename(file.path);
      }
    } catch (_) {
      // Non-fatal if disk write fails
    }
  }

  /// Asynchronously reads thumbnail bytes from persistent disk cache.
  static Future<Uint8List?> readFromDisk(String uri) async {
    try {
      final dir = await getThumbnailsDirectory();
      final fileName = getDiskFileName(uri);
      final file = File(p.join(dir.path, fileName));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        } else {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Ignore read errors
    }
    return null;
  }

  /// Deduplicates in-flight thumbnail resolution for [uri].
  ///
  /// Execution order:
  /// 1. Synchronous L1 RAM cache hit -> returns immediately.
  /// 2. Existing in-flight Future -> joins existing request.
  /// 3. L2 Persistent Disk cache hit -> loads from disk, promotes to RAM, returns.
  /// 4. Cache miss -> runs [loader], stores result in RAM and disk, returns.
  static Future<Uint8List?> resolve(
    String uri,
    Future<Uint8List?> Function() loader,
  ) {
    if (uri.isEmpty) return Future.value(null);

    final cached = get(uri);
    if (cached != null) return Future.value(cached);

    final existing = _inFlight[uri];
    if (existing != null) return existing;

    final future = _resolveInternal(uri, loader);
    _inFlight[uri] = future;
    return future;
  }

  static Future<Uint8List?> _resolveInternal(
    String uri,
    Future<Uint8List?> Function() loader,
  ) async {
    try {
      // 1. Check L2 persistent disk cache
      final diskBytes = await readFromDisk(uri);
      if (diskBytes != null && diskBytes.isNotEmpty) {
        await put(uri, diskBytes, persistToDisk: false);
        return diskBytes;
      }

      // 2. Not cached on disk: execute loader and persist
      final result = await loader();
      if (result != null && result.isNotEmpty) {
        await put(uri, result, persistToDisk: true);
      }
      return result;
    } finally {
      _inFlight.remove(uri);
    }
  }

  /// Pre-warms a list of thumbnail URIs in the background without blocking the UI.
  static void prewarm({
    required WidgetRef ref,
    required List<ThumbnailData> thumbnails,
    int maxItems = 25,
  }) {
    final count = thumbnails.length > maxItems ? maxItems : thumbnails.length;
    for (var i = 0; i < count; i++) {
      final item = thumbnails[i];
      final uri = item.uri.trim();
      if (uri.isEmpty || containsKey(uri) || _inFlight.containsKey(uri)) {
        continue;
      }
      if (item.kind == ThumbnailKind.textFile) {
        continue;
      }
      // Trigger background resolution (which checks disk cache first!)
      resolve(uri, () => _loadThumbnailBytes(ref, uri, item.kind));
    }
  }

  /// Helper to load thumbnail bytes by URI and kind.
  static Future<Uint8List?> _loadThumbnailBytes(
    WidgetRef ref,
    String uri,
    ThumbnailKind kind,
  ) async {
    try {
      if (kind == ThumbnailKind.pdf) {
        Uint8List? pdfBytes;
        if (uri.startsWith('qp://document/')) {
          final docId = uri.replaceFirst('qp://document/', '').trim();
          final docService = ref.read(documentServiceProvider);
          final res = await docService.resolveDocument(docId);
          if (res.isAvailable && res.data != null) {
            pdfBytes = res.data!.pdfBytes;
          }
        } else if (uri.startsWith('qp://asset/')) {
          final assetId = uri.replaceFirst('qp://asset/', '').trim();
          final attachmentService = ref.read(attachmentServiceProvider);
          final res = await attachmentService.resolveAsset(
            assetId,
            variant: 'original',
          );
          if (res.isAvailable && res.data != null) {
            pdfBytes = res.data;
          }
        }

        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          await for (final page in Printing.raster(
            pdfBytes,
            pages: const [0],
            dpi: PdfRasterPolicy.safeDpi(pdfBytes, 72.0),
          )) {
            return await page.toPng();
          }
        }
        return null;
      }

      if (kind == ThumbnailKind.image && uri.startsWith('qp://asset/')) {
        final assetId = uri.replaceFirst('qp://asset/', '').trim();
        if (assetId.isEmpty) return null;

        final service = ref.read(attachmentServiceProvider);
        final resolution = await service.resolveAsset(
          assetId,
          variant: 'original',
        );
        if (resolution.isAvailable && resolution.data != null) {
          return resolution.data!;
        }
      }
    } catch (_) {
      // Ignore background errors
    }
    return null;
  }

  /// Evicts a thumbnail from L1 memory and L2 disk caches.
  static Future<void> evict(String uri) async {
    _cache.remove(uri);
    try {
      final dir = await getThumbnailsDirectory();
      final fileName = getDiskFileName(uri);
      final file = File(p.join(dir.path, fileName));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Number of cached items in RAM.
  @visibleForTesting
  static int get length => _cache.length;

  /// Clears in-memory thumbnail cache, and optionally purges disk cache.
  static void clear({bool clearDisk = true}) {
    _cache.clear();
    _inFlight.clear();
    if (clearDisk) {
      getThumbnailsDirectory().then((dir) async {
        if (await dir.exists()) {
          try {
            await for (final entity in dir.list(recursive: false)) {
              if (entity is File &&
                  (entity.path.endsWith('.thumb') ||
                      entity.path.endsWith('.tmp'))) {
                await entity.delete();
              }
            }
          } catch (_) {}
        }
      }).catchError((_) {});
    }
  }

  /// Synchronously clears in-memory cache and asynchronously purges disk cache.
  @visibleForTesting
  static Future<void> purgeDiskCache() async {
    try {
      final dir = await getThumbnailsDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File &&
              (entity.path.endsWith('.thumb') ||
                  entity.path.endsWith('.tmp'))) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }
}

/// Clears in-memory thumbnail caches (for tests and memory management).
@visibleForTesting
void clearThumbnailCaches({bool clearDisk = true}) {
  NoteThumbnailCache.clear(clearDisk: clearDisk);
}

/// Compact, non-blocking image, PDF, and text file thumbnail widget for note list tiles.
///
/// Uses [AutomaticKeepAliveClientMixin] to prevent rebuilding while scrolling and
/// constrains image decode dimensions ([cacheWidth]/[cacheHeight]) to prevent
/// memory bloat and UI thread jank.
class NoteThumbnailView extends ConsumerStatefulWidget {
  const NoteThumbnailView({
    super.key,
    this.thumbnailData,
    this.thumbnailUri,
    this.size = 48.0,
  });

  final ThumbnailData? thumbnailData;
  final String? thumbnailUri;
  final double size;

  @override
  ConsumerState<NoteThumbnailView> createState() => _NoteThumbnailViewState();
}

class _NoteThumbnailViewState extends ConsumerState<NoteThumbnailView>
    with AutomaticKeepAliveClientMixin<NoteThumbnailView> {
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  String get _effectiveUri =>
      widget.thumbnailData?.uri ?? widget.thumbnailUri?.trim() ?? '';

  ThumbnailKind get _effectiveKind {
    if (widget.thumbnailData != null) return widget.thumbnailData!.kind;
    final uri = _effectiveUri;
    if (uri.startsWith('qp://document/') ||
        uri.toLowerCase().contains('.pdf')) {
      return ThumbnailKind.pdf;
    }
    return ThumbnailKind.image;
  }

  @override
  void initState() {
    super.initState();
    final uri = _effectiveUri;
    final cached = NoteThumbnailCache.get(uri);
    if (cached != null) {
      _imageBytes = cached;
    } else {
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(NoteThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUri = oldWidget.thumbnailData?.uri ?? oldWidget.thumbnailUri;
    if (oldUri != _effectiveUri) {
      final uri = _effectiveUri;
      final cached = NoteThumbnailCache.get(uri);
      if (cached != null) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      } else {
        _loadThumbnail();
      }
    }
  }

  Future<void> _loadThumbnail() async {
    final uri = _effectiveUri;
    if (uri.isEmpty) return;

    final kind = _effectiveKind;

    // 1. Text File Thumbnails are rendered procedurally
    if (kind == ThumbnailKind.textFile) {
      return;
    }

    // Check synchronous cache first
    final cached = NoteThumbnailCache.get(uri);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. PDF Document Thumbnail
    if (kind == ThumbnailKind.pdf) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final pngBytes = await NoteThumbnailCache.resolve(uri, () async {
        try {
          Uint8List? pdfBytes;
          if (uri.startsWith('qp://document/')) {
            final docId = uri.replaceFirst('qp://document/', '').trim();
            final docService = ref.read(documentServiceProvider);
            final res = await docService.resolveDocument(docId);
            if (res.isAvailable && res.data != null) {
              pdfBytes = res.data!.pdfBytes;
            }
          } else if (uri.startsWith('qp://asset/')) {
            final assetId = uri.replaceFirst('qp://asset/', '').trim();
            final attachmentService = ref.read(attachmentServiceProvider);
            final res = await attachmentService.resolveAsset(
              assetId,
              variant: 'original',
            );
            if (res.isAvailable && res.data != null) {
              pdfBytes = res.data;
            }
          }

          if (pdfBytes != null && pdfBytes.isNotEmpty) {
            await for (final page in Printing.raster(
              pdfBytes,
              pages: const [0],
              dpi: PdfRasterPolicy.safeDpi(pdfBytes, 72.0),
            )) {
              return await page.toPng();
            }
          }
        } catch (_) {}
        return null;
      });

      if (mounted) {
        setState(() {
          _imageBytes = pngBytes;
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Image Thumbnail
    if (!uri.startsWith('qp://asset/')) {
      // Network image is handled by Image.network
      return;
    }

    final assetId = uri.replaceFirst('qp://asset/', '').trim();
    if (assetId.isEmpty) return;

    final imageBytes = await NoteThumbnailCache.resolve(uri, () async {
      try {
        final service = ref.read(attachmentServiceProvider);
        final resolution = await service.resolveAsset(
          assetId,
          variant: 'original',
        );
        if (resolution.isAvailable && resolution.data != null) {
          return resolution.data!;
        }
      } catch (_) {}
      return null;
    });

    if (mounted) {
      setState(() {
        _imageBytes = imageBytes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.appColors;
    final uri = _effectiveUri;
    final kind = _effectiveKind;
    final label =
        widget.thumbnailData?.label ??
        (kind == ThumbnailKind.pdf ? 'PDF' : null);

    // Calculate optimal downscaled decode size based on display pixel ratio.
    // Constraining decoding to ~120-144px avoids decoding 12MP-48MP full camera images
    // into uncompressed 48MB GPU textures, preventing image cache evictions and frame drops.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.5;
    final decodeSize = (widget.size * dpr).round().clamp(96, 240);

    Widget content;

    if (kind == ThumbnailKind.textFile) {
      content = _buildTextFileSheet(colors, label ?? 'TXT');
    } else if (kind == ThumbnailKind.pdf && _imageBytes != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _imageBytes!,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            cacheWidth: decodeSize,
            cacheHeight: decodeSize,
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: _buildMiniBadge(colors, 'PDF'),
          ),
        ],
      );
    } else if (kind == ThumbnailKind.pdf && _isLoading) {
      content = _buildPlaceholder(
        colors,
        icon: Icons.picture_as_pdf_outlined,
        label: 'PDF',
      );
    } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
      content = Image.network(
        uri,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colors),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder(colors);
        },
      );
    } else if (_imageBytes != null) {
      content = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
      );
    } else {
      content = _buildPlaceholder(
        colors,
        icon: kind == ThumbnailKind.pdf
            ? Icons.picture_as_pdf_outlined
            : Icons.image_outlined,
        label: label,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 0.8,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildTextFileSheet(AppColors colors, String label) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(5.0),
      child: Stack(
        children: [
          // Simulated text lines
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 2.0,
                width: widget.size * 0.75,
                color: colors.textTertiary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 3.5),
              Container(
                height: 2.0,
                width: widget.size * 0.6,
                color: colors.textTertiary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 3.5),
              Container(
                height: 2.0,
                width: widget.size * 0.45,
                color: colors.textTertiary.withValues(alpha: 0.25),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildMiniBadge(colors, label),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(AppColors colors, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.9),
          width: 0.6,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: colors.textPrimary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    AppColors colors, {
    IconData icon = Icons.image_outlined,
    String? label,
  }) {
    return Container(
      color: colors.surfaceSubtle,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: colors.textTertiary.withValues(alpha: 0.5),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 9.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
