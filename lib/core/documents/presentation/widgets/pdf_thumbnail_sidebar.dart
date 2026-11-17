import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../document_provider.dart';

/// Collapsible left-hand thumbnail preview sidebar for desktop and large tablet screens.
///
/// Lazily loads encrypted 36-DPI page thumbnails via [PdfThumbnailService], highlights
/// the active page, automatically keeps the active thumbnail in view, and allows
/// instant navigation upon tapping.
class PdfThumbnailSidebar extends ConsumerStatefulWidget {
  const PdfThumbnailSidebar({
    super.key,
    required this.documentId,
    required this.pdfBytes,
    required this.pageCount,
    required this.selectedPageIndexListenable,
    required this.onPageSelected,
    this.width = 140.0,
  });

  final String documentId;
  final Uint8List pdfBytes;
  final int pageCount;
  final ValueListenable<int> selectedPageIndexListenable;
  final ValueChanged<int> onPageSelected;
  final double width;

  @override
  ConsumerState<PdfThumbnailSidebar> createState() =>
      _PdfThumbnailSidebarState();
}

class _PdfThumbnailSidebarState extends ConsumerState<PdfThumbnailSidebar> {
  late final ScrollController _scrollController;
  double get _labelHeight => MediaQuery.textScalerOf(context).scale(11) * 1.3;
  double get _itemExtent =>
      (widget.width - 2 * (AppSpacing.xs + 2)) * 1.33 + 16 + _labelHeight;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.selectedPageIndexListenable.addListener(_onActivePageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onActivePageChanged();
    });
  }

  @override
  void didUpdateWidget(covariant PdfThumbnailSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPageIndexListenable !=
        widget.selectedPageIndexListenable) {
      oldWidget.selectedPageIndexListenable.removeListener(
        _onActivePageChanged,
      );
      widget.selectedPageIndexListenable.addListener(_onActivePageChanged);
    }
  }

  @override
  void dispose() {
    widget.selectedPageIndexListenable.removeListener(_onActivePageChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onActivePageChanged() {
    if (!mounted || !_scrollController.hasClients) return;
    final activeIndex = widget.selectedPageIndexListenable.value;
    final currentOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final itemTop = AppSpacing.sm + activeIndex * _itemExtent;
    final itemBottom = itemTop + _itemExtent;

    if (itemTop < currentOffset ||
        itemBottom > currentOffset + viewportHeight) {
      final target = (itemTop - (viewportHeight - _itemExtent) / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      // Jump directly so distant navigation does not build and rasterize
      // every intermediate viewport of a long PDF.
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: widget.width,
      color: colors.surface,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.selectedPageIndexListenable,
        builder: (context, activeIndex, _) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs + 2,
            ),
            itemExtent: _itemExtent,
            itemCount: widget.pageCount,
            itemBuilder: (context, index) {
              final isSelected = activeIndex == index;
              return _ThumbnailTile(
                key: ValueKey('${widget.documentId}_page_$index'),
                documentId: widget.documentId,
                pageIndex: index,
                pdfBytes: widget.pdfBytes,
                isSelected: isSelected,
                colors: colors,
                labelHeight: _labelHeight,
                onTap: () => widget.onPageSelected(index),
              );
            },
          );
        },
      ),
    );
  }
}

class _ThumbnailTile extends ConsumerStatefulWidget {
  const _ThumbnailTile({
    super.key,
    required this.documentId,
    required this.pageIndex,
    required this.pdfBytes,
    required this.isSelected,
    required this.colors,
    required this.labelHeight,
    required this.onTap,
  });

  final String documentId;
  final int pageIndex;
  final Uint8List pdfBytes;
  final bool isSelected;
  final AppColors colors;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  ConsumerState<_ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends ConsumerState<_ThumbnailTile> {
  Future<Uint8List?>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.pdfBytes != widget.pdfBytes) {
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    _thumbnailFuture = ref
        .read(pdfThumbnailServiceProvider)
        .getPageThumbnail(
          documentId: widget.documentId,
          pageIndex: widget.pageIndex,
          pdfBytes: widget.pdfBytes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isSelected = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Semantics(
        label: 'Page ${widget.pageIndex + 1}',
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          mouseCursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.borderSubtle,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FutureBuilder<Uint8List?>(
                    future: _thumbnailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        final bytes = snapshot.data;
                        if (bytes != null && bytes.isNotEmpty) {
                          return Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.low,
                            frameBuilder:
                                (
                                  context,
                                  child,
                                  frame,
                                  wasSynchronouslyLoaded,
                                ) {
                                  if (wasSynchronouslyLoaded || frame != null) {
                                    return child;
                                  }
                                  return _buildLoadingPlaceholder(colors);
                                },
                          );
                        }
                        return Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 20,
                            color: colors.textSecondary.withValues(alpha: 0.5),
                          ),
                        );
                      }
                      return _buildLoadingPlaceholder(colors);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: widget.labelHeight,
                child: Text(
                  '${widget.pageIndex + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colors.accent : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(AppColors colors) {
    return Container(
      color: colors.surfaceElevated,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator.adaptive(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              colors.accent.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
