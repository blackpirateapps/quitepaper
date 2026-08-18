import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

enum QuietButtonVariant {
  primary,
  secondary,
  tonal,
  ghost,
  destructive,
}

class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = QuietButtonVariant.secondary,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final QuietButtonVariant variant;
  final bool isFullWidth;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color backgroundColor;
    Color foregroundColor;
    Border? border;

    switch (variant) {
      case QuietButtonVariant.primary:
        backgroundColor = colors.accent;
        foregroundColor = Colors.white;
        border = null;
        break;
      case QuietButtonVariant.secondary:
        backgroundColor = colors.surface;
        foregroundColor = colors.textPrimary;
        border = Border.all(color: colors.divider);
        break;
      case QuietButtonVariant.tonal:
        backgroundColor = colors.tagBackground;
        foregroundColor = colors.textPrimary;
        border = null;
        break;
      case QuietButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.textSecondary;
        border = null;
        break;
      case QuietButtonVariant.destructive:
        backgroundColor = colors.error.withValues(alpha: 0.12);
        foregroundColor = colors.error;
        border = null;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation(foregroundColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.bodySmallMedium.copyWith(
              color: foregroundColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderBtn,
        side: border != null ? border.top : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.compact,
          ),
          child: content,
        ),
      ),
    );
  }
}
