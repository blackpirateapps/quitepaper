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
import 'formatting_hub_sheet.dart';
import 'heading/markdown_heading_action_sheet.dart';
import 'link_prompt_dialog.dart';

/// Bear Notes-inspired formatting toolbar for Quiet Paper.
///
/// Features:
/// - Segmented pill groups for History, Format Hub, Heading, Inline Styles, Lists, Inserts, and Dictation.
/// - Prominent `Aa` button opening the comprehensive [FormattingHubSheet].
/// - Dynamic heading badge indicating current heading level (H, H1..H6).
/// - Consolidated Insert `+` dropdown menu on desktop and bottom sheet on mobile.
/// - Adaptive layout for mobile, tablet, and desktop environments.
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
  final GlobalKey _insertButtonKey = GlobalKey();

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
    // WYSIWYG mode: route through the semantic controller. Operating on
    // `widget.controller` here would inject literal `[title](url)` into a single
    // block's plain-text controller, which is never committed to the document
    // and is discarded on the next block sync.
    if (widget.semanticController != null) {
      final sc = widget.semanticController!;
      var initialTitle = '';
      final sel = sc.selection;
      if (sel.isValid && !sel.isCollapsed) {
        initialTitle = sc.document.sourceRangeAtSelection(sel).slice(sc.markdown);
      }
      final result = await LinkPromptDialog.show(context, initialTitle: initialTitle);
      if (result != null) {
        sc.toggleLink(url: result.url, title: result.title);
      }
      return;
    }

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
    // WYSIWYG mode: route through the semantic controller for the same reason
    // as _handleLink — the raw block controller edit would never be committed.
    if (widget.semanticController != null) {
      final sc = widget.semanticController!;
      final currentLang = sc.activeCodeBlockLanguage;
      if (sc.isCodeBlockActive) {
        final selected = await LanguageSelectorSheet.show(
          context,
          currentLanguageId: currentLang,
          title: 'Change Code Language',
        );
        if (selected != null) {
          sc.changeCodeBlockLanguage(sc.selection.base.blockId, selected.id);
        }
      } else {
        sc.insertCodeBlock();
      }
      return;
    }

    final effectiveValue = widget.controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(effectiveValue);
    if (currentLang != null) {
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

  int _getActiveHeadingLevel() {
    if (widget.semanticController != null) {
      return widget.semanticController!.activeHeadingLevel ?? 0;
    }
    return MarkdownHelper.getHeadingLevelAt(widget.controller.value) ?? 0;
  }

  void _setHeadingLevel(int level) {
    if (widget.semanticController != null) {
      if (level == 0) {
        widget.semanticController!.convertHeadingToParagraph();
      } else {
        widget.semanticController!.setHeadingLevel(level);
      }
      widget.focusNode?.requestFocus();
    } else {
      _applyHelperFormat((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: level));
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

    final currentLevel = _getActiveHeadingLevel();

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
      _setHeadingLevel(selected);
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

  void _openFormatHub(BuildContext context) {
    FormattingHubSheet.show(
      context,
      isBold: _isBoldActive(),
      isItalic: _isItalicActive(),
      isStrikethrough: _isStrikethroughActive(),
      isCode: _isInlineCodeActive(),
      headingLevel: _getActiveHeadingLevel(),
      isChecklist: _isChecklistActive(),
      isBullet: _isBulletListActive(),
      isOrdered: _isOrderedListActive(),
      isQuote: _isQuoteActive(),
      hasTable: widget.onTablePressed != null,
      hasNoteLink: widget.onNoteLinkPressed != null,
      hasImage: widget.onImagePressed != null,
      hasScan: widget.onScanPressed != null,
      hasPdf: widget.onPdfPressed != null,
      hasFile: widget.onFilePressed != null,
      onSelectFormat: (option) => _handleFormatOption(context, option),
    );
  }

  void _handleFormatOption(BuildContext context, FormattingOption option) {
    switch (option) {
      case FormattingOption.bold:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleBold();
        } else {
          _applyFormat(MarkdownFormatter.toggleBold);
        }
        break;
      case FormattingOption.italic:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleItalic();
        } else {
          _applyFormat(MarkdownFormatter.toggleItalic);
        }
        break;
      case FormattingOption.strikethrough:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleStrike();
        } else {
          _applyFormat(MarkdownFormatter.toggleStrikethrough);
        }
        break;
      case FormattingOption.inlineCode:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleInlineCode();
        } else {
          _applyFormat(MarkdownFormatter.toggleInlineCode);
        }
        break;
      case FormattingOption.paragraph:
        _setHeadingLevel(0);
        break;
      case FormattingOption.heading1:
        _setHeadingLevel(1);
        break;
      case FormattingOption.heading2:
        _setHeadingLevel(2);
        break;
      case FormattingOption.heading3:
        _setHeadingLevel(3);
        break;
      case FormattingOption.quote:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleQuote();
          widget.focusNode?.requestFocus();
        } else {
          _applyHelperFormat((val) => MarkdownHelper.toggleLinePrefix(value: val, prefix: '> '));
        }
        break;
      case FormattingOption.codeBlock:
        _handleCodeBlock(context);
        break;
      case FormattingOption.checklist:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleChecklist();
          widget.focusNode?.requestFocus();
        } else {
          _applyFormat(MarkdownFormatter.toggleChecklist);
        }
        break;
      case FormattingOption.bulletList:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleList();
          widget.focusNode?.requestFocus();
        } else {
          _applyFormat(MarkdownFormatter.toggleBulletList);
        }
        break;
      case FormattingOption.orderedList:
        if (widget.semanticController != null) {
          widget.semanticController!.toggleOrderedList();
          widget.focusNode?.requestFocus();
        } else {
          _applyFormat(MarkdownFormatter.toggleOrderedList);
        }
        break;
      case FormattingOption.divider:
        if (widget.semanticController != null) {
          widget.semanticController!.insertHorizontalRule();
          widget.onApplyAtomicEdit?.call(widget.controller.value);
          widget.focusNode?.requestFocus();
        } else {
          _applyHelperFormat(MarkdownHelper.insertHorizontalRule);
        }
        break;
      case FormattingOption.table:
        widget.onTablePressed?.call();
        break;
      case FormattingOption.link:
        _handleLink(context);
        break;
      case FormattingOption.noteLink:
        widget.onNoteLinkPressed?.call();
        break;
      case FormattingOption.tag:
        widget.onTagPressed();
        break;
      case FormattingOption.image:
        widget.onImagePressed?.call();
        break;
      case FormattingOption.scan:
        widget.onScanPressed?.call();
        break;
      case FormattingOption.pdf:
        widget.onPdfPressed?.call();
        break;
      case FormattingOption.file:
        widget.onFilePressed?.call();
        break;
    }
  }

  Future<void> _showInsertMenu(BuildContext context) async {
    final colors = context.appColors;
    final isDesktop = widget.isTopDocked || PlatformLayoutHelper.isDesktopEditor(context);
    final renderBox = _insertButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null && isDesktop) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final isTop = widget.isTopDocked;

      final position = RelativeRect.fromLTRB(
        offset.dx,
        isTop ? offset.dy + size.height + 4 : offset.dy - 350,
        offset.dx + size.width,
        isTop ? offset.dy + size.height + 4 : offset.dy,
      );

      final selected = await showMenu<String>(
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
          if (widget.onTablePressed != null)
            _buildInsertMenuItem(
              context,
              value: 'table',
              icon: PhosphorIconsRegular.table,
              label: 'Table',
              shortcut: 'Ctrl+Alt+T',
            ),
          _buildInsertMenuItem(
            context,
            value: 'link',
            icon: PhosphorIconsRegular.link,
            label: 'Web Link',
            shortcut: 'Ctrl+K',
          ),
          if (widget.onNoteLinkPressed != null)
            _buildInsertMenuItem(
              context,
              value: 'note_link',
              icon: PhosphorIconsRegular.fileText,
              label: 'Link Note',
              shortcut: 'Ctrl+Shift+L',
            ),
          _buildInsertMenuItem(
            context,
            value: 'code_block',
            icon: PhosphorIconsRegular.codeBlock,
            label: 'Code Block',
            shortcut: 'Ctrl+Alt+C',
          ),
          _buildInsertMenuItem(
            context,
            value: 'tag',
            icon: PhosphorIconsRegular.tag,
            label: 'Tag',
            shortcut: 'Ctrl+Shift+T',
          ),
          _buildInsertMenuItem(
            context,
            value: 'divider',
            icon: PhosphorIconsRegular.minus,
            label: 'Divider Line',
            shortcut: 'Ctrl+Alt+-',
          ),
          if (widget.onImagePressed != null ||
              widget.onScanPressed != null ||
              widget.onPdfPressed != null ||
              widget.onFilePressed != null) ...[
            const PopupMenuDivider(height: 1),
            if (widget.onImagePressed != null)
              _buildInsertMenuItem(
                context,
                value: 'image',
                icon: PhosphorIconsRegular.image,
                label: 'Attach Image',
              ),
            if (widget.onScanPressed != null)
              _buildInsertMenuItem(
                context,
                value: 'scan',
                icon: PhosphorIconsRegular.scan,
                label: 'Scan Document',
              ),
            if (widget.onPdfPressed != null)
              _buildInsertMenuItem(
                context,
                value: 'pdf',
                icon: PhosphorIconsRegular.filePdf,
                label: 'Attach PDF',
              ),
            if (widget.onFilePressed != null)
              _buildInsertMenuItem(
                context,
                value: 'file',
                icon: PhosphorIconsRegular.paperclip,
                label: 'Attach File',
              ),
          ],
        ],
      );

      if (selected != null) {
        _handleInsertSelection(selected);
      }
    } else {
      // Mobile bottom action sheet
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text(
                      'Insert',
                      style: AppTypography.headline.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.onTablePressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.table, color: colors.textPrimary),
                        title: const Text('Table'),
                        onTap: () => Navigator.of(ctx).pop('table'),
                      ),
                    ListTile(
                      leading: Icon(PhosphorIconsRegular.link, color: colors.textPrimary),
                      title: const Text('Web Link'),
                      onTap: () => Navigator.of(ctx).pop('link'),
                    ),
                    if (widget.onNoteLinkPressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.fileText, color: colors.textPrimary),
                        title: const Text('Link Note'),
                        onTap: () => Navigator.of(ctx).pop('note_link'),
                      ),
                    ListTile(
                      leading: Icon(PhosphorIconsRegular.codeBlock, color: colors.textPrimary),
                      title: const Text('Code Block'),
                      onTap: () => Navigator.of(ctx).pop('code_block'),
                    ),
                    ListTile(
                      leading: Icon(PhosphorIconsRegular.tag, color: colors.textPrimary),
                      title: const Text('Tag'),
                      onTap: () => Navigator.of(ctx).pop('tag'),
                    ),
                    ListTile(
                      leading: Icon(PhosphorIconsRegular.minus, color: colors.textPrimary),
                      title: const Text('Divider Line'),
                      onTap: () => Navigator.of(ctx).pop('divider'),
                    ),
                    if (widget.onImagePressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.image, color: colors.textPrimary),
                        title: const Text('Attach Image'),
                        onTap: () => Navigator.of(ctx).pop('image'),
                      ),
                    if (widget.onScanPressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.scan, color: colors.textPrimary),
                        title: const Text('Scan Document'),
                        onTap: () => Navigator.of(ctx).pop('scan'),
                      ),
                    if (widget.onPdfPressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.filePdf, color: colors.textPrimary),
                        title: const Text('Attach PDF'),
                        onTap: () => Navigator.of(ctx).pop('pdf'),
                      ),
                    if (widget.onFilePressed != null)
                      ListTile(
                        leading: Icon(PhosphorIconsRegular.paperclip, color: colors.textPrimary),
                        title: const Text('Attach File'),
                        onTap: () => Navigator.of(ctx).pop('file'),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (selected != null) {
        _handleInsertSelection(selected);
      }
    }
  }

  PopupMenuItem<String> _buildInsertMenuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
    String shortcut = '',
  }) {
    final colors = context.appColors;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          if (shortcut.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              shortcut,
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleInsertSelection(String selected) {
    switch (selected) {
      case 'table':
        widget.onTablePressed?.call();
        break;
      case 'link':
        _handleLink(context);
        break;
      case 'note_link':
        widget.onNoteLinkPressed?.call();
        break;
      case 'code_block':
        _handleCodeBlock(context);
        break;
      case 'tag':
        widget.onTagPressed();
        break;
      case 'divider':
        if (widget.semanticController != null) {
          widget.semanticController!.insertHorizontalRule();
          widget.onApplyAtomicEdit?.call(widget.controller.value);
          widget.focusNode?.requestFocus();
        } else {
          _applyHelperFormat(MarkdownHelper.insertHorizontalRule);
        }
        break;
      case 'image':
        widget.onImagePressed?.call();
        break;
      case 'scan':
        widget.onScanPressed?.call();
        break;
      case 'pdf':
        widget.onPdfPressed?.call();
        break;
      case 'file':
        widget.onFilePressed?.call();
        break;
    }
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
          final headingLevel = _getActiveHeadingLevel();
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              children: [
                // 1. HISTORY GROUP (Undo, Redo)
                _ToolbarPillGroup(
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
                  ],
                ),

                // 2. BEAR-STYLE FORMAT HUB TRIGGER (Aa)
                _ToolbarPillGroup(
                  backgroundColor: colors.accent.withValues(alpha: 0.08),
                  children: [
                    _ToolbarButton(
                      icon: PhosphorIconsRegular.textAa,
                      tooltip: isDesktop
                          ? 'All Formatting Options (Aa)'
                          : 'Format & Structure Catalog',
                      onPressed: () => _openFormatHub(context),
                    ),
                  ],
                ),

                // 3. HEADING GROUP
                _ToolbarPillGroup(
                  children: [
                    _ToolbarButton(
                      key: _headingButtonKey,
                      icon: PhosphorIconsRegular.textH,
                      badgeText: headingLevel > 0 ? '$headingLevel' : null,
                      tooltip: isDesktop
                          ? 'Heading (Ctrl+Alt+1–6)'
                          : 'Heading (cycle H1-H6, long-press for options)',
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
                      onLongPress: widget.onCycleHeadingLongPress ??
                          () => _handleHeadingLongPress(context),
                    ),
                  ],
                ),

                // 4. INLINE STYLES GROUP (B, I, S, </>)
                _ToolbarPillGroup(
                  children: [
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
                      tooltip: isDesktop
                          ? 'Strikethrough (Ctrl+Shift+X)'
                          : 'Strikethrough (~~text~~)',
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
                      tooltip: isDesktop
                          ? 'Inline Code (Ctrl+`)'
                          : 'Inline Code (`text`)',
                      isActive: isCode,
                      onPressed: () {
                        if (widget.semanticController != null) {
                          widget.semanticController!.toggleInlineCode();
                        } else {
                          _applyFormat(MarkdownFormatter.toggleInlineCode);
                        }
                      },
                    ),
                  ],
                ),

                // 5. LISTS & STRUCTURE GROUP (Checklist, Bullets, Numbers, Quote)
                _ToolbarPillGroup(
                  children: [
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
                          _applyHelperFormat(
                              (val) => MarkdownHelper.toggleLinePrefix(value: val, prefix: '> '));
                        }
                      },
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
                  ],
                ),

                // 6. CONSOLIDATED INSERT DROPDOWN (+)
                _ToolbarPillGroup(
                  children: [
                    _ToolbarButton(
                      key: _insertButtonKey,
                      icon: PhosphorIconsRegular.plus,
                      tooltip: isDesktop ? 'Insert Options (Table, Link, Media)' : 'Insert...',
                      onPressed: () => _showInsertMenu(context),
                    ),
                  ],
                ),

                // 7. ATTACHMENTS & MEDIA GROUP
                if (widget.onImagePressed != null ||
                    widget.onScanPressed != null ||
                    widget.onPdfPressed != null ||
                    widget.onFilePressed != null) ...[
                  _ToolbarPillGroup(
                    children: [
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
                  ),
                ],

                // 8. DICTATION BUTTON
                if (widget.onDictatePressed != null) ...[
                  _ToolbarPillGroup(
                    backgroundColor: widget.isDictating
                        ? colors.accent.withValues(alpha: 0.18)
                        : null,
                    children: [
                      _ToolbarButton(
                        icon: PhosphorIconsRegular.microphone,
                        tooltip: 'Dictate',
                        isActive: widget.isDictating,
                        isEnabled: widget.canDictate,
                        onPressed: widget.onDictatePressed!,
                      ),
                    ],
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

class _ToolbarPillGroup extends StatelessWidget {
  const _ToolbarPillGroup({
    required this.children,
    this.backgroundColor,
  });

  final List<Widget> children;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveBg = backgroundColor ?? colors.divider.withValues(alpha: 0.14);

    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: AppRadii.borderMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeText,
    this.onLongPress,
    this.isActive = false,
    this.isEnabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? badgeText;
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
            width: badgeText != null ? 38 : 32,
            height: 30,
            child: Center(
              child: badgeText != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: effectiveColor),
                        const SizedBox(width: 1),
                        Text(
                          badgeText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: effectiveColor,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      icon,
                      size: 17,
                      color: effectiveColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
