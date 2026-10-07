import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../notes/domain/note_model.dart';

/// A 3-column quick-action bar at the top of the editor overflow menu.
/// Features prominent, tactile icon buttons for frequent actions:
/// Pin, Archive/Unarchive, and Delete/Trash (or Restore and Delete permanently for trashed notes).
class EditorQuickActionsBar extends StatelessWidget {
  const EditorQuickActionsBar({
    super.key,
    required this.note,
    required this.onTogglePin,
    required this.onToggleArchive,
    required this.onTrash,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  final Note note;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleArchive;
  final VoidCallback onTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeletePermanently;

  @override
  Widget build(BuildContext context) {
    if (note.isTrashed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.restore_rounded,
                label: 'Restore',
                onTap: onRestore,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.delete_forever_rounded,
                label: 'Delete permanently',
                isDestructive: true,
                onTap: onDeletePermanently,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: note.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              label: note.isPinned ? 'Unpin' : 'Pin',
              onTap: onTogglePin,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _QuickActionButton(
              icon: note.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: note.isArchived ? 'Unarchive' : 'Archive',
              onTap: onToggleArchive,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              isDestructive: true,
              onTap: onTrash,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final contentColor = isDestructive ? colors.error : colors.textPrimary;
    final iconColor = isDestructive ? colors.error : colors.textSecondary;

    return Material(
      color: colors.surfaceSecondary,
      borderRadius: const BorderRadius.all(AppRadii.rMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(AppRadii.rMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: iconColor,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: contentColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
