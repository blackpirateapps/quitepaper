import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../uri/resource_resolver.dart';
import '../attachment_provider.dart';

/// Editorial image widget displaying an encrypted Quiet Paper asset (`qp://asset/<UUID>`)
/// resolved asynchronously from local encrypted storage or Cloudinary.
class QuietAssetImageView extends ConsumerStatefulWidget {
  const QuietAssetImageView({
    super.key,
    required this.assetId,
    this.altText,
    this.title,
    this.variant = 'original',
    this.fit = BoxFit.contain,
    this.maxHeight,
  });

  final String assetId;
  final String? altText;
  final String? title;
  final String variant;
  final BoxFit fit;
  final double? maxHeight;

  @override
  ConsumerState<QuietAssetImageView> createState() => _QuietAssetImageViewState();
}

class _QuietAssetImageViewState extends ConsumerState<QuietAssetImageView> {
  ResourceResolution<Uint8List>? _resolution;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(QuietAssetImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId || oldWidget.variant != widget.variant) {
      _loadAsset();
    }
  }

  Future<void> _loadAsset() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final service = ref.read(attachmentServiceProvider);
    final result = await service.resolveAsset(widget.assetId, variant: widget.variant);

    if (mounted) {
      setState(() {
        _resolution = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoading) {
      return _buildPlaceholder(
        colors: colors,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14.0,
              height: 14.0,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              widget.altText?.isNotEmpty == true ? widget.altText! : 'Loading image...',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final res = _resolution;
    if (res == null || !res.isAvailable || res.data == null) {
      String message = 'Image unavailable';
      IconData icon = Icons.broken_image_outlined;

      if (res?.isLocked == true) {
        message = 'Encrypted image locked';
        icon = Icons.lock_outline_rounded;
      } else if (res?.isCorrupted == true) {
        message = 'Image decryption failed';
        icon = Icons.error_outline_rounded;
      } else if (res?.isMissing == true) {
        message = 'Image not found';
        icon = Icons.image_not_supported_outlined;
      }

      return _buildPlaceholder(
        colors: colors,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.0, color: colors.textTertiary),
            const SizedBox(width: 8.0),
            Flexible(
              child: Text(
                widget.altText?.isNotEmpty == true
                    ? '${widget.altText} ($message)'
                    : message,
                style: AppTypography.caption.copyWith(color: colors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Successfully decrypted image bytes
    final imageWidget = ClipRRect(
      borderRadius: AppRadii.borderMd,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.6),
            width: 0.8,
          ),
          borderRadius: AppRadii.borderMd,
        ),
        child: Image.memory(
          res.data!,
          fit: widget.fit,
          semanticLabel: widget.altText,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxHeight ?? 480.0,
            ),
            child: imageWidget,
          ),
          if (widget.altText != null &&
              widget.altText!.trim().isNotEmpty &&
              widget.altText!.trim().toLowerCase() != 'image') ...[
            const SizedBox(height: 4.0),
            Text(
              widget.altText!.trim(),
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder({required AppColors colors, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
