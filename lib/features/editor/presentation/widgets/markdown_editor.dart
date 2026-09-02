import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/markdown_table_controller.dart';
import '../../application/markdown_table_parser.dart';
import '../../application/markdown_text_input_formatter.dart';
import '../../application/semantic_editor_controller.dart';
import '../../domain/editor_editing_style.dart';
import '../../domain/markdown_table.dart';
import '../../domain/markdown_table_position.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import 'code_block_overlay.dart';
import 'heading/markdown_heading_action_sheet.dart';
import 'link_prompt_dialog.dart';
import 'table/markdown_table_editor.dart';
import 'table/markdown_table_view.dart';
import 'visual_document_editor.dart';

/// A dedicated, distraction-free Markdown and Visual (WYSIWYG) editor widget.
///
/// In [EditorEditingStyle.wysiwyg], renders the semantic visual document editor
/// where users edit real headings, checklists, lists, tables, and formatted runs without syntax noise.
/// In [EditorEditingStyle.markdown], renders the source-oriented Markdown editor.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.editingStyle = EditorEditingStyle.markdown,
    this.stripFrontmatter = false,
    this.hintText = 'Start writing...',
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.readOnly = false,
    this.searchQuery,
    this.onActiveTargetChanged,
    this.onNoteLinkPrompt,
  });

  final MarkdownEditingController controller;
  final FocusNode focusNode;
  final EditorEditingStyle editingStyle;
  final bool stripFrontmatter;
  final String hintText;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final EdgeInsets scrollPadding;
  final bool readOnly;
  final String? searchQuery;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final VoidCallback? onNoteLinkPrompt;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  static const _tableParser = MarkdownTableParser();

  MarkdownTable? _activeTable;
  MarkdownTableController? _activeTableController;
  SemanticEditorController? _semanticController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initSemanticController();
    widget.controller.addListener(_onSourceControllerChanged);
  }

  void _initSemanticController() {
    if (widget.editingStyle == EditorEditingStyle.wysiwyg) {
      _semanticController?.dispose();
      _semanticController = SemanticEditorController(
        initialMarkdown: widget.controller.text,
        styles: widget.controller.styles,
        stripFrontmatter: widget.stripFrontmatter,
        onMarkdownChanged: _onSemanticMarkdownChanged,
      );
      _semanticController!.searchQuery = widget.searchQuery;
    } else {
      _semanticController?.dispose();
      _semanticController = null;
    }
  }

  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.editingStyle != widget.editingStyle ||
        oldWidget.stripFrontmatter != widget.stripFrontmatter) {
      _initSemanticController();
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSourceControllerChanged);
      widget.controller.addListener(_onSourceControllerChanged);
      if (_semanticController != null) {
        _semanticController!.styles = widget.controller.styles;
        _semanticController!.markdown = widget.controller.text;
      }
      _syncActiveTableWithDocument();
    } else if (_semanticController != null) {
      if (widget.controller.styles != _semanticController!.styles) {
        _semanticController!.styles = widget.controller.styles;
      }
      if (widget.searchQuery != _semanticController!.searchQuery) {
        _semanticController!.searchQuery = widget.searchQuery;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSourceControllerChanged);
    _semanticController?.dispose();
    _activeTableController?.dispose();
    _activeTableController = null;
    super.dispose();
  }

  void _onSemanticMarkdownChanged(String newMarkdown) {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      if (widget.controller.text != newMarkdown) {
        widget.controller.value = TextEditingValue(
          text: newMarkdown,
          selection: widget.controller.selection,
        );
        widget.onChanged?.call(newMarkdown);
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _onSourceControllerChanged() {
    if (_isSyncing) return;

    if (_semanticController != null &&
        _semanticController!.markdown != widget.controller.text) {
      _semanticController!.markdown = widget.controller.text;
    }

    _syncActiveTableWithDocument();
  }

  void _syncActiveTableWithDocument() {
    if (_activeTable != null) {
      final docText = widget.controller.text;
      final reloaded = _tableParser.findTableAtOffset(docText, _activeTable!.sourceStart);
      if (reloaded != null) {
        _activeTable = reloaded;
        _activeTableController?.updateTableProjection(reloaded);
      } else {
        _deactivateTable();
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _activateTable(MarkdownTable table, [TablePosition? position]) {
    if (widget.readOnly) return;

    _activeTableController?.dispose();

    _activeTable = table;
    final controller = MarkdownTableController(
      table: table,
      getDocumentValue: () => widget.controller.value,
      onUpdateDocument: (newVal) {
        widget.controller.value = newVal;
        if (_semanticController != null) {
          _semanticController!.markdown = newVal.text;
        }
        widget.onChanged?.call(newVal.text);
      },
      initialPosition: position ?? const TablePosition(row: 0, column: 0),
      styles: widget.controller.styles,
    );
    _activeTableController = controller;

    widget.onActiveTargetChanged?.call(
      controller.cellController,
      controller.cellFocusNode,
    );

    setState(() {});
  }

  void _deactivateTable() {
    _activeTableController?.dispose();
    _activeTableController = null;
    _activeTable = null;

    widget.onActiveTargetChanged?.call(
      widget.controller,
      widget.focusNode,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: widget.controller.value);
    widget.controller.value = updated;
    if (_semanticController != null) {
      _semanticController!.markdown = updated.text;
    }
    widget.onChanged?.call(widget.controller.text);
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  Future<void> _promptLink(BuildContext context) async {
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
      if (_semanticController != null) {
        _semanticController!.markdown = updated.text;
      }
      widget.onChanged?.call(widget.controller.text);
      if (!widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
    }
  }

  void _handleTap() {
    final val = widget.controller.value;
    final text = val.text;
    final sel = val.selection;
    if (!sel.isValid) return;

    final cursor = sel.start;
    if (cursor < 0 || cursor > text.length) return;

    // Check if tapped inside a table
    final sourceText = widget.controller.text;
    final table = _tableParser.findTableAtOffset(sourceText, cursor);
    if (table != null && !widget.readOnly) {
      final pos = table.findPositionAtSourceOffset(cursor) ?? const TablePosition(row: 0, column: 0);
      _activateTable(table, pos);
      return;
    }

    // In Markdown mode, check if tapped on `- [ ]` or `- [x]`
    var lineStart = 0;
    if (cursor > 0) {
      lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    }
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd == -1) lineEnd = text.length;

    final line = text.substring(lineStart, lineEnd);
    final match = RegExp(r'^(\s*[-*+]\s*\[)([ xX])(\])').firstMatch(line);
    if (match != null) {
      final markerEnd = lineStart + match.end;
      if (cursor <= markerEnd + 1) {
        final state = match.group(2);
        final newState = (state == 'x' || state == 'X') ? ' ' : 'x';
        final stateOffset = lineStart + (match.group(1)?.length ?? 3);
        final newText = text.replaceRange(stateOffset, stateOffset + 1, newState);
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: sel,
        );
        widget.onChanged?.call(newText);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editingStyle == EditorEditingStyle.wysiwyg && _semanticController != null) {
      return VisualDocumentEditor(
        controller: _semanticController!,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        hintText: widget.hintText,
        searchQuery: widget.searchQuery,
        onActiveTargetChanged: widget.onActiveTargetChanged,
        onNoteLinkPrompt: widget.onNoteLinkPrompt,
        onChanged: (newVal) {
          widget.onChanged?.call(newVal);
        },
      );
    }

    final colors = context.appColors;
    final text = widget.controller.text;

    // Fast path: Check for tables
    final tables = _tableParser.findTables(text);

    if (tables.isEmpty || text.length > 60000) {
      return _buildSingleTextField(context, colors);
    }

    return _buildSegmentedTableEditor(context, colors, tables);
  }

  Widget _buildSingleTextField(BuildContext context, AppColors colors) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _applyFormat(MarkdownFormatter.toggleBold),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
            _applyFormat(MarkdownFormatter.toggleBold),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            _applyFormat(MarkdownFormatter.toggleItalic),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
            _applyFormat(MarkdownFormatter.toggleItalic),
        const SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true): () =>
            _applyFormat(MarkdownFormatter.toggleStrikethrough),
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true): () =>
            _applyFormat(MarkdownFormatter.toggleStrikethrough),
        const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
            _applyFormat(MarkdownFormatter.toggleInlineCode),
        const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () =>
            _applyFormat(MarkdownFormatter.toggleInlineCode),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _promptLink(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _promptLink(context),
      },
      child: CodeBlockOverlay(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          cursorColor: colors.accent,
          style: (widget.controller.styles?.body ?? AppTypography.editorBody).copyWith(
            color: colors.textPrimary,
          ),
          inputFormatters: const [MarkdownTextInputFormatter()],
          onTap: () {
            widget.onActiveTargetChanged?.call(widget.controller, widget.focusNode);
            _handleTap();
          },
          contextMenuBuilder: _buildContextMenu,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.editorBody.copyWith(
              color: colors.textTertiary.withValues(alpha: 0.4),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          maxLines: null,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          onChanged: (val) {
            widget.onChanged?.call(val);
          },
          scrollPadding: widget.scrollPadding,
        ),
      ),
    );
  }

  Widget _buildSegmentedTableEditor(
    BuildContext context,
    AppColors colors,
    List<MarkdownTable> tables,
  ) {
    final text = widget.controller.text;
    final children = <Widget>[];

    var currentOffset = 0;

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];

      // 1. Text segment before this table
      if (table.sourceStart > currentOffset) {
        final textBefore = text.substring(currentOffset, table.sourceStart);
        final segmentStart = currentOffset;
        final segmentEnd = table.sourceStart;

        children.add(
          _TextSegmentField(
            key: ValueKey('seg_${segmentStart}_$segmentEnd'),
            initialText: textBefore,
            styles: widget.controller.styles,
            readOnly: widget.readOnly,
            hintText: currentOffset == 0 ? widget.hintText : '',
            searchQuery: widget.searchQuery,
            editingStyle: widget.editingStyle,
            onActiveTarget: widget.onActiveTargetChanged,
            onTap: _handleTap,
            onChanged: (newSegText) {
              final newFullText = text.replaceRange(segmentStart, segmentEnd, newSegText);
              widget.controller.value = TextEditingValue(
                text: newFullText,
                selection: TextSelection.collapsed(offset: segmentStart + newSegText.length),
              );
              widget.onChanged?.call(newFullText);
            },
          ),
        );
      }

      // 2. Table segment
      final isActiveTable = _activeTable != null &&
          _activeTable!.sourceStart == table.sourceStart;

      if (isActiveTable && _activeTableController != null) {
        children.add(
          MarkdownTableEditor(
            key: ValueKey('table_editor_${table.sourceStart}'),
            controller: _activeTableController!,
            styles: widget.controller.styles,
            searchQuery: widget.searchQuery,
            onClose: _deactivateTable,
          ),
        );
      } else {
        children.add(
          MarkdownTableView(
            key: ValueKey('table_view_${table.sourceStart}'),
            table: table,
            styles: widget.controller.styles,
            readOnly: widget.readOnly,
            searchQuery: widget.searchQuery,
            onCellTap: (pos) => _activateTable(table, pos),
          ),
        );
      }

      currentOffset = table.sourceEnd;
    }

    // 3. Trailing text segment after last table
    if (currentOffset < text.length) {
      final trailingText = text.substring(currentOffset);
      final segmentStart = currentOffset;
      final segmentEnd = text.length;

      children.add(
        _TextSegmentField(
          key: ValueKey('seg_${segmentStart}_$segmentEnd'),
          initialText: trailingText,
          styles: widget.controller.styles,
          readOnly: widget.readOnly,
          hintText: '',
          searchQuery: widget.searchQuery,
          editingStyle: widget.editingStyle,
          onActiveTarget: widget.onActiveTargetChanged,
          onTap: _handleTap,
          onChanged: (newSegText) {
            final newFullText = text.replaceRange(segmentStart, segmentEnd, newSegText);
            widget.controller.value = TextEditingValue(
              text: newFullText,
              selection: TextSelection.collapsed(offset: segmentStart + newSegText.length),
            );
            widget.onChanged?.call(newFullText);
          },
        ),
      );
    } else if (tables.isNotEmpty && currentOffset == text.length && !widget.readOnly) {
      children.add(
        _TextSegmentField(
          key: const ValueKey('seg_bottom_empty'),
          initialText: '',
          styles: widget.controller.styles,
          readOnly: widget.readOnly,
          hintText: 'Continue writing...',
          searchQuery: widget.searchQuery,
          editingStyle: widget.editingStyle,
          onActiveTarget: widget.onActiveTargetChanged,
          onChanged: (newSegText) {
            final newFullText = '$text\n\n$newSegText';
            widget.controller.value = TextEditingValue(
              text: newFullText,
              selection: TextSelection.collapsed(offset: newFullText.length),
            );
            widget.onChanged?.call(newFullText);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    final buttonItems = editableTextState.contextMenuButtonItems;
    final isSelectionActive = !editableTextState.textEditingValue.selection.isCollapsed;
    final val = widget.controller.value;
    final currentLang = MarkdownHelper.getCodeBlockLanguageAtCursor(val);
    final codeLangButton = currentLang != null
        ? ContextMenuButtonItem(
            label: currentLang.isEmpty ? 'Select Language' : 'Language ($currentLang)',
            onPressed: () async {
              ContextMenuController.removeAny();
              final selected = await LanguageSelectorSheet.show(
                context,
                currentLanguageId: currentLang.isNotEmpty ? currentLang : null,
                title: 'Select Code Language',
              );
              if (selected != null) {
                final updated = MarkdownHelper.changeCodeBlockLanguage(
                  value: widget.controller.value,
                  newLanguage: selected.id,
                );
                widget.controller.value = updated;
                widget.onChanged?.call(updated.text);
                if (!widget.focusNode.hasFocus) {
                  widget.focusNode.requestFocus();
                }
              }
            },
          )
        : null;

    final currentHeadingLevel = MarkdownHelper.getHeadingLevelAt(val);
    final headingLevelButton = currentHeadingLevel != null
        ? ContextMenuButtonItem(
            label: 'Heading (H$currentHeadingLevel)',
            onPressed: () {
              ContextMenuController.removeAny();
              MarkdownHeadingActionSheet.show(
                context,
                currentLevel: currentHeadingLevel,
                onSelectLevel: (newLevel) {
                  final updated = MarkdownHelper.setHeadingLevelAt(
                    value: widget.controller.value,
                    level: newLevel,
                  );
                  widget.controller.value = updated;
                  widget.onChanged?.call(updated.text);
                  if (!widget.focusNode.hasFocus) {
                    widget.focusNode.requestFocus();
                  }
                },
                onConvertToParagraph: () {
                  final updated = MarkdownHelper.setHeadingLevelAt(
                    value: widget.controller.value,
                    level: 0,
                  );
                  widget.controller.value = updated;
                  widget.onChanged?.call(updated.text);
                  if (!widget.focusNode.hasFocus) {
                    widget.focusNode.requestFocus();
                  }
                },
                onCycleLevel: () {
                  final updated = MarkdownHelper.cycleHeading(widget.controller.value);
                  widget.controller.value = updated;
                  widget.onChanged?.call(updated.text);
                  if (!widget.focusNode.hasFocus) {
                    widget.focusNode.requestFocus();
                  }
                },
              );
            },
          )
        : null;

    if (isSelectionActive) {
      final formattingButtons = [
        ?headingLevelButton,
        ?codeLangButton,
        ContextMenuButtonItem(
          label: 'Bold',
          onPressed: () {
            ContextMenuController.removeAny();
            _applyFormat(MarkdownFormatter.toggleBold);
          },
        ),
        ContextMenuButtonItem(
          label: 'Italic',
          onPressed: () {
            ContextMenuController.removeAny();
            _applyFormat(MarkdownFormatter.toggleItalic);
          },
        ),
        ContextMenuButtonItem(
          label: 'Strike',
          onPressed: () {
            ContextMenuController.removeAny();
            _applyFormat(MarkdownFormatter.toggleStrikethrough);
          },
        ),
        ContextMenuButtonItem(
          label: 'Code',
          onPressed: () {
            ContextMenuController.removeAny();
            _applyFormat(MarkdownFormatter.toggleInlineCode);
          },
        ),
        ContextMenuButtonItem(
          label: 'Link',
          onPressed: () {
            ContextMenuController.removeAny();
            _promptLink(context);
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
        ContextMenuButtonItem(
          label: 'Checklist',
          onPressed: () {
            ContextMenuController.removeAny();
            _applyFormat(MarkdownFormatter.toggleChecklist);
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
        ?headingLevelButton,
        ?codeLangButton,
        ...buttonItems,
      ],
    );
  }
}

/// A lightweight text segment editor for non-table regions surrounding Markdown tables.
class _TextSegmentField extends StatefulWidget {
  const _TextSegmentField({
    super.key,
    required this.initialText,
    required this.styles,
    required this.readOnly,
    required this.hintText,
    required this.onChanged,
    this.searchQuery,
    this.editingStyle = EditorEditingStyle.markdown,
    this.onTap,
    this.onActiveTarget,
  });

  final String initialText;
  final dynamic styles;
  final bool readOnly;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? searchQuery;
  final EditorEditingStyle editingStyle;
  final VoidCallback? onTap;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTarget;

  @override
  State<_TextSegmentField> createState() => _TextSegmentFieldState();
}

class _TextSegmentFieldState extends State<_TextSegmentField> {
  late final MarkdownEditingController _sourceController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _sourceController = MarkdownEditingController(
      text: widget.initialText,
      styles: widget.styles,
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _sourceController.addListener(_onTextChanged);
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.onActiveTarget?.call(_sourceController, _focusNode);
    }
  }

  @override
  void didUpdateWidget(_TextSegmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _sourceController.text) {
      _sourceController.text = widget.initialText;
    }
    if (oldWidget.styles != widget.styles) {
      _sourceController.styles = widget.styles;
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _sourceController.searchQuery = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _sourceController.removeListener(_onTextChanged);
    _sourceController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_sourceController.text != widget.initialText) {
      widget.onChanged(_sourceController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: _sourceController,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      cursorColor: colors.accent,
      style: (widget.styles?.body ?? AppTypography.editorBody).copyWith(
        color: colors.textPrimary,
      ),
      inputFormatters: const [MarkdownTextInputFormatter()],
      maxLines: null,
      onTap: () {
        widget.onActiveTarget?.call(_sourceController, _focusNode);
        widget.onTap?.call();
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
