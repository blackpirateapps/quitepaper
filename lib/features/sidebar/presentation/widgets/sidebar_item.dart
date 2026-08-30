import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.isDestructive = false,
    this.customIconColor,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool isDestructive;
  final Color? customIconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final defaultTextColor = isSidebarDark ? const Color(0xFFF1F2F4) : colors.textPrimary;
    final defaultSecondaryColor = isSidebarDark ? const Color(0xFF9CA3AF) : colors.textSecondary;
    final defaultTertiaryColor = isSidebarDark ? const Color(0xFF9CA3AF) : colors.textTertiary;

    final textColor = isSelected
        ? (isSidebarDark ? Colors.white : colors.textPrimary)
        : (isDestructive ? colors.error : defaultTextColor);

    final countColor = isSelected
        ? (isSidebarDark ? const Color(0xFFE5E7EB) : colors.textPrimary)
        : defaultTertiaryColor;

    final iconColor = isSelected
        ? colors.accent
        : (isDestructive
            ? colors.error.withValues(alpha: 0.8)
            : (customIconColor ?? defaultSecondaryColor));

    final backgroundColor = isSelected
        ? colors.sidebarSelected
        : Colors.transparent;

    final textStyle = (isSelected ? AppTypography.bodyMedium : AppTypography.body).copyWith(
      color: textColor,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      fontSize: 15,
    );

    return Semantics(
      selected: isSelected,
      label: count != null ? '$label, $count notes' : label,
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2.0,
        ),
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onSecondaryTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            splashColor: colors.accent.withValues(alpha: 0.1),
            highlightColor: colors.selection.withValues(alpha: 0.3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: iconColor,
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Text(
                        label,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          color: countColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
