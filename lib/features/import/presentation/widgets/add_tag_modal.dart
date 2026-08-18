import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../../core/widgets/quiet_button.dart';

class AddTagDialog extends StatefulWidget {
  const AddTagDialog({
    super.key,
    this.title = 'Add Tag',
    this.hintText = 'e.g. project, notes',
  });

  final String title;
  final String hintText;

  static Future<String?> show(BuildContext context, {String title = 'Add Tag', String hintText = 'e.g. project, notes'}) {
    return showDialog<String>(
      context: context,
      builder: (context) => AddTagDialog(title: title, hintText: hintText),
    );
  }

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    var normalized = TagParser.normalizeTag(raw);
    normalized = normalized.replaceAll(RegExp(r'\s+'), '-');

    if (!TagParser.isValidTag(normalized)) {
      setState(() {
        _errorText = 'Invalid tag format. Use letters, numbers, and hyphens.';
      });
      return;
    }

    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textTertiary),
                prefixText: '#',
                prefixStyle: AppTypography.bodyMedium.copyWith(color: colors.accent),
                errorText: _errorText,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.borderMd,
                  borderSide: BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.borderMd,
                  borderSide: BorderSide(color: colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.borderMd,
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                QuietButton(
                  label: 'Cancel',
                  variant: QuietButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                QuietButton(
                  label: 'Add',
                  variant: QuietButtonVariant.primary,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
