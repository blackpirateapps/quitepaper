import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
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
  });

  final String tag;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final displayTag = TagParser.formatDisplay(tag);

    Color bg;
    Color textColor;

    if (isSelected) {
      bg = colors.accentSoft;
      textColor = colors.accentDark;
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
        Text(
          displayTag,
          style: AppTypography.tag.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
                Icons.close_rounded,
                size: 14,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ],
    );

    if (onTap != null) {
      return Material(
        color: bg,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.borderSm,
      ),
      child: content,
    );
  }
}
