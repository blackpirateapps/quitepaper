import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/semantic_editor_controller.dart';
import 'heading/markdown_heading_action_sheet.dart';
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
    this.onCycleHeading,
    this.onCycleHeadingLongPress,
    this.semanticController,
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

  /// Optional [SemanticEditorController] when running in WYSIWYG mode.
  final SemanticEditorController? semanticController;

  /// When provided (WYSIWYG mode), tapping the heading button calls this
  /// instead of inserting raw `#` markdown syntax.
  final VoidCallback? onCycleHeading;

  /// When provided (WYSIWYG mode), long-pressing the heading button calls this
  /// instead of opening the source-mode heading action sheet.
  final VoidCallback? onCycleHeadingLongPress;

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
    var initialTitle = '';
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
    final effectiveValue = controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
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
    final effectiveValue = controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
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

  Future<void> _handleHeadingLongPress(BuildContext context) async {
    if (semanticController != null) {
      final currentLevel = semanticController!.activeHeadingLevel ?? 0;
      await MarkdownHeadingActionSheet.show(
        context,
        currentLevel: currentLevel,
        onSelectLevel: (newLevel) {
          semanticController!.setHeadingLevel(newLevel);
          if (focusNode != null && !focusNode!.hasFocus) {
            focusNode!.requestFocus();
          }
        },
        onConvertToParagraph: () {
          semanticController!.convertHeadingToParagraph();
          if (focusNode != null && !focusNode!.hasFocus) {
            focusNode!.requestFocus();
          }
        },
        onCycleLevel: () {
          semanticController!.cycleHeadingLevel();
          if (focusNode != null && !focusNode!.hasFocus) {
            focusNode!.requestFocus();
          }
        },
      );
      return;
    }

    final effectiveValue = controller.value;
    final currentLevel = MarkdownHelper.getHeadingLevelAt(effectiveValue) ?? 0;
    await MarkdownHeadingActionSheet.show(
      context,
      currentLevel: currentLevel,
      onSelectLevel: (newLevel) {
        _applyHelperFormat((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: newLevel));
      },
      onConvertToParagraph: () {
        _applyHelperFormat((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: 0));
      },
      onCycleLevel: () {
        _applyHelperFormat(MarkdownHelper.cycleHeading);
      },
    );
  }

  bool _isBoldActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isBoldActive;
    return MarkdownFormatter.isBoldAt(controller.value);
  }

  bool _isItalicActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isItalicActive;
    return MarkdownFormatter.isItalicAt(controller.value);
  }

  bool _isStrikethroughActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isStrikethroughActive;
    return MarkdownFormatter.isStrikethroughAt(controller.value);
  }

  bool _isInlineCodeActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isInlineCodeActive;
    return MarkdownFormatter.isInlineCodeAt(controller.value);
  }

  bool _isHeadingActive() {
    if (semanticController != null) {
      return semanticController!.activeHeadingLevel != null;
    }
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isHeadingActive;
    return MarkdownFormatter.isHeadingAt(controller.value);
  }

  bool _isChecklistActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isChecklistActive;
    return MarkdownFormatter.isChecklistAt(controller.value);
  }

  bool _isBulletListActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isBulletListActive;
    return MarkdownFormatter.isBulletListAt(controller.value);
  }

  bool _isOrderedListActive() {
    if (controller is MarkdownEditingController) return (controller as MarkdownEditingController).isOrderedListActive;
    return MarkdownFormatter.isOrderedListAt(controller.value);
  }

  bool _isQuoteActive() {
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
                tooltip: 'Redo (Ctrl+Y)',
                isEnabled: canRedo,
                onPressed: onRedo ?? () {},
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: PhosphorIconsRegular.textB,
                tooltip: 'Bold (**text**)',
                isActive: isBold,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleBold),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.textItalic,
                tooltip: 'Italic (*text*)',
                isActive: isItalic,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleItalic),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.textStrikethrough,
                tooltip: 'Strikethrough (~~text~~)',
                isActive: isStrikethrough,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleStrikethrough),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.code,
                tooltip: 'Inline Code (`code`)',
                isActive: isCode,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleInlineCode),
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: PhosphorIconsRegular.textH,
                tooltip: 'Heading (cycle H1-H6, long-press for options)',
                isActive: isHeading,
                onPressed: () {
                  if (onCycleHeading != null) {
                    onCycleHeading!();
                  } else if (semanticController != null) {
                    semanticController!.cycleHeadingLevel();
                    focusNode?.requestFocus();
                  } else {
                    _applyHelperFormat(MarkdownHelper.cycleHeading);
                  }
                },
                onLongPress: onCycleHeadingLongPress ?? () => _handleHeadingLongPress(context),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.checkSquare,
                tooltip: 'Checklist (- [ ])',
                isActive: isChecklist,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleChecklist),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.listBullets,
                tooltip: 'Bullet List (-)',
                isActive: isBullet,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleBulletList),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.listNumbers,
                tooltip: 'Numbered List (1.)',
                isActive: isOrdered,
                onPressed: () => _applyFormat(MarkdownFormatter.toggleOrderedList),
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.quotes,
                tooltip: 'Quote (>)',
                isActive: isQuote,
                onPressed: () => _applyHelperFormat((val) => MarkdownHelper.toggleLinePrefix(value: val, prefix: '> ')),
              ),
              const _ToolbarDivider(),
              _ToolbarButton(
                icon: PhosphorIconsRegular.codeBlock,
                tooltip: 'Code Block (```)',
                onPressed: () => _handleCodeBlock(context),
                onLongPress: () => _handleCodeBlockLongPress(context),
              ),
              if (onTablePressed != null)
                _ToolbarButton(
                  icon: PhosphorIconsRegular.table,
                  tooltip: 'Insert Table',
                  onPressed: onTablePressed!,
                ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.link,
                tooltip: 'Link ([text](url))',
                onPressed: () => _handleLink(context),
              ),
              if (onNoteLinkPressed != null)
                _ToolbarButton(
                  icon: PhosphorIconsRegular.fileText,
                  tooltip: 'Link Note ([[Note]])',
                  onPressed: onNoteLinkPressed!,
                ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.tag,
                tooltip: 'Tag (#tag)',
                onPressed: onTagPressed,
              ),
              _ToolbarButton(
                icon: PhosphorIconsRegular.minus,
                tooltip: 'Divider (---)',
                onPressed: () => _applyHelperFormat((val) => MarkdownHelper.wrapSelection(value: val, prefix: '\n---\n', suffix: '')),
              ),
              if (onImagePressed != null || onScanPressed != null || onPdfPressed != null || onFilePressed != null) ...[
                const _ToolbarDivider(),
                if (onImagePressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.image,
                    tooltip: 'Attach Image',
                    onPressed: onImagePressed!,
                  ),
                if (onScanPressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.scan,
                    tooltip: 'Scan Document',
                    onPressed: onScanPressed!,
                  ),
                if (onPdfPressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.filePdf,
                    tooltip: 'Attach Document (PDF)',
                    onPressed: onPdfPressed!,
                  ),
                if (onFilePressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.paperclip,
                    tooltip: 'Attach File',
                    onPressed: onFilePressed!,
                  ),
              ],
              if (onDictatePressed != null) ...[
                const _ToolbarDivider(),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.microphone,
                  tooltip: 'Dictate',
                  isActive: isDictating,
                  isEnabled: canDictate,
                  onPressed: onDictatePressed!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      color: colors.divider,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.isActive = false,
    this.isEnabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool isActive;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final effectiveColor = !isEnabled
        ? colors.textTertiary.withValues(alpha: 0.3)
        : (isActive ? colors.accent : colors.textSecondary);

    final backgroundColor =
        isActive ? colors.accent.withValues(alpha: 0.12) : Colors.transparent;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadii.borderSm,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: AppRadii.borderSm,
          onTap: isEnabled ? onPressed : null,
          onLongPress: isEnabled ? onLongPress : null,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(
                icon,
                size: 19,
                color: effectiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
