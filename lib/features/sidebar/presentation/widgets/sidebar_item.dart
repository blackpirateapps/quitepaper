import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
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
    this.onSecondaryTapUp,
    this.isDestructive = false,
    this.customIconColor,
    this.trailing,
    this.indent = 0,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final bool isDestructive;
  final Color? customIconColor;
  final Widget? trailing;

  /// Extra left padding steps for hierarchy rows.
  final int indent;

  /// Optional accessibility label; defaults to [label] plus note count.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final defaultTextColor = isSidebarDark
        ? const Color(0xFFF1F2F4)
        : colors.textPrimary;
    final defaultSecondaryColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textSecondary;
    final defaultTertiaryColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textTertiary;

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

    final textStyle =
        (isSelected ? AppTypography.bodyMedium : AppTypography.body).copyWith(
          color: textColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 14.5,
        );

    return Semantics(
      selected: isSelected,
      label: semanticLabel ?? (count != null ? '$label, $count notes' : label),
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: 1.5,
        ),
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(9.0),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onSecondaryTap,
            onSecondaryTapUp: onSecondaryTapUp,
            borderRadius: BorderRadius.circular(9.0),
            splashColor: colors.accent.withValues(alpha: 0.1),
            highlightColor: colors.selection.withValues(alpha: 0.3),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36.0),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 10.0 + (indent * 16.0),
                  right: 10.0,
                  top: 7.0,
                  bottom: 7.0,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22.0,
                      height: 22.0,
                      child: Center(
                        child: Icon(icon, size: 18.0, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 10.0),
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
                        style: GoogleFonts.jetBrainsMono(
                          textStyle: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontFamily: 'monospace',
                          ),
                          color: countColor,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      trailing!,
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

