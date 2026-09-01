import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/documents/document_provider.dart';
import '../../domain/note_metadata_extractor.dart';

/// In-memory cache for rasterized PDF page-0 thumbnails to ensure smooth 60fps scrolling.
final Map<String, Uint8List> _pdfThumbnailCache = {};

/// In-memory cache for resolved encrypted local asset thumbnails to eliminate disk I/O on scroll.
final Map<String, Uint8List> _assetThumbnailCache = {};

/// Clears in-memory thumbnail caches (for tests and memory management).
@visibleForTesting
void clearThumbnailCaches() {
  _pdfThumbnailCache.clear();
  _assetThumbnailCache.clear();
}

/// Compact, non-blocking image, PDF, and text file thumbnail widget for note list tiles.
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

class _NoteThumbnailViewState extends ConsumerState<NoteThumbnailView> {
  Uint8List? _imageBytes;
  bool _isLoading = false;

  String get _effectiveUri =>
      widget.thumbnailData?.uri ?? widget.thumbnailUri?.trim() ?? '';

  ThumbnailKind get _effectiveKind {
    if (widget.thumbnailData != null) return widget.thumbnailData!.kind;
    final uri = _effectiveUri;
    if (uri.startsWith('qp://document/') || uri.toLowerCase().contains('.pdf')) {
      return ThumbnailKind.pdf;
    }
    return ThumbnailKind.image;
  }

  @override
  void initState() {
    super.initState();
    final uri = _effectiveUri;
    final kind = _effectiveKind;
    if (kind == ThumbnailKind.pdf && _pdfThumbnailCache.containsKey(uri)) {
      _imageBytes = _pdfThumbnailCache[uri];
    } else if (kind == ThumbnailKind.image && _assetThumbnailCache.containsKey(uri)) {
      _imageBytes = _assetThumbnailCache[uri];
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
      final kind = _effectiveKind;
      if (kind == ThumbnailKind.pdf && _pdfThumbnailCache.containsKey(uri)) {
        setState(() {
          _imageBytes = _pdfThumbnailCache[uri];
          _isLoading = false;
        });
      } else if (kind == ThumbnailKind.image && _assetThumbnailCache.containsKey(uri)) {
        setState(() {
          _imageBytes = _assetThumbnailCache[uri];
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

    // 2. PDF Document Thumbnail
    if (kind == ThumbnailKind.pdf) {
      // Check cache first
      if (_pdfThumbnailCache.containsKey(uri)) {
        if (mounted) {
          setState(() {
            _imageBytes = _pdfThumbnailCache[uri];
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = true);

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
          final res = await attachmentService.resolveAsset(assetId, variant: 'original');
          if (res.isAvailable && res.data != null) {
            pdfBytes = res.data;
          }
        }

        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          await for (final page in Printing.raster(pdfBytes, pages: const [0], dpi: 72.0)) {
            final png = await page.toPng();
            _pdfThumbnailCache[uri] = png;
            if (mounted) {
              setState(() {
                _imageBytes = png;
                _isLoading = false;
              });
            }
            break;
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // 3. Image Thumbnail
    if (!uri.startsWith('qp://asset/')) {
      // Network image is handled by Image.network
      return;
    }

    // Check memory cache first
    if (_assetThumbnailCache.containsKey(uri)) {
      if (mounted) {
        setState(() {
          _imageBytes = _assetThumbnailCache[uri];
        });
      }
      return;
    }

    final assetId = uri.replaceFirst('qp://asset/', '').trim();
    if (assetId.isEmpty) return;

    try {
      final service = ref.read(attachmentServiceProvider);
      final resolution = await service.resolveAsset(assetId, variant: 'thumbnail');

      if (!mounted) return;
      if (resolution.isAvailable && resolution.data != null) {
        _assetThumbnailCache[uri] = resolution.data!;
        setState(() {
          _imageBytes = resolution.data;
        });
      } else {
        // Fallback to original variant
        final origResolution = await service.resolveAsset(assetId, variant: 'original');
        if (!mounted) return;
        if (origResolution.isAvailable && origResolution.data != null) {
          _assetThumbnailCache[uri] = origResolution.data!;
          setState(() {
            _imageBytes = origResolution.data;
          });
        }
      }
    } catch (_) {
      // Silent fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final uri = _effectiveUri;
    final kind = _effectiveKind;
    final label = widget.thumbnailData?.label ?? (kind == ThumbnailKind.pdf ? 'PDF' : null);

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
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: _buildMiniBadge(colors, 'PDF'),
          ),
        ],
      );
    } else if (kind == ThumbnailKind.pdf && _isLoading) {
      content = _buildPlaceholder(colors, icon: Icons.picture_as_pdf_outlined, label: 'PDF');
    } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
      content = Image.network(
        uri,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
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
