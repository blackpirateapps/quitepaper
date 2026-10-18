import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/uri/quiet_paper_uri.dart';
import '../../../../core/utils/link_launcher_helper.dart';
import '../../domain/rich_block.dart';

/// Shared visual card for a baked web-link preview ([LinkPreviewBlock]).
///
/// Renders an optional thumbnail (resolved through the same local-first asset
/// path images use), a title (falling back to the host/url), an optional
/// description and a site/domain row. Tapping anywhere on the card opens the
/// link through [LinkLauncherHelper.handleLinkTap] so the trusted-domain gate
/// is always honoured. When [readOnly] is false and either [onRemove] or
/// [onRefresh] is provided, a small overflow menu exposes those actions.
///
/// This widget always renders the *card*; callers decide (via
/// `smartWebLinksProvider`) whether to show it or a plain inline link.
class LinkPreviewCard extends ConsumerStatefulWidget {
  const LinkPreviewCard({
    super.key,
    required this.block,
    this.readOnly = false,
    this.onRemove,
    this.onRefresh,
    this.fallbackToInlineLinkOnThumbnailFailure = false,
  });

  final LinkPreviewBlock block;
  final bool readOnly;
  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;
  final bool fallbackToInlineLinkOnThumbnailFailure;

  @override
  ConsumerState<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends ConsumerState<LinkPreviewCard> {
  String? _failedThumbnailAssetId;

  @override
  void didUpdateWidget(LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.thumbnailAssetId != widget.block.thumbnailAssetId) {
      _failedThumbnailAssetId = null;
    }
  }

  void _onThumbnailFailed(String assetId) {
    if (!widget.fallbackToInlineLinkOnThumbnailFailure ||
        widget.block.thumbnailAssetId != assetId ||
        _failedThumbnailAssetId == assetId) {
      return;
    }
    setState(() => _failedThumbnailAssetId = assetId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final block = widget.block;

    final host = LinkLauncherHelper.extractDomain(block.url);
    final effectiveTitle =
        block.title.trim().isNotEmpty ? block.title.trim() : (host ?? block.url);
    final siteLabel = (block.siteName != null && block.siteName!.trim().isNotEmpty)
        ? block.siteName!.trim()
        : (host ?? block.url);
    final description = block.description?.trim();
    final hasThumbnail =
        block.thumbnailAssetId != null && block.thumbnailAssetId!.trim().isNotEmpty;

    final showMenu = !widget.readOnly && (widget.onRemove != null || widget.onRefresh != null);

    if (widget.fallbackToInlineLinkOnThumbnailFailure &&
        block.thumbnailAssetId != null &&
        _failedThumbnailAssetId == block.thumbnailAssetId) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => LinkLauncherHelper.handleLinkTap(context, block.url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      block.url,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showMenu)
              _PreviewOverflowMenu(onRemove: widget.onRemove, onRefresh: widget.onRefresh),
          ],
        ),
      );
    }

    final card = Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      elevation: 0,
      child: InkWell(
        onTap: () => LinkLauncherHelper.handleLinkTap(context, block.url),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: colors.divider, width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasThumbnail) ...[
                _LinkPreviewThumbnail(
                  assetId: block.thumbnailAssetId!,
                  onFailed: _onThumbnailFailed,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      effectiveTitle,
                      style: AppTypography.bodySmallMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 12,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            siteLabel,
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Reserve space so the title/description never slide under the
              // overlaid overflow menu button.
              if (showMenu) const SizedBox(width: 28),
            ],
          ),
        ),
      ),
    );

    if (!showMenu) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: card,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Stack(
        children: [
          card,
          Positioned(
            top: 2,
            right: 4,
            child: _PreviewOverflowMenu(
              onRemove: widget.onRemove,
              onRefresh: widget.onRefresh,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overflow menu matching the block affordances used elsewhere (refresh /
/// remove the baked preview).
class _PreviewOverflowMenu extends StatelessWidget {
  const _PreviewOverflowMenu({this.onRemove, this.onRefresh});

  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopupMenuButton<String>(
      tooltip: 'Preview options',
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: colors.textSecondary,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      color: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      onSelected: (value) {
        if (value == 'refresh') {
          onRefresh?.call();
        } else if (value == 'remove') {
          onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        if (onRefresh != null)
          PopupMenuItem<String>(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: colors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                const Text('Refresh preview'),
              ],
            ),
          ),
        if (onRemove != null)
          PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.link_off_rounded, size: 18, color: colors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                const Text('Remove preview'),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact fixed-size thumbnail that resolves a `qp://asset/<id>` reference
/// through [AttachmentService.resolveAsset] — the same local-first, offline
/// path [QuietAssetImageView] uses — and renders the decrypted bytes.
class _LinkPreviewThumbnail extends ConsumerStatefulWidget {
  const _LinkPreviewThumbnail({required this.assetId, this.onFailed});

  /// Full `qp://asset/<id>` reference to the baked thumbnail.
  final String assetId;
  final ValueChanged<String>? onFailed;

  @override
  ConsumerState<_LinkPreviewThumbnail> createState() => _LinkPreviewThumbnailState();
}

class _LinkPreviewThumbnailState extends ConsumerState<_LinkPreviewThumbnail> {
  static const double _size = 72.0;

  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_LinkPreviewThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final id = QuietPaperUri.tryParse(widget.assetId)?.resourceId ?? widget.assetId;
      if (id.isEmpty) {
        _markFailed();
        return;
      }
      final service = ref.read(attachmentServiceProvider);
      final result = await service.resolveAsset(id, variant: 'original')
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (result.isAvailable && result.data != null && result.data!.isNotEmpty) {
        setState(() {
          _bytes = result.data;
          _loading = false;
          _failed = false;
        });
      } else {
        _markFailed();
      }
    } catch (_) {
      _markFailed();
    }
  }

  void _markFailed() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = true;
      _bytes = null;
    });
    widget.onFailed?.call(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // On failure, degrade gracefully to a text-only card (render nothing).
    if (_failed) {
      return const SizedBox.shrink();
    }

    final Widget inner;
    if (_loading || _bytes == null) {
      inner = Center(
        child: Icon(
          Icons.image_outlined,
          size: 20,
          color: colors.textTertiary,
        ),
      );
    } else {
      inner = Image.memory(
        _bytes!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (widget.onFailed == null) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: colors.textTertiary,
              ),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFailed?.call(widget.assetId);
          });
          return const SizedBox.shrink();
        },
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.borderSm,
      child: Container(
        width: _size,
        height: _size,
        color: colors.surfaceSecondary,
        child: inner,
      ),
    );
  }
}
