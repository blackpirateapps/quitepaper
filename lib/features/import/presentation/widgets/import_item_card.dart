import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';
import '../../domain/markdown_import_item.dart';
import 'add_tag_modal.dart';

class ImportItemCard extends StatelessWidget {
  const ImportItemCard({
    super.key,
    required this.item,
    required this.onToggleSelect,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onEditTitle,
  });

  final MarkdownImportItem item;
  final ValueChanged<bool?> onToggleSelect;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<String> onEditTitle;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateStr = DateFormat('MMM d, y • h:mm a').format(item.updatedAt);
    final sizeStr = _formatFileSize(item.fileSizeBytes);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: item.isSelected ? colors.accent.withValues(alpha: 0.5) : colors.divider,
          width: item.isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Title, Edit Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.isSelected,
                    onChanged: onToggleSelect,
                    activeColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _promptEditTitle(context),
                    child: Text(
                      item.title.isNotEmpty ? item.title : 'Untitled Note',
                      style: AppTypography.title.copyWith(
                        color: item.isSelected ? colors.textPrimary : colors.textTertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  tooltip: 'Edit title',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _promptEditTitle(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Path & file metadata
            Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.relativePath,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr • $sizeStr',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontSize: 11,
                    ),
                  ),

                  // Snippet preview if available
                  if (item.content.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.content.trim().replaceAll('\n', ' '),
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  // Tags list
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in item.tags)
                        QuietTagChip(
                          tag: tag,
                          onDelete: () => onRemoveTag(tag),
                        ),
                      // Add Tag Button
                      InkWell(
                        onTap: () async {
                          final newTag = await AddTagDialog.show(
                            context,
                            title: 'Add Tag to "${item.title}"',
                          );
                          if (newTag != null && newTag.isNotEmpty) {
                            onAddTag(newTag);
                          }
                        },
                        borderRadius: AppRadii.borderSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.divider),
                            borderRadius: AppRadii.borderSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: colors.accent),
                              const SizedBox(width: 2),
                              Text(
                                'Tag',
                                style: AppTypography.caption.copyWith(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptEditTitle(BuildContext context) async {
    final colors = context.appColors;
    final controller = TextEditingController(text: item.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          'Edit Title',
          style: AppTypography.title.copyWith(color: colors.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Note title',
            filled: true,
            fillColor: colors.background,
            border: OutlineInputBorder(
              borderRadius: AppRadii.borderMd,
              borderSide: BorderSide(color: colors.divider),
            ),
          ),
          onSubmitted: (val) => Navigator.of(ctx).pop(val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Save', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      onEditTitle(newTitle.trim());
    }
  }
}
