import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';

/// A container card mimicking the iOS grouped table section.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// An informative, non-clickable row used for headers/descriptions inside a grouped section.
class SettingsInfoTile extends StatelessWidget {
  const SettingsInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.descriptionColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final Color? descriptionColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 14.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: descriptionColor ?? colors.textSecondary,
                    fontSize: 12.0,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8.0),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A standard clickable row inside a grouped section.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.badge,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.trailingRowText,
    this.isSelected = false,
    this.isPrimaryAction = false,
    this.isDestructive = false,
    this.onTap,
  }) : assert(icon != null || leading != null,
            'Either icon or leading must be provided');

  final IconData? icon;
  final Widget? leading;
  final String title;
  final Widget? badge;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final String? trailingRowText;
  final bool isSelected;
  final bool isPrimaryAction;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final resolvedIconColor = iconColor ??
        (isSelected
            ? colors.accent
            : (isDestructive
                ? colors.error
                : (isPrimaryAction ? colors.accent : colors.textSecondary)));

    final resolvedTitleColor = titleColor ??
        (isSelected
            ? colors.accent
            : (isDestructive
                ? colors.error
                : (isPrimaryAction ? colors.accent : colors.textPrimary)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 14.0,
          ),
          child: Row(
            crossAxisAlignment: subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: leading ??
                      Icon(
                        icon,
                        size: 20,
                        color: resolvedIconColor,
                      ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.bodyMedium.copyWith(
                              color: resolvedTitleColor,
                              fontWeight: (isSelected || isPrimaryAction)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8.0),
                          badge!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12.0,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (trailingRowText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingRowText!,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 13.0,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ],
                )
              else if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDestructive
                      ? colors.error.withValues(alpha: 0.6)
                      : (isPrimaryAction
                          ? colors.accent.withValues(alpha: 0.7)
                          : colors.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact editorial Beta badge pill matching Quiet Paper's aesthetic.
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        'BETA',
        style: AppTypography.caption.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colors.accent,
        ),
      ),
    );
  }
}

Widget buildSectionHeader(BuildContext context, String title) {
  final colors = context.appColors;
  return Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.xs,
      bottom: 8.0,
    ),
    child: Text(
      title.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: colors.textTertiary,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

Widget buildSectionFooter(BuildContext context, String text) {
  final colors = context.appColors;
  return Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.xs,
      top: 6.0,
      right: AppSpacing.xs,
    ),
    child: Text(
      text,
      style: AppTypography.caption.copyWith(
        color: colors.textTertiary,
        fontSize: 11.5,
        height: 1.35,
      ),
    ),
  );
}

Widget buildDivider(AppColors colors) {
  return Divider(
    color: colors.divider.withValues(alpha: 0.5),
    height: 1,
    thickness: 1.0,
    indent: 52, // 16 horizontal padding + 24 icon box + 12 gap = 52
    endIndent: 0,
  );
}

Widget buildThemePreviewSwatches({
  required BuildContext context,
  required AppColors colors,
  required bool isSelected,
}) {
  final activeColors = context.appColors;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: colors.divider, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.divider, width: 0.5),
              ),
            ),
            const SizedBox(width: 3.5),
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                color: colors.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3.5),
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                color: colors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3.5),
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      if (isSelected) ...[
        const SizedBox(width: 8.0),
        Icon(
          Icons.check_rounded,
          size: 20,
          color: activeColors.accent,
        ),
      ],
    ],
  );
}
