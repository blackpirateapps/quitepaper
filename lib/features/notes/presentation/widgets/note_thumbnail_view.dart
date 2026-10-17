import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/documents/document_provider.dart';
import '../../../../core/pdf/pdf_page_renderer.dart';
import '../../domain/note_metadata_extractor.dart';

/// High-performance in-memory LRU cache and request deduplicator for note list thumbnails.
///
/// Ensures smooth 60fps/120fps scrolling by:
/// 1. Caching rasterized PDF first-page PNGs and decrypted image assets in RAM.
/// 2. Deduplicating concurrent in-flight disk read/decryption/rasterization requests.
/// 3. Providing synchronous instant access for previously loaded items.
abstract final class NoteThumbnailCache {
  static const int maxEntries = 500;
  static final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  static final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  /// Retrieves cached thumbnail bytes if present, refreshing LRU position.
  static Uint8List? get(String uri) {
    if (uri.isEmpty) return null;
    final cached = _cache.remove(uri);
    if (cached != null) {
      _cache[uri] = cached;
      return cached;
    }
    return null;
  }

  /// Whether the cache contains a thumbnail for [uri].
  static bool containsKey(String uri) => _cache.containsKey(uri);

  /// Stores thumbnail bytes in the LRU cache.
  static void put(String uri, Uint8List bytes) {
    if (uri.isEmpty || bytes.isEmpty) return;
    _cache.remove(uri);
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[uri] = bytes;
  }

  /// Deduplicates in-flight thumbnail resolution for [uri].
  ///
  /// If a load is already in-flight for this URI, returns the existing Future.
  /// Otherwise executes [loader], caches the result on success, and cleans up.
  static Future<Uint8List?> resolve(
    String uri,
    Future<Uint8List?> Function() loader,
  ) {
    if (uri.isEmpty) return Future.value(null);

    final cached = get(uri);
    if (cached != null) return Future.value(cached);

    final existing = _inFlight[uri];
    if (existing != null) return existing;

    final future = loader().then((result) {
      if (result != null && result.isNotEmpty) {
        put(uri, result);
      }
      return result;
    }).whenComplete(() {
      _inFlight.remove(uri);
    });

    _inFlight[uri] = future;
    return future;
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
      // Trigger background resolution
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

  /// Number of cached items in RAM.
  @visibleForTesting
  static int get length => _cache.length;

  /// Clears in-memory thumbnail cache (for tests and memory management).
  static void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

/// Clears in-memory thumbnail caches (for tests and memory management).
@visibleForTesting
void clearThumbnailCaches() {
  NoteThumbnailCache.clear();
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
