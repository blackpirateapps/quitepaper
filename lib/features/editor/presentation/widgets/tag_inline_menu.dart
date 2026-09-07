import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../tags/domain/tag_model.dart';

/// A Notion/Bear style inline autocomplete floating menu for selecting tags.
class TagInlineMenu extends StatelessWidget {
  const TagInlineMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.query,
    required this.onSelectTag,
    this.maxHeight = 240.0,
    this.width = 280.0,
    this.scrollController,
  });

  final List<Tag> items;
  final int selectedIndex;
  final String query;
  final ValueChanged<Tag> onSelectTag;
  final double maxHeight;
  final double width;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 6.0),
              child: Text(
                'TAGS',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Scrollable List of Tag Candidates
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 4.0),
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final tag = items[index];
                  final isSelected = index == selectedIndex;
                  return _InlineTagCandidateTile(
                    tag: tag,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelectTag(tag);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTagCandidateTile extends StatelessWidget {
  const _InlineTagCandidateTile({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final Tag tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tagColor = tag.colorDefinition?.foreground(colors.isDark);
    final iconData = tag.iconItem?.getIconData() ?? PhosphorIconsRegular.tag;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? colors.accent.withValues(alpha: 0.12) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 15,
              color: tagColor ?? (isSelected ? colors.accent : colors.textTertiary),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                '#${tag.name}',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tag.noteCount > 0)
              Text(
                '${tag.noteCount}',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11.0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
