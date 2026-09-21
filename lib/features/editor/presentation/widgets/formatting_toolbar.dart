import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/semantic_editor_controller.dart';
import 'heading/markdown_heading_action_sheet.dart';
import 'link_prompt_dialog.dart';

class FormattingToolbar extends StatefulWidget {
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
    this.isTopDocked = false,
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

  /// Whether the toolbar is docked at the top of the editor (desktop mode)
  /// or at the bottom above the keyboard (mobile mode).
  final bool isTopDocked;

  @override
  State<FormattingToolbar> createState() => _FormattingToolbarState();
}

class _FormattingToolbarState extends State<FormattingToolbar> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _headingButtonKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: widget.controller.value);
    widget.controller.value = updated;
    widget.onApplyAtomicEdit?.call(updated);
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      widget.focusNode!.requestFocus();
    }
  }

  void _applyHelperFormat(TextEditingValue Function(TextEditingValue) action) {
    final updated = action(widget.controller.value);
    widget.controller.value = updated;
    widget.onApplyAtomicEdit?.call(updated);
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      widget.focusNode!.requestFocus();
    }
  }

  Future<void> _handleLink(BuildContext context) async {
    final selection = widget.controller.selection;
    final text = widget.controller.text;
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
        value: widget.controller.value,
        url: result.url,
        title: result.title,
      );
      widget.controller.value = updated;
      widget.onApplyAtomicEdit?.call(updated);
      if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
        widget.focusNode!.requestFocus();
      }
    }
  }

  Future<void> _handleCodeBlock(BuildContext context) async {
    final effectiveValue = widget.controller.value;
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
          value: widget.controller.value,
          newLanguage: selected.id,
        );
        widget.controller.value = updated;
        widget.onApplyAtomicEdit?.call(updated);
        if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
          widget.focusNode!.requestFocus();
        }
      }
    } else {
      _applyHelperFormat(MarkdownHelper.insertCodeBlock);
    }
  }

  Future<void> _handleCodeBlockLongPress(BuildContext context) async {
    final effectiveValue = widget.controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: currentLang,
      title: currentLang != null ? 'Change Code Language' : 'Insert Code Block with Language',
    );
    if (selected != null) {
      if (currentLang != null) {
        final updated = MarkdownHelper.changeCodeBlockLanguage(
          value: widget.controller.value,
          newLanguage: selected.id,
        );
        widget.controller.value = updated;
        widget.onApplyAtomicEdit?.call(updated);
      } else {
        final updated = MarkdownHelper.insertCodeBlock(
          widget.controller.value,
          language: selected.id,
        );
        widget.controller.value = updated;
        widget.onApplyAtomicEdit?.call(updated);
      }
      if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
        widget.focusNode!.requestFocus();
      }
    }
  }

  Future<void> _showDesktopHeadingMenu(BuildContext context) async {
    final colors = context.appColors;
    final renderBox = _headingButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isTop = widget.isTopDocked;

    final position = RelativeRect.fromLTRB(
      offset.dx,
      isTop ? offset.dy + size.height + 4 : offset.dy - 300,
      offset.dx + size.width,
      isTop ? offset.dy + size.height + 4 : offset.dy,
    );

    int currentLevel = 0;
    if (widget.semanticController != null) {
      currentLevel = widget.semanticController!.activeHeadingLevel ?? 0;
    } else {
      currentLevel = MarkdownHelper.getHeadingLevelAt(widget.controller.value) ?? 0;
    }

    final selected = await showMenu<int>(
      context: context,
      position: position,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderMd,
        side: BorderSide(color: colors.divider),
      ),
      items: [
        _buildHeadingMenuItem(context, level: 0, label: 'Paragraph (Normal)', shortcut: 'Ctrl+Alt+0', isSelected: currentLevel == 0),
        const PopupMenuDivider(height: 1),
        _buildHeadingMenuItem(context, level: 1, label: 'Heading 1', shortcut: 'Ctrl+Alt+1', isSelected: currentLevel == 1),
        _buildHeadingMenuItem(context, level: 2, label: 'Heading 2', shortcut: 'Ctrl+Alt+2', isSelected: currentLevel == 2),
        _buildHeadingMenuItem(context, level: 3, label: 'Heading 3', shortcut: 'Ctrl+Alt+3', isSelected: currentLevel == 3),
        _buildHeadingMenuItem(context, level: 4, label: 'Heading 4', shortcut: 'Ctrl+Alt+4', isSelected: currentLevel == 4),
        _buildHeadingMenuItem(context, level: 5, label: 'Heading 5', shortcut: 'Ctrl+Alt+5', isSelected: currentLevel == 5),
        _buildHeadingMenuItem(context, level: 6, label: 'Heading 6', shortcut: 'Ctrl+Alt+6', isSelected: currentLevel == 6),
      ],
    );

    if (selected != null) {
      if (widget.semanticController != null) {
        if (selected == 0) {
          widget.semanticController!.convertHeadingToParagraph();
        } else {
          widget.semanticController!.setHeadingLevel(selected);
        }
        widget.focusNode?.requestFocus();
      } else {
        _applyHelperFormat((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: selected));
      }
    }
  }

  PopupMenuItem<int> _buildHeadingMenuItem(
    BuildContext context, {
    required int level,
    required String label,
    required String shortcut,
    required bool isSelected,
  }) {
    final colors = context.appColors;
    return PopupMenuItem<int>(
      value: level,
      height: 38,
      child: Row(
        children: [
          Icon(
            level == 0 ? PhosphorIconsRegular.paragraph : PhosphorIconsRegular.textH,
            size: 16,
            color: isSelected ? colors.accent : colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            shortcut,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleHeadingLongPress(BuildContext context) async {
    if (widget.semanticController != null) {
      final currentLevel = widget.semanticController!.activeHeadingLevel ?? 0;
      await MarkdownHeadingActionSheet.show(
        context,
        currentLevel: currentLevel,
        onSelectLevel: (newLevel) {
          widget.semanticController!.setHeadingLevel(newLevel);
          if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
            widget.focusNode!.requestFocus();
          }
        },
        onConvertToParagraph: () {
          widget.semanticController!.convertHeadingToParagraph();
          if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
            widget.focusNode!.requestFocus();
          }
        },
        onCycleLevel: () {
          widget.semanticController!.cycleHeadingLevel();
          if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
            widget.focusNode!.requestFocus();
          }
        },
      );
      return;
    }

    final effectiveValue = widget.controller.value;
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
    if (widget.semanticController != null) return widget.semanticController!.isBoldActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isBoldActive;
    }
    return MarkdownFormatter.isBoldAt(widget.controller.value);
  }

  bool _isItalicActive() {
    if (widget.semanticController != null) return widget.semanticController!.isItalicActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isItalicActive;
    }
    return MarkdownFormatter.isItalicAt(widget.controller.value);
  }

  bool _isStrikethroughActive() {
    if (widget.semanticController != null) return widget.semanticController!.isStrikeActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isStrikethroughActive;
    }
    return MarkdownFormatter.isStrikethroughAt(widget.controller.value);
  }

  bool _isInlineCodeActive() {
    if (widget.semanticController != null) return widget.semanticController!.isCodeActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isInlineCodeActive;
    }
    return MarkdownFormatter.isInlineCodeAt(widget.controller.value);
  }

  bool _isHeadingActive() {
    if (widget.semanticController != null) {
      return widget.semanticController!.activeHeadingLevel != null;
    }
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isHeadingActive;
    }
    return MarkdownFormatter.isHeadingAt(widget.controller.value);
  }

  bool _isChecklistActive() {
    if (widget.semanticController != null) return widget.semanticController!.isChecklistActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isChecklistActive;
    }
    return MarkdownFormatter.isChecklistAt(widget.controller.value);
  }

  bool _isBulletListActive() {
    if (widget.semanticController != null) return widget.semanticController!.isListActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isBulletListActive;
    }
    return MarkdownFormatter.isBulletListAt(widget.controller.value);
  }

  bool _isOrderedListActive() {
    if (widget.semanticController != null) return widget.semanticController!.isOrderedListActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isOrderedListActive;
    }
    return MarkdownFormatter.isOrderedListAt(widget.controller.value);
  }

  bool _isQuoteActive() {
    if (widget.semanticController != null) return widget.semanticController!.isQuoteActive;
    if (widget.controller is MarkdownEditingController) {
      return (widget.controller as MarkdownEditingController).isQuoteActive;
    }
    return MarkdownFormatter.isQuoteAt(widget.controller.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDesktop = widget.isTopDocked || PlatformLayoutHelper.isDesktopEditor(context);

    final border = widget.isTopDocked
        ? Border(bottom: BorderSide(color: colors.divider, width: 0.8))
        : Border(top: BorderSide(color: colors.divider, width: 0.8));

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        border: border,
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.controller,
          ?widget.semanticController,
        ]),
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

          return Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
                final delta = pointerSignal.scrollDelta.dy != 0
                    ? pointerSignal.scrollDelta.dy
                    : pointerSignal.scrollDelta.dx;
                final newOffset = (_scrollController.offset + delta)
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
                _scrollController.jumpTo(newOffset);
              }
            },
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _ToolbarButton(
                  icon: PhosphorIconsRegular.arrowUUpLeft,
                  tooltip: isDesktop ? 'Undo (Ctrl+Z)' : 'Undo',
                  isEnabled: widget.canUndo,
                  onPressed: widget.onUndo ?? () {},
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.arrowUUpRight,
                  tooltip: isDesktop ? 'Redo (Ctrl+Y)' : 'Redo',
                  isEnabled: widget.canRedo,
                  onPressed: widget.onRedo ?? () {},
                ),
                const _ToolbarDivider(),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.textB,
                  tooltip: isDesktop ? 'Bold (Ctrl+B)' : 'Bold (**text**)',
                  isActive: isBold,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleBold();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleBold);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.textItalic,
                  tooltip: isDesktop ? 'Italic (Ctrl+I)' : 'Italic (*text*)',
                  isActive: isItalic,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleItalic();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleItalic);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.textStrikethrough,
                  tooltip: isDesktop ? 'Strikethrough (Ctrl+Shift+X)' : 'Strikethrough (~~text~~)',
                  isActive: isStrikethrough,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleStrike();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleStrikethrough);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.code,
                  tooltip: isDesktop ? 'Inline Code (Ctrl+`)' : 'Inline Code (`text`)',
                  isActive: isCode,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleInlineCode();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleInlineCode);
                    }
                  },
                ),
                const _ToolbarDivider(),
                _ToolbarButton(
                  key: _headingButtonKey,
                  icon: PhosphorIconsRegular.textH,
                  tooltip: isDesktop ? 'Heading (Ctrl+Alt+1–6)' : 'Heading (cycle H1-H6, long-press for options)',
                  isActive: isHeading,
                  onPressed: () {
                    if (isDesktop) {
                      _showDesktopHeadingMenu(context);
                    } else {
                      if (widget.onCycleHeading != null) {
                        widget.onCycleHeading!();
                      } else if (widget.semanticController != null) {
                        widget.semanticController!.cycleHeadingLevel();
                        widget.focusNode?.requestFocus();
                      } else {
                        _applyHelperFormat(MarkdownHelper.cycleHeading);
                      }
                    }
                  },
                  onLongPress: widget.onCycleHeadingLongPress ?? () => _handleHeadingLongPress(context),
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.checkSquare,
                  tooltip: isDesktop ? 'Checklist (Ctrl+Shift+C)' : 'Checklist (- [ ])',
                  isActive: isChecklist,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleChecklist();
                      widget.focusNode?.requestFocus();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleChecklist);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.listBullets,
                  tooltip: isDesktop ? 'Bullet List (Ctrl+Shift+8)' : 'Bullet List (-)',
                  isActive: isBullet,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleList();
                      widget.focusNode?.requestFocus();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleBulletList);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.listNumbers,
                  tooltip: isDesktop ? 'Numbered List (Ctrl+Shift+7)' : 'Numbered List (1.)',
                  isActive: isOrdered,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleOrderedList();
                      widget.focusNode?.requestFocus();
                    } else {
                      _applyFormat(MarkdownFormatter.toggleOrderedList);
                    }
                  },
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.quotes,
                  tooltip: isDesktop ? 'Quote (Ctrl+Shift+.)' : 'Quote (>)',
                  isActive: isQuote,
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.toggleQuote();
                      widget.focusNode?.requestFocus();
                    } else {
                      _applyHelperFormat((val) => MarkdownHelper.toggleLinePrefix(value: val, prefix: '> '));
                    }
                  },
                ),
                const _ToolbarDivider(),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.codeBlock,
                  tooltip: isDesktop ? 'Code Block (Ctrl+Alt+C)' : 'Code Block (```)',
                  onPressed: () => _handleCodeBlock(context),
                  onLongPress: () => _handleCodeBlockLongPress(context),
                ),
                if (widget.onTablePressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.table,
                    tooltip: isDesktop ? 'Insert Table (Ctrl+Alt+T)' : 'Insert Table',
                    onPressed: widget.onTablePressed!,
                  ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.link,
                  tooltip: isDesktop ? 'Link (Ctrl+K)' : 'Link ([text](url))',
                  onPressed: () => _handleLink(context),
                ),
                if (widget.onNoteLinkPressed != null)
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.fileText,
                    tooltip: isDesktop ? 'Link Note (Ctrl+Shift+L)' : 'Link Note ([[Note]])',
                    onPressed: widget.onNoteLinkPressed!,
                  ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.tag,
                  tooltip: isDesktop ? 'Tag (Ctrl+Shift+T)' : 'Tag (#tag)',
                  onPressed: widget.onTagPressed,
                ),
                _ToolbarButton(
                  icon: PhosphorIconsRegular.minus,
                  tooltip: isDesktop ? 'Divider (Ctrl+Alt+-)' : 'Divider (---)',
                  onPressed: () {
                    if (widget.semanticController != null) {
                      widget.semanticController!.insertHorizontalRule();
                      widget.onApplyAtomicEdit?.call(widget.controller.value);
                      widget.focusNode?.requestFocus();
                    } else {
                      _applyHelperFormat(MarkdownHelper.insertHorizontalRule);
                    }
                  },
                ),
                if (widget.onImagePressed != null ||
                    widget.onScanPressed != null ||
                    widget.onPdfPressed != null ||
                    widget.onFilePressed != null) ...[
                  const _ToolbarDivider(),
                  if (widget.onImagePressed != null)
                    _ToolbarButton(
                      icon: PhosphorIconsRegular.image,
                      tooltip: 'Attach Image',
                      onPressed: widget.onImagePressed!,
                    ),
                  if (widget.onScanPressed != null)
                    _ToolbarButton(
                      icon: PhosphorIconsRegular.scan,
                      tooltip: 'Scan Document',
                      onPressed: widget.onScanPressed!,
                    ),
                  if (widget.onPdfPressed != null)
                    _ToolbarButton(
                      icon: PhosphorIconsRegular.filePdf,
                      tooltip: 'Attach Document (PDF)',
                      onPressed: widget.onPdfPressed!,
                    ),
                  if (widget.onFilePressed != null)
                    _ToolbarButton(
                      icon: PhosphorIconsRegular.paperclip,
                      tooltip: 'Attach File',
                      onPressed: widget.onFilePressed!,
                    ),
                ],
                if (widget.onDictatePressed != null) ...[
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: PhosphorIconsRegular.microphone,
                    tooltip: 'Dictate',
                    isActive: widget.isDictating,
                    isEnabled: widget.canDictate,
                    onPressed: widget.onDictatePressed!,
                  ),
                ],
              ],
            ),
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
    super.key,
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
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadii.borderSm,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: AppRadii.borderSm,
          mouseCursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          hoverColor: colors.accent.withValues(alpha: 0.08),
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
