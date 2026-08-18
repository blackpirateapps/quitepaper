import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';

class TagEditorBar extends StatelessWidget {
  const TagEditorBar({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  final List<String> tags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 6.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...tags.map((tag) {
            return QuietTagChip(
              tag: tag,
              onDelete: () => onRemoveTag(tag),
            );
          }),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.borderSm,
              side: BorderSide(color: colors.divider, style: BorderStyle.solid),
            ),
            child: InkWell(
              onTap: () => _showAddTagDialog(context),
              borderRadius: AppRadii.borderSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Tag',
                      style: AppTypography.tag.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final textController = TextEditingController();
    final colors = context.appColors;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Add tag',
            style: AppTypography.headline.copyWith(color: colors.textPrimary),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. ideas, work/project',
              prefixText: '#',
              prefixStyle: AppTypography.body.copyWith(color: colors.accent),
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.compact,
              ),
              border: const OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                onAddTag(val.trim());
                Navigator.of(ctx).pop();
              }
            },
          ),
          actions: [
            QuietButton(
              label: 'Cancel',
              variant: QuietButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            QuietButton(
              label: 'Add',
              variant: QuietButtonVariant.primary,
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  onAddTag(textController.text.trim());
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
