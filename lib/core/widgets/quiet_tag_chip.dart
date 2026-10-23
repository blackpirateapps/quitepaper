import 'package:flutter/material.dart';
import '../../features/tags/domain/phosphor_icons.dart';
import '../../features/tags/domain/tag_path.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/tag_parser.dart';

class QuietTagChip extends StatelessWidget {
  const QuietTagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onDelete,
    this.isSelected = false,
    this.showBackground = true,
    this.icon,
    this.customColor,
    this.customBackgroundColor,
  });

  final String tag;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final bool showBackground;
  final IconData? icon;
  final Color? customColor;
  final Color? customBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final path = TagPath.tryParse(tag);
    final isNested = path?.isNested == true;
    final displayTag = path != null
        ? '#${path.leaf}'
        : TagParser.formatDisplay(tag);
    final fullLabel = path?.token ?? displayTag;

    final VoidCallback? effectiveOnTap;
    if (isNested) {
      effectiveOnTap = () => _showPathDisclosure(context, path!);
    } else {
      effectiveOnTap = onTap;
    }

    Color bg;
    Color textColor;

    if (isSelected) {
      bg = colors.accentSoft;
      textColor = colors.accentDark;
    } else if (customColor != null) {
      bg = customBackgroundColor ?? colors.tagBackground;
      textColor = customColor!;
    } else if (showBackground) {
      bg = colors.tagBackground;
      textColor = colors.tagText;
    } else {
      bg = Colors.transparent;
      textColor = colors.textSecondary;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          displayTag,
          style: AppTypography.tag.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                PhosphorIconsRegular.x,
                size: 14,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ],
    );

    content = Semantics(
      label: isNested ? '$fullLabel, nested tag' : fullLabel,
      button: effectiveOnTap != null,
      excludeSemantics: true,
      child: content,
    );

    if (effectiveOnTap != null) {
      return Material(
        color: bg,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderSm),
      child: content,
    );
  }

  Future<void> _showPathDisclosure(BuildContext context, TagPath path) async {
    final colors = context.appColors;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          '#${path.leaf}',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Full tag path',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              path.breadcrumb,
              style: AppTypography.body.copyWith(
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Close',
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Open tag',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
    if (shouldOpen == true && context.mounted) {
      onTap?.call();
    }
  }
}
