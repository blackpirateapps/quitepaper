import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import 'slash_command_item.dart';

/// A Notion/Bear style inline floating menu for slash commands ('/').
class SlashCommandMenu extends StatelessWidget {
  const SlashCommandMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectCommand,
    this.maxHeight = 300.0,
    this.width = 320.0,
    this.scrollController,
  });

  final List<SlashCommandItem> items;
  final int selectedIndex;
  final ValueChanged<SlashCommandItem> onSelectCommand;
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
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 6.0),
              child: Text(
                'BLOCK COMMANDS',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
                child: Text(
                  'No matching commands',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 6.0),
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = index == selectedIndex;
                    return _SlashCommandTile(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => onSelectCommand(item),
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

class _SlashCommandTile extends StatelessWidget {
  const _SlashCommandTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SlashCommandItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final backgroundColor = isSelected
        ? colors.accent.withValues(alpha: 0.12)
        : Colors.transparent;

    return InkWell(
      canRequestFocus: false,
      mouseCursor: SystemMouseCursors.click,
      hoverColor: colors.accent.withValues(alpha: 0.07),
      onTap: onTap,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.18)
                    : colors.divider.withValues(alpha: 0.25),
                borderRadius: AppRadii.borderSm,
              ),
              child: Center(
                child: Icon(
                  item.icon,
                  size: 16,
                  color: isSelected ? colors.accent : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? colors.accent : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item.shortcut != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.divider.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.shortcut!,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
