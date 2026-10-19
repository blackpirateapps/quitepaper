import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/utils/link_launcher_helper.dart';

/// An understated editorial skeleton card displayed in Super Editor while
/// a link preview's page metadata, description, and thumbnail are being fetched.
class LinkPreviewLoadingCard extends StatefulWidget {
  const LinkPreviewLoadingCard({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  State<LinkPreviewLoadingCard> createState() => _LinkPreviewLoadingCardState();
}

class _LinkPreviewLoadingCardState extends State<LinkPreviewLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  static const double _thumbnailSize = 72.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final host = LinkLauncherHelper.extractDomain(widget.url) ?? widget.url;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final pulse = _animation.value;
        // Interpolate smooth pulse colors for the skeleton elements.
        final shimmerColor = Color.lerp(
          colors.divider.withValues(alpha: 0.35),
          colors.divider.withValues(alpha: 0.85),
          pulse,
        )!;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.9),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Skeleton thumbnail box
              ClipRRect(
                borderRadius: AppRadii.borderSm,
                child: Container(
                  width: _thumbnailSize,
                  height: _thumbnailSize,
                  color: colors.surfaceSecondary,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 24,
                      color: Color.lerp(
                        colors.textTertiary.withValues(alpha: 0.3),
                        colors.textTertiary.withValues(alpha: 0.7),
                        pulse,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Content skeleton bars
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Domain and subtle spinner
                    Row(
                      children: [
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            host,
                            style: AppTypography.caption.copyWith(
                              color: colors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  Fetching preview…',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    // Title placeholder or pre-filled title
                    if (widget.title != null &&
                        widget.title!.trim().isNotEmpty &&
                        widget.title != widget.url)
                      Text(
                        widget.title!.trim(),
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: colors.textPrimary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Container(
                        height: 13,
                        width: double.infinity,
                        margin: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    const SizedBox(height: 7),
                    // Description skeleton bars
                    Container(
                      height: 9,
                      width: double.infinity,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: shimmerColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.55,
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: shimmerColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
