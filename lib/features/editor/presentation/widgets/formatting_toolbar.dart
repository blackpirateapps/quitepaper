import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../application/markdown_formatter.dart';
import 'link_prompt_dialog.dart';

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.onTagPressed,
    this.onTablePressed,
    this.onImagePressed,
    this.onScanPressed,
    this.onPdfPressed,
    this.onFilePressed,
    this.onNoteLinkPressed,
    this.onDictatePressed,
    this.focusNode,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.isDictating = false,
    this.canDictate = true,
    this.onApplyAtomicEdit,
  });

  final TextEditingController controller;
  final VoidCallback onTagPressed;
  final VoidCallback? onTablePressed;
  final VoidCallback? onImagePressed;
  final VoidCallback? onScanPressed;
  final VoidCallback? onPdfPressed;
  final VoidCallback? onFilePressed;
  final VoidCallback? onNoteLinkPressed;
  final VoidCallback? onDictatePressed;
  final FocusNode? focusNode;

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool isDictating;
  final bool canDictate;
  final void Function(TextEditingValue value)? onApplyAtomicEdit;

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: controller.value);
    controller.value = updated;
    onApplyAtomicEdit?.call(updated);
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  void _applyHelperFormat(TextEditingValue Function(TextEditingValue) action) {
    final updated = action(controller.value);
    controller.value = updated;
    onApplyAtomicEdit?.call(updated);
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  Future<void> _handleLink(BuildContext context) async {
    final selection = controller.selection;
    final text = controller.text;
    String initialTitle = '';
    if (selection.isValid && !selection.isCollapsed) {
      final selStart = selection.start;
      final selEnd = selection.end;
      initialTitle = text.substring(selStart, selEnd);
    }

    final result = await LinkPromptDialog.show(
      context,
      initialTitle: initialTitle,
    );

    if (result != null) {
      final updated = MarkdownFormatter.createLink(
        value: controller.value,
        url: result.url,
        title: result.title,
      );
      controller.value = updated;
      onApplyAtomicEdit?.call(updated);
      if (focusNode != null && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    }
  }

  Future<void> _handleCodeBlock(BuildContext context) async {
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(controller.value);
    if (currentLang != null) {
      // Cursor is already inside a code block: prompt for language change
      final selected = await LanguageSelectorSheet.show(
        context,
        currentLanguageId: currentLang,
        title: 'Change Code Language',
      );
      if (selected != null) {
        final updated = MarkdownHelper.changeCodeBlockLanguage(
          value: controller.value,
          newLanguage: selected.id,
        );
        controller.value = updated;
        onApplyAtomicEdit?.call(updated);
        if (focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();
        }
      }
    } else {
      _applyHelperFormat(MarkdownHelper.insertCodeBlock);
    }
  }

  Future<void> _handleCodeBlockLongPress(BuildContext context) async {
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(controller.value);
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: currentLang,
      title: currentLang != null ? 'Change Code Language' : 'Insert Code Block with Language',
    );
    if (selected != null) {
      if (currentLang != null) {
        final updated = MarkdownHelper.changeCodeBlockLanguage(
          value: controller.value,
          newLanguage: selected.id,
        );
        controller.value = updated;
        onApplyAtomicEdit?.call(updated);
      } else {
        final updated = MarkdownHelper.insertCodeBlock(
          controller.value,
          language: selected.id,
        );
        controller.value = updated;
        onApplyAtomicEdit?.call(updated);
      }
      if (focusNode != null && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.8),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _ToolbarButton(
            icon: PhosphorIconsRegular.arrowUUpLeft,
            tooltip: 'Undo (Ctrl+Z)',
            isEnabled: canUndo,
            onPressed: onUndo ?? () {},
          ),
          _ToolbarButton(
            icon: PhosphorIconsRegular.arrowUUpRight,
            tooltip: 'Redo (Ctrl+Shift+Z)',
            isEnabled: canRedo,
            onPressed: onRedo ?? () {},
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            width: 1,
            color: colors.divider.withValues(alpha: 0.6),
          ),
          _ToolbarButton(
            label: 'B',
            tooltip: 'Bold (**text**)',
            isBold: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleBold),
          ),
          _ToolbarButton(
            label: 'I',
            tooltip: 'Italic (*text*)',
            isItalic: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleItalic),
          ),
          _ToolbarButton(
            label: 'S',
            tooltip: 'Strikethrough (~~text~~)',
            isStrikethrough: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleStrikethrough),
          ),
          _ToolbarButton(
            label: 'H',
            tooltip: 'Cycle heading (# / ## / ###)',
            isBold: true,
            onPressed: () => _applyHelperFormat(MarkdownHelper.cycleHeading),
          ),
          _ToolbarButton(
            icon: PhosphorIconsRegular.checkSquare,
            tooltip: 'Checklist (- [ ] item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleChecklist),
          ),
          _ToolbarButton(
            label: '•',
            tooltip: 'Bullet list (- item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleBulletList),
          ),
          _ToolbarButton(
            label: '1.',
            tooltip: 'Numbered list (1. item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleOrderedList),
          ),
          _ToolbarButton(
            label: '"',
            tooltip: 'Quote (> quote)',
            onPressed: () => _applyHelperFormat(
              (v) => MarkdownHelper.toggleLinePrefix(
                value: v,
                prefix: '> ',
              ),
            ),
          ),
          _ToolbarButton(
            label: '`',
            tooltip: 'Inline code (`code`)',
            isMonospace: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleInlineCode),
          ),
          _ToolbarButton(
            icon: PhosphorIconsRegular.code,
            tooltip: 'Code block (```) — Long press for language',
            onPressed: () => _handleCodeBlock(context),
            onLongPress: () => _handleCodeBlockLongPress(context),
          ),
          _ToolbarButton(
            icon: PhosphorIconsRegular.link,
            tooltip: 'Link ([title](url))',
            onPressed: () => _handleLink(context),
          ),
          if (onNoteLinkPressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.article,
              tooltip: 'Link to note ([title](qp://note/...))',
              onPressed: onNoteLinkPressed!,
            ),
          if (onTablePressed != null)

            _ToolbarButton(
              icon: PhosphorIconsRegular.table,
              tooltip: 'Insert table',
              onPressed: onTablePressed!,
            ),
          if (onImagePressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.image,
              tooltip: 'Insert image (![alt](qp://asset/...))',
              onPressed: onImagePressed!,
            ),
          if (onScanPressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.scan,
              tooltip: 'Scan document ([title](qp://document/...))',
              onPressed: onScanPressed!,
            ),
          if (onPdfPressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.filePdf,
              tooltip: 'Attach PDF document ([title](qp://document/...))',
              onPressed: onPdfPressed!,
            ),
          if (onFilePressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.paperclip,
              tooltip: 'Attach file ([name](qp://asset/...))',
              onPressed: onFilePressed!,
            ),
          _ToolbarButton(
            label: '#',
            tooltip: 'Add tag',
            isBold: true,
            onPressed: onTagPressed,
          ),
          if (onDictatePressed != null)
            _ToolbarButton(
              icon: PhosphorIconsRegular.microphone,
              tooltip: 'Dictate',
              isEnabled: canDictate,
              onPressed: onDictatePressed!,
            ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.isBold = false,
    this.isItalic = false,
    this.isStrikethrough = false,
    this.isMonospace = false,
    this.isEnabled = true,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool isBold;
  final bool isItalic;
  final bool isStrikethrough;
  final bool isMonospace;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final effectiveColor = isEnabled
        ? colors.textSecondary
        : colors.textTertiary.withValues(alpha: 0.35);

    TextStyle textStyle = TextStyle(
      fontSize: 16,
      color: effectiveColor,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
      fontFamily: isMonospace ? 'monospace' : null,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: isEnabled ? onPressed : null,
          onLongPress: isEnabled ? onLongPress : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 18, color: effectiveColor)
                : Text(label!, style: textStyle),
          ),
        ),
      ),
    );
  }
}
