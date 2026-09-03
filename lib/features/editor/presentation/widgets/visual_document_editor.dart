import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../application/markdown_table_controller.dart';
import '../../application/semantic_editor_controller.dart';
import '../../domain/document_position.dart';
import '../../domain/markdown_styles.dart';
import '../../domain/markdown_table.dart';
import '../../domain/markdown_table_position.dart';
import '../../domain/semantic_nodes.dart';
import 'heading/markdown_heading_action_sheet.dart';
import 'heading/markdown_heading_badge.dart';
import 'link_prompt_dialog.dart';
import 'table/markdown_table_editor.dart';
import 'table/markdown_table_view.dart';

/// Complete semantic visual document editor widget for Quiet Paper (V4).
///
/// **Architectural Rule**: The user edits real visual document blocks and inline runs.
/// Markdown syntax delimiters are never rendered in editable text fields.
class VisualDocumentEditor extends StatefulWidget {
  const VisualDocumentEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.hintText = 'Start writing...',
    this.searchQuery,
    this.onActiveTargetChanged,
    this.onNoteLinkPrompt,
    this.onChanged,
  });

  final SemanticEditorController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String hintText;
  final String? searchQuery;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final VoidCallback? onNoteLinkPrompt;
  final ValueChanged<String>? onChanged;

  @override
  State<VisualDocumentEditor> createState() => _VisualDocumentEditorState();
}

class _VisualDocumentEditorState extends State<VisualDocumentEditor> {
  MarkdownTable? _activeTable;
  MarkdownTableController? _activeTableController;

