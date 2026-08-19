import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

/// Editorial dialog for entering link title and URL.
class LinkPromptDialog extends StatefulWidget {
  const LinkPromptDialog({
    super.key,
    this.initialTitle = '',
    this.initialUrl = '',
  });

  final String initialTitle;
  final String initialUrl;

  /// Shows the dialog and returns the resulting `(title, url)` or `null` if cancelled.
  static Future<({String title, String url})?> show(
    BuildContext context, {
    String initialTitle = '',
    String initialUrl = '',
  }) {
    return showDialog<({String title, String url})>(
      context: context,
      builder: (ctx) => LinkPromptDialog(
        initialTitle: initialTitle,
        initialUrl: initialUrl,
      ),
    );
  }

  @override
  State<LinkPromptDialog> createState() => _LinkPromptDialogState();
}

class _LinkPromptDialogState extends State<LinkPromptDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _urlController = TextEditingController(
      text: widget.initialUrl.isNotEmpty ? widget.initialUrl : 'https://',
    );
    _urlFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _urlFocusNode.requestFocus();
        _urlController.selection = TextSelection(
          baseOffset: 8,
          extentOffset: _urlController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    if (url.isEmpty || url == 'https://') return;

    Navigator.of(context).pop((
      title: title.isNotEmpty ? title : 'link',
      url: url,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
      title: Row(
        children: [
          Icon(Icons.link_rounded, size: 20, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Insert Link',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Link Text',
              labelStyle: AppTypography.caption.copyWith(color: colors.textSecondary),
              hintText: 'Display text',
              hintStyle: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'URL',
              labelStyle: AppTypography.caption.copyWith(color: colors.textSecondary),
              hintText: 'https://example.com',
              hintStyle: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.borderSm,
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        QuietButton(
          label: 'Cancel',
          variant: QuietButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        QuietButton(
          label: 'Insert',
          variant: QuietButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
