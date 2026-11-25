import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';
import '../../../tags/presentation/widgets/tag_picker_dialog.dart';

class TagEditorBar extends StatelessWidget {
  const TagEditorBar({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.onAddTags,
    this.showAddButton = false,
    this.showFullPath = true,
    this.padding,
  });

  final List<String> tags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<List<String>>? onAddTags;
  final bool showAddButton;
  final bool showFullPath;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && !showAddButton) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 6.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...tags.map((tag) {
            return QuietTagChip(
              tag: tag,
              showFullPath: showFullPath,
              onDelete: () => onRemoveTag(tag),
            );
          }),
          if (showAddButton)
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.borderSm,
                side: BorderSide(color: colors.divider, width: 0.8),
              ),
              child: InkWell(
                onTap: () => showAddTagDialog(
                  context,
                  onAddTag,
                  existingTags: tags,
                  onAddTags: onAddTags,
                ),
                borderRadius: AppRadii.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.plus,
                        size: 13,
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

  static Future<void> showAddTagDialog(
    BuildContext context,
    ValueChanged<String> onAddTag, {
    List<String> existingTags = const [],
    ValueChanged<List<String>>? onAddTags,
  }) async {
    final selected = await TagPickerDialog.show(
      context,
      existingTags: existingTags,
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    if (onAddTags != null) {
      onAddTags(selected);
    } else {
      for (final tag in selected) {
        onAddTag(tag);
      }
    }
  }
}