  final Map<String, TextEditingController> _blockControllers = {};
  final Map<String, FocusNode> _blockFocusNodes = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncBlockControllers();
  }

  @override
  void didUpdateWidget(VisualDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncBlockControllers();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final ctrl in _blockControllers.values) {
      ctrl.dispose();
    }
    for (final fn in _blockFocusNodes.values) {
      fn.dispose();
    }
    _activeTableController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _syncBlockControllers();
    if (mounted) setState(() {});
  }

  void _syncBlockControllers() {
    final doc = widget.controller.document;
    final liveIds = <String>{};
    final wasFocused = _blockFocusNodes.values.any((fn) => fn.hasFocus);

    void registerBlock(SemanticBlock block) {
      liveIds.add(block.id);
      if (!_blockControllers.containsKey(block.id)) {
        final ctrl = _RichBlockEditingController(
          block: block,
          styles: widget.controller.styles,
          searchQuery: widget.searchQuery,
        );
        _blockControllers[block.id] = ctrl;
      } else {
        final ctrl = _blockControllers[block.id]!;
        if (ctrl is _RichBlockEditingController) {
          ctrl.updateBlock(block, widget.controller.styles, widget.searchQuery);
        } else if (ctrl.text != block.plainText) {
          ctrl.text = block.plainText;
        }
      }

      if (!_blockFocusNodes.containsKey(block.id)) {
        final fn = FocusNode(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (event.logicalKey == LogicalKeyboardKey.backspace) {
                final ctrl = _blockControllers[block.id];
                if (ctrl != null && ctrl.selection.isCollapsed && ctrl.selection.start == 0) {
                  widget.controller.mergeWithPreviousBlock(block.id);
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
        );
        fn.addListener(() => _handleBlockFocus(block.id, fn));
        _blockFocusNodes[block.id] = fn;
      }
    }

    for (final block in doc.blocks) {
      if (block is ListBlock) {
        for (final item in block.items) {
          registerBlock(item);
        }
      } else if (block is OrderedListBlock) {
        for (final item in block.items) {
          registerBlock(item);
        }
      } else if (block is ChecklistBlock) {
        for (final item in block.items) {
          registerBlock(item);
        }
      } else {
        registerBlock(block);
      }
    }

    if (wasFocused) {
      final targetBlockId = widget.controller.selection.base.blockId;
      final targetOffset = widget.controller.selection.base.offset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetFn = _blockFocusNodes[targetBlockId];
        if (targetFn != null && !targetFn.hasFocus) {
          targetFn.requestFocus();
        }
        final targetCtrl = _blockControllers[targetBlockId];
        if (targetCtrl != null) {
          targetCtrl.selection = TextSelection.collapsed(
            offset: targetOffset.clamp(0, targetCtrl.text.length),
          );
        }
      });
    }

    // Clean up unmounted block controllers safely after frame
    final deadIds = _blockControllers.keys.where((id) => !liveIds.contains(id)).toList();
    if (deadIds.isNotEmpty) {
      final deadCtrls = <TextEditingController>[];
      final deadFns = <FocusNode>[];
      for (final deadId in deadIds) {
        final c = _blockControllers.remove(deadId);
        if (c != null) deadCtrls.add(c);
        final f = _blockFocusNodes.remove(deadId);
        if (f != null) deadFns.add(f);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in deadCtrls) {
          c.dispose();
        }
        for (final f in deadFns) {
          f.dispose();
        }
      });
    }
  }

  void _handleBlockFocus(String blockId, FocusNode node) {
    if (!mounted) return;
    if (node.hasFocus) {
      final ctrl = _blockControllers[blockId];
      if (ctrl != null) {
        widget.onActiveTargetChanged?.call(ctrl, node);
        widget.controller.selection = DocumentSelection.collapsed(
          DocumentPosition(blockId: blockId, offset: ctrl.selection.baseOffset.clamp(0, ctrl.text.length)),
        );
      }
    }
  }

  void _activateTable(MarkdownTable table, [TablePosition? position]) {
    if (widget.readOnly) return;
    _activeTableController?.dispose();
    _activeTable = table;

    final controller = MarkdownTableController(
      table: table,
      getDocumentValue: () => TextEditingValue(
        text: widget.controller.markdown,
        selection: TextSelection.collapsed(offset: table.sourceStart),
      ),
      onUpdateDocument: (newVal) {
        widget.controller.markdown = newVal.text;
        widget.onChanged?.call(newVal.text);
      },
      initialPosition: position ?? const TablePosition(row: 0, column: 0),
      styles: widget.controller.styles,
    );
    _activeTableController = controller;
    widget.onActiveTargetChanged?.call(controller.cellController, controller.cellFocusNode);
    setState(() {});
  }

  void _deactivateTable() {
    _activeTableController?.dispose();
    _activeTableController = null;
    _activeTable = null;
    if (_blockControllers.isNotEmpty) {
      final firstKey = _blockControllers.keys.first;
      widget.onActiveTargetChanged?.call(_blockControllers[firstKey]!, _blockFocusNodes[firstKey]!);
    }
    if (mounted) setState(() {});
  }

  Future<void> _promptLink(BuildContext context, String blockId) async {
    final ctrl = _blockControllers[blockId];
    var initialTitle = '';
    if (ctrl != null && ctrl.selection.isValid && !ctrl.selection.isCollapsed) {
      final s = ctrl.selection.start.clamp(0, ctrl.text.length);
      final e = ctrl.selection.end.clamp(s, ctrl.text.length);
      initialTitle = ctrl.text.substring(s, e);
    }

    final result = await LinkPromptDialog.show(context, initialTitle: initialTitle);
    if (result != null) {
      widget.controller.toggleLink(url: result.url, title: result.title);
      widget.onChanged?.call(widget.controller.markdown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final doc = widget.controller.document;

    final blockWidgets = <Widget>[];

    for (var i = 0; i < doc.blocks.length; i++) {
      final block = doc.blocks[i];
      blockWidgets.add(_buildBlockWidget(context, colors, block, i));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  Widget _buildBlockWidget(
    BuildContext context,
    AppColors colors,
    SemanticBlock block,
    int index,
  ) {
    if (block is TableBlock) {
      final isActive = _activeTable != null && _activeTable!.sourceStart == block.table.sourceStart;
      if (isActive && _activeTableController != null) {
        return MarkdownTableEditor(
          key: ValueKey('table_editor_${block.id}'),
          controller: _activeTableController!,
          styles: widget.controller.styles,
          searchQuery: widget.searchQuery,
          onClose: _deactivateTable,
        );
      } else {
        return MarkdownTableView(
          key: ValueKey('table_view_${block.id}'),
          table: block.table,
          styles: widget.controller.styles,
          readOnly: widget.readOnly,
          searchQuery: widget.searchQuery,
          onCellTap: (pos) => _activateTable(block.table, pos),
        );
      }
    }

    if (block is CodeBlock) {
      return _buildCodeBlockItem(context, colors, block);
    }

    if (block is HorizontalRuleBlock) {
      return _buildHorizontalRuleItem(context, colors, block);
    }

    if (block is ImageBlock) {
      return _buildImageBlockItem(context, colors, block);
    }

    if (block is ChecklistBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in block.items) _buildChecklistItem(context, colors, item),
        ],
      );
    }

    if (block is ListBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in block.items) _buildListItem(context, colors, item),
        ],
      );
    }

    if (block is OrderedListBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in block.items) _buildOrderedListItem(context, colors, item),
        ],
      );
    }

    if (block is ChecklistItemBlock) {
      return _buildChecklistItem(context, colors, block);
    }

    if (block is ListItemBlock) {
      return _buildListItem(context, colors, block);
    }

    if (block is OrderedListItemBlock) {
      return _buildOrderedListItem(context, colors, block);
    }

    if (block is QuoteBlock) {
      return _buildQuoteBlockItem(context, colors, block);
    }

    if (block is HeadingBlock) {
      return _buildHeadingBlockItem(context, colors, block);
    }

    if (block is ParagraphBlock) {
      return _buildParagraphBlockItem(context, colors, block, isFirst: index == 0);
    }

    if (block is UnsupportedMarkdownBlock) {
      return _buildUnsupportedBlockItem(context, colors, block);
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // Individual Block Builders
  // ---------------------------------------------------------------------------

  void _showHeadingActionSheet(BuildContext context, HeadingBlock block) {
    if (widget.readOnly) return;
    MarkdownHeadingActionSheet.show(
      context,
      currentLevel: block.level,
      onSelectLevel: (newLevel) {
        widget.controller.setHeadingLevelForBlock(block.id, newLevel);
        widget.onChanged?.call(widget.controller.markdown);
      },
      onConvertToParagraph: () {
        widget.controller.convertHeadingToParagraph(blockId: block.id);
        widget.onChanged?.call(widget.controller.markdown);
      },
      onCycleLevel: () {
        widget.controller.cycleHeadingLevel(blockId: block.id);
        widget.onChanged?.call(widget.controller.markdown);
      },
      onDeleteHeading: () {
        widget.controller.deleteBlock(block.id);
        widget.onChanged?.call(widget.controller.markdown);
      },
    );
  }

  Widget _buildHeadingBlockItem(
    BuildContext context,
    AppColors colors,
    HeadingBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final headingStyle = widget.controller.styles?.getHeadingStyle(block.level) ??
        AppTypography.editorH1.copyWith(color: colors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: MarkdownHeadingBadge(
              level: block.level,
              enabled: !widget.readOnly,
              onTap: () => _showHeadingActionSheet(context, block),
            ),
          ),
          Expanded(
            child: _buildBlockTextField(
              context: context,
              colors: colors,
              blockId: block.id,
              controller: ctrl,
              focusNode: fn,
              textStyle: headingStyle,
              hintText: 'Heading ${block.level}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraphBlockItem(
    BuildContext context,
    AppColors colors,
    ParagraphBlock block, {
    bool isFirst = false,
  }) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final bodyStyle = widget.controller.styles?.body ??
        AppTypography.editorBody.copyWith(color: colors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: _buildBlockTextField(
        context: context,
        colors: colors,
        blockId: block.id,
        controller: ctrl,
        focusNode: fn,
        textStyle: bodyStyle,
        hintText: isFirst ? widget.hintText : '',
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context,
    AppColors colors,
    ChecklistItemBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final baseStyle = widget.controller.styles?.body ??
        AppTypography.editorBody.copyWith(color: colors.textPrimary);
    final textStyle = block.checked
        ? (widget.controller.styles?.taskTextCompleted ??
            baseStyle.copyWith(
              color: colors.textSecondary.withValues(alpha: 0.6),
              decoration: TextDecoration.lineThrough,
            ))
        : baseStyle;

    return Padding(
      padding: EdgeInsets.only(
        left: (block.indent * 12.0),
        top: 2.0,
        bottom: 2.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Real interactive checkbox control
          GestureDetector(
            onTap: widget.readOnly
                ? null
                : () {
                    widget.controller.toggleChecklistState(block.id);
                    widget.onChanged?.call(widget.controller.markdown);
                  },
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 8.0),
              child: Icon(
                block.checked
                    ? PhosphorIconsFill.checkSquare
                    : PhosphorIconsRegular.square,
                size: 20,
                color: block.checked ? colors.accent : colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: _buildBlockTextField(
              context: context,
              colors: colors,
              blockId: block.id,
              controller: ctrl,
              focusNode: fn,
              textStyle: textStyle,
              hintText: 'To-do item...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    AppColors colors,
    ListItemBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final bodyStyle = widget.controller.styles?.body ??
        AppTypography.editorBody.copyWith(color: colors.textPrimary);

    return Padding(
      padding: EdgeInsets.only(
        left: (block.indent * 12.0),
        top: 2.0,
        bottom: 2.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 4.0, right: 10.0),
            child: Text(
              '•',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
          ),
          Expanded(
            child: _buildBlockTextField(
              context: context,
              colors: colors,
              blockId: block.id,
              controller: ctrl,
              focusNode: fn,
              textStyle: bodyStyle,
              hintText: 'List item...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderedListItem(
    BuildContext context,
    AppColors colors,
    OrderedListItemBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final bodyStyle = widget.controller.styles?.body ??
        AppTypography.editorBody.copyWith(color: colors.textPrimary);

    return Padding(
      padding: EdgeInsets.only(
        left: (block.indent * 12.0),
        top: 2.0,
        bottom: 2.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 4.0, right: 8.0),
            child: Text(
              '${block.number}${block.delimiter}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
          Expanded(
            child: _buildBlockTextField(
              context: context,
              colors: colors,
              blockId: block.id,
              controller: ctrl,
              focusNode: fn,
              textStyle: bodyStyle,
              hintText: 'Numbered item...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteBlockItem(
    BuildContext context,
    AppColors colors,
    QuoteBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final quoteStyle = widget.controller.styles?.blockquote ??
        AppTypography.editorBody.copyWith(
          color: colors.textSecondary,
          fontStyle: FontStyle.italic,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: colors.accent.withValues(alpha: 0.7), width: 3.0),
          ),
        ),
        padding: const EdgeInsets.only(left: 12.0),
        child: _buildBlockTextField(
          context: context,
          colors: colors,
          blockId: block.id,
          controller: ctrl,
          focusNode: fn,
          textStyle: quoteStyle,
          hintText: 'Quote...',
        ),
      ),
    );
  }

  Widget _buildHorizontalRuleItem(
    BuildContext context,
    AppColors colors,
    HorizontalRuleBlock block,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.divider,
      ),
    );
  }

  Widget _buildCodeBlockItem(
    BuildContext context,
    AppColors colors,
    CodeBlock block,
  ) {
    final ctrl = _blockControllers[block.id];
    final fn = _blockFocusNodes[block.id];
    if (ctrl == null || fn == null) return const SizedBox.shrink();

    final codeStyle = widget.controller.styles?.codeBlock ??
        AppTypography.editorCode.copyWith(color: colors.textPrimary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar with language selector pill & copy button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.readOnly
                      ? null
                      : () async {
                          final selected = await LanguageSelectorSheet.show(
                            context,
                            currentLanguageId: block.language,
                            title: 'Select Code Language',
                          );
                          if (selected != null) {
                            widget.controller.changeCodeBlockLanguage(block.id, selected.id);
                            widget.onChanged?.call(widget.controller.markdown);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: colors.tagBackground,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      block.language?.isNotEmpty == true ? block.language! : 'plain text',
                      style: AppTypography.caption.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIconsRegular.copy, size: 16, color: colors.textTertiary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Code content text field
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: ctrl,
              focusNode: fn,
              readOnly: widget.readOnly,
              cursorColor: colors.accent,
              style: codeStyle,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (newCode) {
                // Update code in markdown
                final newMarkdown = widget.controller.markdown.replaceRange(
                  block.codeRange.start,
                  block.codeRange.end,
                  newCode,
                );
                widget.controller.markdown = newMarkdown;
                widget.onChanged?.call(newMarkdown);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBlockItem(
    BuildContext context,
    AppColors colors,
    ImageBlock block,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.image, size: 28, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.altText.isNotEmpty ? block.altText : 'Image',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  block.url,
                  style: AppTypography.caption.copyWith(color: colors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedBlockItem(
    BuildContext context,
    AppColors colors,
    UnsupportedMarkdownBlock block,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider),
      ),
      child: Text(
        block.rawSource,
        style: AppTypography.editorCode.copyWith(color: colors.textSecondary),
      ),
    );
  }

  Widget _buildBlockTextField({
    required BuildContext context,
    required AppColors colors,
    required String blockId,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextStyle textStyle,
    required String hintText,
  }) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          widget.controller.toggleBold();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          widget.controller.toggleBold();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
          widget.controller.toggleItalic();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
          widget.controller.toggleItalic();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true): () {
          widget.controller.toggleStrike();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true): () {
          widget.controller.toggleStrike();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.backquote, control: true): () {
          widget.controller.toggleInlineCode();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () {
          widget.controller.toggleInlineCode();
          widget.onChanged?.call(widget.controller.markdown);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _promptLink(context, blockId),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _promptLink(context, blockId),
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: widget.readOnly,
        cursorColor: colors.accent,
        style: textStyle,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          SemanticBlockInputFormatter(
            onEnter: (offset) {
              widget.controller.splitBlock(blockId, offset);
            },
          ),
        ],
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: textStyle.copyWith(
            color: colors.textTertiary.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onTap: () {
          widget.onActiveTargetChanged?.call(controller, focusNode);
        },
        contextMenuBuilder: (ctx, state) => _buildSelectionContextMenu(ctx, state, blockId),
        onChanged: (newText) {
          _handleBlockTextChanged(blockId, newText, controller.selection);
        },
      ),
    );
  }

  void _handleBlockTextChanged(String blockId, String newText, TextSelection selection) {
    final doc = widget.controller.document;
    final block = doc.findBlockById(blockId);
    if (block == null) return;

    // Direct content edit within this block
    final contentStart = (block is HeadingBlock)
        ? block.contentRange.start
        : (block is ListItemBlock)
            ? block.contentRange.start
            : (block is OrderedListItemBlock)
                ? block.contentRange.start
                : (block is ChecklistItemBlock)
                    ? block.contentRange.start
                    : (block is QuoteBlock)
                        ? block.contentRange.start
                        : (block is ParagraphBlock)
                            ? (block.contentRange?.start ?? block.sourceRange.start)
                            : block.sourceRange.start;

    final contentEnd = (block is HeadingBlock)
        ? block.contentRange.end
        : (block is ListItemBlock)
            ? block.contentRange.end
            : (block is OrderedListItemBlock)
                ? block.contentRange.end
                : (block is ChecklistItemBlock)
                    ? block.contentRange.end
                    : (block is QuoteBlock)
                        ? block.contentRange.end
                        : (block is ParagraphBlock)
                            ? (block.contentRange?.end ?? block.sourceRange.end)
                            : block.sourceRange.end;

    final newMarkdown = widget.controller.markdown.replaceRange(contentStart, contentEnd, newText);
    final newSourceOffset = contentStart + selection.baseOffset;
    widget.controller.updateMarkdownAndRetainSelection(newMarkdown, newSourceOffset);
  }

  Widget _buildSelectionContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    String blockId,
  ) {
    final buttonItems = editableTextState.contextMenuButtonItems;
    final isSelectionActive = !editableTextState.textEditingValue.selection.isCollapsed;
    final block = widget.controller.document.findBlockById(blockId);
    final headingButton = block is HeadingBlock
        ? ContextMenuButtonItem(
            label: 'Heading (${block.badgeLabel})',
            onPressed: () {
              ContextMenuController.removeAny();
              _showHeadingActionSheet(context, block);
            },
          )
        : null;

    if (isSelectionActive) {
      final formattingButtons = [
        ?headingButton,
        ContextMenuButtonItem(
          label: 'Bold',
          onPressed: () {
            ContextMenuController.removeAny();
            widget.controller.toggleBold();
            widget.onChanged?.call(widget.controller.markdown);
          },
        ),
        ContextMenuButtonItem(
          label: 'Italic',
          onPressed: () {
            ContextMenuController.removeAny();
            widget.controller.toggleItalic();
            widget.onChanged?.call(widget.controller.markdown);
          },
        ),
        ContextMenuButtonItem(
          label: 'Strike',
          onPressed: () {
            ContextMenuController.removeAny();
            widget.controller.toggleStrike();
            widget.onChanged?.call(widget.controller.markdown);
          },
        ),
        ContextMenuButtonItem(
          label: 'Code',
          onPressed: () {
            ContextMenuController.removeAny();
            widget.controller.toggleInlineCode();
            widget.onChanged?.call(widget.controller.markdown);
          },
        ),
        ContextMenuButtonItem(
          label: 'Link',
          onPressed: () {
            ContextMenuController.removeAny();
            _promptLink(context, blockId);
          },
        ),
        if (widget.onNoteLinkPrompt != null)
          ContextMenuButtonItem(
            label: 'Note Link',
            onPressed: () {
              ContextMenuController.removeAny();
              widget.onNoteLinkPrompt!();
            },
          ),
      ];

      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: [
          ...formattingButtons,
          ...buttonItems,
        ],
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ?headingButton,
        ...buttonItems,
      ],
    );
  }
}

class SemanticBlockInputFormatter extends TextInputFormatter {
  SemanticBlockInputFormatter({
    required this.onEnter,
  });

  final void Function(int offset) onEnter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selectionSpan = oldValue.selection.isValid && !oldValue.selection.isCollapsed
        ? (oldValue.selection.end - oldValue.selection.start)
        : 0;
    final isSingleCharInsertion = newValue.text.length == oldValue.text.length - selectionSpan + 1;

    if (isSingleCharInsertion && newValue.selection.isCollapsed) {
      final insertedOffset = newValue.selection.start - 1;
      if (insertedOffset >= 0 &&
          insertedOffset < newValue.text.length &&
          newValue.text[insertedOffset] == '\n') {
        onEnter(insertedOffset);
        return oldValue;
      }
    }
    return newValue;
  }
}

/// Custom [TextEditingController] rendering inline styled spans for a semantic block.
class _RichBlockEditingController extends TextEditingController {
  _RichBlockEditingController({
    required SemanticBlock block,
    this.styles,
    this.searchQuery,
  }) : _block = block,
       super(text: block.plainText);

  SemanticBlock _block;
  MarkdownStyles? styles;
  String? searchQuery;

  void updateBlock(SemanticBlock newBlock, MarkdownStyles? newStyles, String? newSearchQuery) {
    _block = newBlock;
    styles = newStyles;
    searchQuery = newSearchQuery;
    if (text != newBlock.plainText) {
      final oldSelection = selection;
      value = TextEditingValue(
        text: newBlock.plainText,
        selection: TextSelection.collapsed(offset: oldSelection.baseOffset.clamp(0, newBlock.plainText.length)),
      );
    } else {
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = context.appColors;
    final spans = <InlineSpan>[];

    List<SemanticInline> runs = [];
    if (_block is ParagraphBlock) {
      runs = (_block as ParagraphBlock).runs;
    } else if (_block is HeadingBlock) {
      runs = (_block as HeadingBlock).runs;
    } else if (_block is ListItemBlock) {
      runs = (_block as ListItemBlock).runs;
    } else if (_block is OrderedListItemBlock) {
      runs = (_block as OrderedListItemBlock).runs;
    } else if (_block is ChecklistItemBlock) {
      runs = (_block as ChecklistItemBlock).runs;
    } else if (_block is QuoteBlock) {
      runs = (_block as QuoteBlock).runs;
    }

    if (runs.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    for (final run in runs) {
      TextStyle? runStyle = style;

      if (run is BoldRun) {
        runStyle = runStyle?.merge(styles?.bold ?? const TextStyle(fontWeight: FontWeight.bold));
      } else if (run is ItalicRun) {
        runStyle = runStyle?.merge(styles?.italic ?? const TextStyle(fontStyle: FontStyle.italic));
      } else if (run is StrikeRun) {
        runStyle = runStyle?.merge(styles?.strikethrough ?? const TextStyle(decoration: TextDecoration.lineThrough));
      } else if (run is HighlightRun) {
        runStyle = runStyle?.merge(styles?.highlight ?? TextStyle(backgroundColor: colors.accent.withValues(alpha: 0.22)));
      } else if (run is InlineCodeRun) {
        runStyle = runStyle?.merge(styles?.inlineCode ?? TextStyle(color: colors.accentDark, backgroundColor: colors.tagBackground));
      } else if (run is LinkRun) {
        runStyle = runStyle?.merge(styles?.link ?? TextStyle(color: colors.accent, decoration: TextDecoration.underline));
      } else if (run is NoteLinkRun) {
        runStyle = runStyle?.merge(styles?.link ?? TextStyle(color: colors.accent, fontWeight: FontWeight.w600));
      } else if (run is TagRun) {
        runStyle = runStyle?.merge(styles?.tag ?? TextStyle(color: colors.accent, fontWeight: FontWeight.w500));
      }

      // Handle in-note search highlight
      if (searchQuery != null && searchQuery!.isNotEmpty && run.text.toLowerCase().contains(searchQuery!.toLowerCase())) {
        final query = searchQuery!.toLowerCase();
        final content = run.text;
        var start = 0;
        final matchSpans = <InlineSpan>[];

        while (true) {
          final idx = content.toLowerCase().indexOf(query, start);
          if (idx == -1) {
            matchSpans.add(TextSpan(text: content.substring(start), style: runStyle));
            break;
          }
          if (idx > start) {
            matchSpans.add(TextSpan(text: content.substring(start, idx), style: runStyle));
          }
          matchSpans.add(
            TextSpan(
              text: content.substring(idx, idx + query.length),
              style: runStyle?.merge(styles?.searchHighlight ?? TextStyle(backgroundColor: colors.searchHighlight)),
            ),
          );
          start = idx + query.length;
        }
        spans.addAll(matchSpans);
      } else {
        spans.add(TextSpan(text: run.text, style: runStyle));
      }
    }

    return TextSpan(children: spans, style: style);
  }
}
