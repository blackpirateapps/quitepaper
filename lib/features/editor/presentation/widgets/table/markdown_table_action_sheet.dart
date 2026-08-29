import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../domain/markdown_table_alignment.dart';

/// Modal bottom action sheet presenting complete row, column, and table operations.
class MarkdownTableActionSheet extends StatelessWidget {
  const MarkdownTableActionSheet({
    super.key,
    required this.controller,
    this.onClose,
  });

  final MarkdownTableController controller;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required MarkdownTableController controller,
    VoidCallback? onClose,
  }) {
    final colors = context.appColors;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) => MarkdownTableActionSheet(
        controller: controller,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeCol = controller.activePosition.column;
    final currentAlign = controller.table.getAlignment(activeCol);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, size: 18, color: colors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Table Operations',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Rows Section
            _ActionTile(
              icon: Icons.add_rounded,
              title: 'Add row below',
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                controller.addRowBelow();
              },
            ),
            _ActionTile(
              icon: Icons.vertical_align_top_rounded,
              title: 'Add row above',
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                controller.addRowAbove();
              },
            ),
            if (controller.activePosition.row > 0 && controller.table.bodyRows.isNotEmpty)
              _ActionTile(
                icon: Icons.remove_circle_outline_rounded,
                title: 'Delete row',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.deleteCurrentRow();
                },
              ),

            const Divider(height: 16),

            // Columns Section
            _ActionTile(
              icon: Icons.add_rounded,
              title: 'Add column right',
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                controller.addColumnRight();
              },
            ),
            _ActionTile(
              icon: Icons.keyboard_tab_rounded,
              title: 'Add column left',
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                controller.addColumnLeft();
              },
            ),
            if (controller.table.columnCount > 1)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete column',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.deleteCurrentColumn();
                },
              ),

            const Divider(height: 16),

            // Alignment Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
              child: Text(
                'COLUMN ALIGNMENT',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _AlignChip(
                    label: 'Left',
                    icon: Icons.format_align_left_rounded,
                    isSelected: currentAlign == MarkdownTableAlignment.left ||
                        currentAlign == MarkdownTableAlignment.none,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.setColumnAlignment(MarkdownTableAlignment.left);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _AlignChip(
                    label: 'Center',
                    icon: Icons.format_align_center_rounded,
                    isSelected: currentAlign == MarkdownTableAlignment.center,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.setColumnAlignment(MarkdownTableAlignment.center);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _AlignChip(
                    label: 'Right',
                    icon: Icons.format_align_right_rounded,
                    isSelected: currentAlign == MarkdownTableAlignment.right,
                    colors: colors,
                    onTap: () {
                      Navigator.of(context).pop();
                      controller.setColumnAlignment(MarkdownTableAlignment.right);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),

            const Divider(height: 24),

            // Delete Table Action
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              title: 'Delete table',
              isDestructive: true,
              colors: colors,
              onTap: () {
                Navigator.of(context).pop();
                controller.deleteTable();
                onClose?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDestructive ? colors.error : colors.textPrimary;

    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDestructive ? colors.error : colors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: effectiveColor,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}

class _AlignChip extends StatelessWidget {
  const _AlignChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.borderSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.15) : colors.background,
          borderRadius: AppRadii.borderSm,
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
