import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';

class TagEditorBar extends StatelessWidget {
  const TagEditorBar({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.showAddButton = false,
    this.showFullPath = true,
    this.padding,
  });

  final List<String> tags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
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
                onTap: () => showAddTagDialog(context, onAddTag),
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

  static void showAddTagDialog(BuildContext context, ValueChanged<String> onAddTag) {
    final textController = TextEditingController();
    final colors = context.appColors;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void submit() {
              final raw = textController.text.trim();
              if (raw.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }

              final normalized = TagParser.normalizeTag(raw);
              if (!TagParser.isValidTag(normalized)) {
                setDialogState(() {
                  errorText = 'Invalid tag format. Use letters, numbers, and hyphens.';
                });
                return;
              }

              onAddTag(normalized);
              Navigator.of(ctx).pop();
            }

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
              title: Text(
                'Add Tag',
                style: AppTypography.headline.copyWith(color: colors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: AppTypography.body.copyWith(color: colors.textPrimary),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. ideas, journal/2026',
                      hintStyle: AppTypography.body.copyWith(
                        color: colors.textTertiary.withValues(alpha: 0.5),
                      ),
                      prefixText: '#',
                      prefixStyle: AppTypography.body.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
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
                    onSubmitted: (_) => submit(),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      errorText!,
                      style: AppTypography.caption.copyWith(color: colors.error),
                    ),
                  ],
                ],
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
                  onPressed: submit,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
