import 'package:flutter/material.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/wysiwyg_editing_controller.dart';
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
    if (controller is WysiwygEditingController) {
      (controller as WysiwygEditingController).applyFormat(action);
      onApplyAtomicEdit?.call(controller.value);
    } else {
      final updated = action(value: controller.value);
      controller.value = updated;
      onApplyAtomicEdit?.call(updated);
    }
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  void _applyHelperFormat(TextEditingValue Function(TextEditingValue) action) {
    if (controller is WysiwygEditingController) {
      (controller as WysiwygEditingController).applyFormat(({required value}) => action(value));
      onApplyAtomicEdit?.call(controller.value);
    } else {
      final updated = action(controller.value);
      controller.value = updated;
      onApplyAtomicEdit?.call(updated);
    }
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
      if (controller is WysiwygEditingController) {
        (controller as WysiwygEditingController).applyFormat(
          ({required value}) => MarkdownFormatter.createLink(
            value: value,
            url: result.url,
            title: result.title,
          ),
        );
        onApplyAtomicEdit?.call(controller.value);
      } else {
        final updated = MarkdownFormatter.createLink(
          value: controller.value,
          url: result.url,
          title: result.title,
        );
        controller.value = updated;
        onApplyAtomicEdit?.call(updated);
      }
      if (focusNode != null && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    }
  }

  Future<void> _handleCodeBlock(BuildContext context) async {
    final effectiveValue = controller is WysiwygEditingController
        ? (controller as WysiwygEditingController).sourceValue
        : controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
    if (currentLang != null) {
      // Cursor is already inside a code block: prompt for language change
      final selected = await LanguageSelectorSheet.show(
        context,
        currentLanguageId: currentLang,
        title: 'Change Code Language',
      );
      if (selected != null) {
        if (controller is WysiwygEditingController) {
          (controller as WysiwygEditingController).applyFormat(
            ({required value}) => MarkdownHelper.changeCodeBlockLanguage(
              value: value,
              newLanguage: selected.id,
            ),
          );
          onApplyAtomicEdit?.call(controller.value);
        } else {
          final updated = MarkdownHelper.changeCodeBlockLanguage(
            value: controller.value,
            newLanguage: selected.id,
          );
          controller.value = updated;
          onApplyAtomicEdit?.call(updated);
        }
        if (focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();
        }
      }
    } else {
      _applyHelperFormat(MarkdownHelper.insertCodeBlock);
    }
  }

  Future<void> _handleCodeBlockLongPress(BuildContext context) async {
    final effectiveValue = controller is WysiwygEditingController
        ? (controller as WysiwygEditingController).sourceValue
        : controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: currentLang,
      title: currentLang != null ? 'Change Code Language' : 'Insert Code Block with Language',
    );
    if (selected != null) {
      if (currentLang != null) {
        if (controller is WysiwygEditingController) {
          (controller as WysiwygEditingController).applyFormat(
            ({required value}) => MarkdownHelper.changeCodeBlockLanguage(
              value: value,
              newLanguage: selected.id,
            ),
          );
          onApplyAtomicEdit?.call(controller.value);
        } else {
          final updated = MarkdownHelper.changeCodeBlockLanguage(
            value: controller.value,
            newLanguage: selected.id,
          );
          controller.value = updated;
          onApplyAtomicEdit?.call(updated);
        }
      } else {
        if (controller is WysiwygEditingController) {
          (controller as WysiwygEditingController).applyFormat(
            ({required value}) => MarkdownHelper.insertCodeBlock(
              value,
              language: selected.id,
            ),
          );
          onApplyAtomicEdit?.call(controller.value);
        } else {
          final updated = MarkdownHelper.insertCodeBlock(
            controller.value,
            language: selected.id,
          );
          controller.value = updated;
          onApplyAtomicEdit?.call(updated);
        }
      }
      if (focusNode != null && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    }
  }

  bool _isBoldActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isBoldActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isBoldActive;
    return MarkdownFormatter.isBoldAt(controller.value);
  }

  bool _isItalicActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isItalicActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isItalicActive;
    return MarkdownFormatter.isItalicAt(controller.value);
  }

  bool _isStrikethroughActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isStrikethroughActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isStrikethroughActive;
    return MarkdownFormatter.isStrikethroughAt(controller.value);
  }

  bool _isInlineCodeActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isInlineCodeActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isInlineCodeActive;
    return MarkdownFormatter.isInlineCodeAt(controller.value);
  }

  bool _isHeadingActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isHeadingActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isHeadingActive;
    return MarkdownFormatter.isHeadingAt(controller.value);
  }

  bool _isChecklistActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isChecklistActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isChecklistActive;
    return MarkdownFormatter.isChecklistAt(controller.value);
  }

  bool _isBulletListActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isBulletListActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isBulletListActive;
    return MarkdownFormatter.isBulletListAt(controller.value);
  }

  bool _isOrderedListActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isOrderedListActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isOrderedListActive;
    return MarkdownFormatter.isOrderedListAt(controller.value);
  }

  bool _isQuoteActive() {
    if (controller is WysiwygEditingController) return (controller as WysiwygEditingController).isQuoteActive;
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isQuoteActive;
    return MarkdownFormatter.isQuoteAt(controller.value);
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
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final isBold = _isBoldActive();
          final isItalic = _isItalicActive();
          final isStrikethrough = _isStrikethroughActive();
          final isCode = _isInlineCodeActive();
          final isHeading = _isHeadingActive();
          final isChecklist = _isChecklistActive();
          final isBullet = _isBulletListActive();
          final isOrdered = _isOrderedListActive();
          final isQuote = _isQuoteActive();

          return ListView(
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
                isActive: isBold,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleBold),
              ),
              _ToolbarButton(
                label: 'I',
                tooltip: 'Italic (*text*)',
                isItalic: true,
                isActive: isItalic,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleItalic),
              ),
              _ToolbarButton(
                label: 'S',
                tooltip: 'Strikethrough (~~text~~)',
                isStrikethrough: true,
                isActive: isStrikethrough,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleStrikethrough),
              ),
              _ToolbarButton(
                label: 'H',
                tooltip: 'Cycle heading (# / ## / ###)',
                isBold: true,
                isActive: isHeading,
                onPressed: () => _applyHelperFormat(MarkdownHelper.cycleHeading),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.checkSquare,
                tooltip: 'Checklist (- [ ] item)',
                isActive: isChecklist,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleChecklist),
              ),
              _ToolbarButton(
                label: '•',
                tooltip: 'Bullet list (- item)',
                isActive: isBullet,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleBulletList),
              ),
              _ToolbarButton(
                label: '1.',
                tooltip: 'Numbered list (1. item)',
                isActive: isOrdered,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleOrderedList),
              ),
              _ToolbarButton(
                label: '"',
                tooltip: 'Quote (> quote)',
                isActive: isQuote,
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
                isActive: isCode,
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
          );
        },
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
    this.isActive = false,
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
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final effectiveColor = !isEnabled
        ? colors.textTertiary.withValues(alpha: 0.35)
        : (isActive ? colors.accent : colors.textSecondary);

    final backgroundColor = (isEnabled && isActive)
        ? colors.accent.withValues(alpha: 0.16)
        : Colors.transparent;

    TextStyle textStyle = TextStyle(
      fontSize: 16,
      color: effectiveColor,
      fontWeight: (isBold || isActive) ? FontWeight.w700 : FontWeight.w500,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
      fontFamily: isMonospace ? 'monospace' : null,
    );

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: (isEnabled && isActive)
                ? BorderSide(color: colors.accent.withValues(alpha: 0.28), width: 1.0)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: isEnabled ? onPressed : null,
            onLongPress: isEnabled ? onLongPress : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 18, color: effectiveColor)
                  : Text(label!, style: textStyle),
            ),
          ),
        ),
      ),
    );
  }
}
