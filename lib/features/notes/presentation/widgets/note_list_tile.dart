import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';
import '../../domain/note_model.dart';

class NoteListTile extends StatelessWidget {
  const NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    this.onTagTap,
    this.isSelected = false,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final ValueChanged<String>? onTagTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final formattedTime = DateFormatter.formatNoteTileTime(note.updatedAt);
    final preview = note.previewSnippet;

    return Material(
      color: isSelected
          ? colors.selection.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14.0,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.divider.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and relative time / pin row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isPinned) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, right: 6.0),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: colors.accent,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      note.displayTitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: note.hasCustomTitle
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formattedTime,
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),

              // Preview content snippet
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 5.0),
                Text(
                  preview,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags row
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: note.tags.map((tag) {
                    return QuietTagChip(
                      tag: tag,
                      showBackground: true,
                      onTap: onTagTap != null ? () => onTagTap!(tag) : null,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    note.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    note.isPinned ? 'Unpin note' : 'Pin note',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onTogglePin();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    'Delete note',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
