import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../domain/markdown_table_alignment.dart';
import 'markdown_table_action_sheet.dart';

/// Compact, editorial floating/contextual toolbar for quick table operations.
class MarkdownTableToolbar extends StatelessWidget {
  const MarkdownTableToolbar({
    super.key,
    required this.controller,
    this.onCloseTable,
  });

  final MarkdownTableController controller;
  final VoidCallback? onCloseTable;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeCol = controller.activePosition.column;
    final alignment = controller.table.getAlignment(activeCol);

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.tagBackground,
              borderRadius: AppRadii.borderSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart_outlined, size: 13, color: colors.accent),
                const SizedBox(width: 4),
                Text(
                  '${controller.table.columnCount}×${controller.table.rowCount}',
                  style: AppTypography.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          VerticalDivider(
            indent: 6,
            endIndent: 6,
            width: 1,
            color: colors.divider.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.xs),

          // + Row button
          _ToolbarItem(
            label: '+Row',
            tooltip: 'Add row below',
            onTap: controller.addRowBelow,
            colors: colors,
          ),

          // + Column button
          _ToolbarItem(
            label: '+Col',
            tooltip: 'Add column right',
            onTap: controller.addColumnRight,
            colors: colors,
          ),

          // Alignment toggle button
          _ToolbarItem(
            icon: _getAlignIcon(alignment),
            tooltip: 'Cycle column alignment',
            onTap: () {
              final nextAlign = _cycleAlignment(alignment);
              controller.setColumnAlignment(nextAlign);
            },
            colors: colors,
          ),

          // More Options button
          _ToolbarItem(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More table actions',
            onTap: () => MarkdownTableActionSheet.show(
              context,
              controller: controller,
              onClose: onCloseTable,
            ),
            colors: colors,
          ),

          if (onCloseTable != null) ...[
            VerticalDivider(
              indent: 6,
              endIndent: 6,
              width: 1,
              color: colors.divider.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.xs),
            _ToolbarItem(
              icon: Icons.check_rounded,
              tooltip: 'Done editing table',
              onTap: onCloseTable!,
              colors: colors,
              isAccent: true,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAlignIcon(MarkdownTableAlignment alignment) {
    switch (alignment) {
      case MarkdownTableAlignment.center:
        return Icons.format_align_center_rounded;
      case MarkdownTableAlignment.right:
        return Icons.format_align_right_rounded;
      case MarkdownTableAlignment.left:
      case MarkdownTableAlignment.none:
        return Icons.format_align_left_rounded;
    }
  }

  MarkdownTableAlignment _cycleAlignment(MarkdownTableAlignment current) {
    switch (current) {
      case MarkdownTableAlignment.none:
      case MarkdownTableAlignment.left:
        return MarkdownTableAlignment.center;
      case MarkdownTableAlignment.center:
        return MarkdownTableAlignment.right;
      case MarkdownTableAlignment.right:
        return MarkdownTableAlignment.left;
    }
  }
}

class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
    this.isAccent = false,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppColors colors;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isAccent ? colors.accent : colors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 16, color: effectiveColor)
                : Text(
                    label!,
                    style: AppTypography.caption.copyWith(
                      color: effectiveColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
