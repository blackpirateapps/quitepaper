import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/web_url_helper.dart';
import '../../../../core/widgets/quiet_button.dart';

/// Result of a [LinkPromptDialog]: the entered link text and URL. An empty
/// [url] (only possible in edit mode) signals that the caller should strip the
/// link, keeping the surrounding text.
typedef LinkPromptResult = ({String title, String url});

/// Editorial dialog for entering link title and URL.
class LinkPromptDialog extends StatefulWidget {
  const LinkPromptDialog({
    super.key,
    this.initialTitle = '',
    this.initialUrl = '',
    this.isEditing = false,
  });

  final String initialTitle;
  final String initialUrl;

  /// When true the dialog edits an existing link: it prefills both fields,
  /// relabels for editing, allows an empty URL submission (to revert), and
  /// offers an explicit "Remove link" action.
  final bool isEditing;

  /// Shows the dialog and returns the resulting [LinkPromptResult] or `null` if
  /// cancelled.
  static Future<LinkPromptResult?> show(
    BuildContext context, {
    String initialTitle = '',
    String initialUrl = '',
    bool isEditing = false,
  }) {
    return showDialog<LinkPromptResult>(
      context: context,
      builder: (ctx) => LinkPromptDialog(
        initialTitle: initialTitle,
        initialUrl: initialUrl,
        isEditing: isEditing,
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
  late final FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _urlController = TextEditingController(
      text: widget.initialUrl.isNotEmpty ? widget.initialUrl : 'https://',
    );
    _urlFocusNode = FocusNode();
    _titleFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _urlFocusNode.requestFocus();
      if (widget.isEditing) {
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      } else {
        _urlController.selection = TextSelection(
          baseOffset: 8,
          extentOffset: _urlController.text.length,
        );
      }
    });

    // Feature 3 — Smart clipboard detection (local only). When inserting a new
    // link with no URL supplied, peek the clipboard; if it holds a single web
    // URL, prefill it and move focus to the Title field. Never overwrites a URL
    // the user has already started editing.
    if (!widget.isEditing && widget.initialUrl.isEmpty) {
      _prefillUrlFromClipboard();
    }
  }

  Future<void> _prefillUrlFromClipboard() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final text = data?.text;
    if (text == null || !isSingleWebUrl(text)) return;
    final url = normalizeWebUrl(text);
    if (url == null) return;
    // Respect any URL the user has already typed.
    final current = _urlController.text.trim();
    if (current.isNotEmpty && current != 'https://') return;
    setState(() {
      _urlController.text = url;
    });
    _titleFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    var url = _urlController.text.trim();
    if (url == 'https://') url = '';

    if (!widget.isEditing) {
      // Insert mode preserves the original contract: a URL is required and an
      // empty title falls back to "link".
      if (url.isEmpty) return;
      Navigator.of(context).pop((
        title: title.isNotEmpty ? title : 'link',
        url: url,
      ));
      return;
    }

    // Edit mode allows an empty URL: an empty url is the removal/revert signal.
    // The caller decides the display text when the title is left empty.
    Navigator.of(context).pop((title: title, url: url));
  }

  void _removeLink() {
    // Empty url is the agreed removal sentinel (keeps the 2-field record shape).
    Navigator.of(context).pop((title: '', url: ''));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEditing = widget.isEditing;

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
            isEditing ? 'Edit Link' : 'Insert Link',
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
            focusNode: _titleFocusNode,
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
        if (isEditing)
          QuietButton(
            label: 'Remove link',
            variant: QuietButtonVariant.destructive,
            onPressed: _removeLink,
          ),
        QuietButton(
          label: 'Cancel',
          variant: QuietButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        QuietButton(
          label: isEditing ? 'Update' : 'Insert',
          variant: QuietButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
