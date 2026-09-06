import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/documents/document_provider.dart';
import '../../domain/editorial_attachment_item.dart';
import '../widgets/note_thumbnail_view.dart';

/// Inline attachment group for the Editorial notes list.
/// Renders aspect-ratio preserved single images, horizontal thumbnail grids,
/// and document cards matching the Bear notes editorial reference.
class EditorialAttachmentGroup extends ConsumerStatefulWidget {
  const EditorialAttachmentGroup({
    super.key,
    required this.items,
    this.maxVisible = 2,
  });

  final List<EditorialAttachmentItem> items;
  final int maxVisible;

  @override
  ConsumerState<EditorialAttachmentGroup> createState() =>
      _EditorialAttachmentGroupState();
}

class _EditorialAttachmentGroupState
    extends ConsumerState<EditorialAttachmentGroup> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final colors = context.appColors;

    if (widget.items.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _buildSingleItem(context, colors, widget.items.first),
        ),
      );
    }

    final visibleCount = widget.items.length > widget.maxVisible
        ? widget.maxVisible
        : widget.items.length;
    final remaining = widget.items.length - visibleCount;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: SizedBox(
        height: 72.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < visibleCount; i++) ...[
              if (i > 0) const SizedBox(width: 8.0),
              Flexible(
                child: _buildMultiItem(
                  context,
                  colors,
                  widget.items[i],
                  isLastWithRemaining: i == visibleCount - 1 && remaining > 0,
                  remainingCount: remaining,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleItem(
    BuildContext context,
    AppColors colors,
    EditorialAttachmentItem item,
  ) {
    if (item.isImage) {
      return _EditorialImageCard(
        uri: item.uri,
        width: 190.0,
        height: 76.0,
      );
    }

    return _EditorialDocCard(
      item: item,
      width: 150.0,
      height: 72.0,
    );
  }

  Widget _buildMultiItem(
    BuildContext context,
    AppColors colors,
    EditorialAttachmentItem item, {
    bool isLastWithRemaining = false,
    int remainingCount = 0,
  }) {
    Widget card;
    if (item.isImage) {
      card = _EditorialImageCard(
        uri: item.uri,
        width: 100.0,
        height: 72.0,
      );
    } else {
      card = _EditorialDocCard(
        item: item,
        width: 110.0,
        height: 72.0,
      );
    }

    if (isLastWithRemaining) {
      return Stack(
        children: [
          card,
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: colors.divider,
                  width: 0.8,
                ),
              ),
              child: Text(
                '+$remainingCount',
                style: AppTypography.caption.copyWith(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

class _EditorialImageCard extends ConsumerStatefulWidget {
  const _EditorialImageCard({
    required this.uri,
    required this.width,
    required this.height,
  });

  final String uri;
  final double width;
  final double height;

  @override
  ConsumerState<_EditorialImageCard> createState() => _EditorialImageCardState();
}

class _EditorialImageCardState extends ConsumerState<_EditorialImageCard> {
  Uint8List? _bytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(_EditorialImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _loadAsset();
    }
  }

  Future<void> _loadAsset() async {
    final uri = widget.uri;
    if (!uri.startsWith('qp://asset/')) return;

    if (assetThumbnailCache.containsKey(uri)) {
      _bytes = assetThumbnailCache[uri];
      return;
    }

    final assetId = uri.replaceFirst('qp://asset/', '').trim();
    if (assetId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(attachmentServiceProvider);
      var resolution = await service.resolveAsset(assetId, variant: 'thumbnail');
      if (!resolution.isAvailable || resolution.data == null) {
        resolution = await service.resolveAsset(assetId, variant: 'original');
      }

      if (!mounted) return;
      if (resolution.isAvailable && resolution.data != null) {
        assetThumbnailCache[uri] = resolution.data!;
        setState(() {
          _bytes = resolution.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final uri = widget.uri;

    Widget imageContent;

    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      imageContent = Image.network(
        uri,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, error, stackTrace) => _buildFallback(colors),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _buildLoading(colors);
        },
      );
    } else if (_bytes != null) {
      imageContent = Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      );
    } else if (_isLoading) {
      imageContent = _buildLoading(colors);
    } else {
      imageContent = _buildFallback(colors);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: imageContent,
      ),
    );
  }

  Widget _buildLoading(AppColors colors) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: colors.surfaceSubtle,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: colors.textTertiary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildFallback(AppColors colors) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: colors.surfaceSubtle,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: colors.textTertiary.withValues(alpha: 0.5),
      ),
    );
  }
}

class _EditorialDocCard extends ConsumerStatefulWidget {
  const _EditorialDocCard({
    required this.item,
    required this.width,
    required this.height,
  });

  final EditorialAttachmentItem item;
  final double width;
  final double height;

  @override
  ConsumerState<_EditorialDocCard> createState() => _EditorialDocCardState();
}

class _EditorialDocCardState extends ConsumerState<_EditorialDocCard> {
  Uint8List? _firstPagePng;

  @override
  void initState() {
    super.initState();
    _loadPdfThumbnail();
  }

  @override
  void didUpdateWidget(_EditorialDocCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.uri != widget.item.uri) {
      _loadPdfThumbnail();
    }
  }

  Future<void> _loadPdfThumbnail() async {
    final item = widget.item;
    if (!item.isPdf) return;

    final uri = item.uri;
    if (pdfThumbnailCache.containsKey(uri)) {
      _firstPagePng = pdfThumbnailCache[uri];
      return;
    }

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
        final service = ref.read(attachmentServiceProvider);
        final res = await service.resolveAsset(assetId, variant: 'original');
        if (res.isAvailable && res.data != null) {
          pdfBytes = res.data;
        }
      }

      if (!mounted) return;
      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        await for (final page in Printing.raster(pdfBytes, pages: const [0], dpi: 72.0)) {
          final png = await page.toPng();
          pdfThumbnailCache[uri] = png;
          if (mounted) {
            setState(() {
              _firstPagePng = png;
            });
          }
          break;
        }
      }
    } catch (_) {
      // Quiet fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final item = widget.item;
    final badgeLabel = item.label ?? (item.isPdf ? 'PDF' : 'DOC');
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : (item.isPdf ? 'PDF Document' : 'Attachment');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Stack(
          children: [
            if (_firstPagePng != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.22,
                  child: Image.memory(
                    _firstPagePng!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.0,
                      height: 1.25,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5.0,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.8),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
