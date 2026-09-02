import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/markdown_table_controller.dart';
import '../../application/markdown_table_parser.dart';
import '../../application/markdown_text_input_formatter.dart';
import '../../application/wysiwyg_editing_controller.dart';
import '../../application/wysiwyg_projection_builder.dart';
import '../../domain/editor_editing_style.dart';
import '../../domain/markdown_table.dart';
import '../../domain/markdown_table_position.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import 'code_block_overlay.dart';
import 'link_prompt_dialog.dart';
import 'table/markdown_table_editor.dart';
import 'table/markdown_table_view.dart';

/// A dedicated, distraction-free Markdown and WYSIWYG editor widget.
/// Supports both Markdown mode (syntax visible) and WYSIWYG mode (syntax hidden),
/// while preserving exact canonical Markdown persistence and hybrid table spreadsheet editing.
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
  WysiwygEditingController? _wysiwygController;
  bool _isSyncingFromWysiwyg = false;

  @override
  void initState() {
    super.initState();
    _initWysiwygController();
    widget.controller.addListener(_onSourceControllerChanged);
  }

  void _initWysiwygController() {
    if (widget.editingStyle == EditorEditingStyle.wysiwyg) {
      _wysiwygController?.dispose();
      _wysiwygController = WysiwygEditingController(
        sourceText: widget.controller.text,
        styles: widget.controller.styles,
        stripFrontmatter: widget.stripFrontmatter,
        onSourceChanged: _onWysiwygSourceChanged,
      );
      _wysiwygController!.searchQuery = widget.searchQuery;
    } else {
      _wysiwygController?.dispose();
      _wysiwygController = null;
    }
  }

  @override
  void didUpdateWidget(MarkdownEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.editingStyle != widget.editingStyle ||
        oldWidget.stripFrontmatter != widget.stripFrontmatter) {
      _initWysiwygController();
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSourceControllerChanged);
      widget.controller.addListener(_onSourceControllerChanged);
      if (_wysiwygController != null) {
        _wysiwygController!.styles = widget.controller.styles;
        _wysiwygController!.sourceText = widget.controller.text;
      }
      _syncActiveTableWithDocument();
    } else if (_wysiwygController != null) {
      if (widget.controller.styles != _wysiwygController!.styles) {
        _wysiwygController!.styles = widget.controller.styles;
      }
      if (widget.searchQuery != _wysiwygController!.searchQuery) {
        _wysiwygController!.searchQuery = widget.searchQuery;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSourceControllerChanged);
    _wysiwygController?.dispose();
    _activeTableController?.dispose();
    _activeTableController = null;
    super.dispose();
  }

  void _onWysiwygSourceChanged(String newSource) {
    if (_isSyncingFromWysiwyg) return;
    _isSyncingFromWysiwyg = true;
    try {
      final oldVal = widget.controller.value;
      widget.controller.value = TextEditingValue(
        text: newSource,
        selection: _wysiwygController?.sourceValue.selection ?? oldVal.selection,
      );
      widget.onChanged?.call(newSource);
    } finally {
      _isSyncingFromWysiwyg = false;
    }
  }

  void _onSourceControllerChanged() {
    if (_isSyncingFromWysiwyg) return;

    if (_wysiwygController != null &&
        _wysiwygController!.sourceText != widget.controller.text) {
      _wysiwygController!.sourceText = widget.controller.text;
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
        if (_wysiwygController != null) {
          _wysiwygController!.sourceText = newVal.text;
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

    final targetCtrl = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null
        ? _wysiwygController!
        : widget.controller;

    widget.onActiveTargetChanged?.call(
      targetCtrl,
      widget.focusNode,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final currentSourceVal = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null
        ? _wysiwygController!.sourceValue
        : widget.controller.value;

    final updated = action(value: currentSourceVal);
    widget.controller.value = updated;
    if (_wysiwygController != null) {
      _wysiwygController!.setSourceValue(updated);
    }
    widget.onChanged?.call(widget.controller.text);
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
  }

  Future<void> _promptLink(BuildContext context) async {
    final activeCtrl = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null
        ? _wysiwygController!
        : widget.controller;

    final selection = activeCtrl.selection;
    final text = activeCtrl.text;
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
      final currentSourceVal = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null
          ? _wysiwygController!.sourceValue
          : widget.controller.value;

      final updated = MarkdownFormatter.createLink(
        value: currentSourceVal,
        url: result.url,
        title: result.title,
      );
      widget.controller.value = updated;
      if (_wysiwygController != null) {
        _wysiwygController!.setSourceValue(updated);
      }
      widget.onChanged?.call(widget.controller.text);
      if (!widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
    }
  }

  void _handleTap() {
    final isWysiwyg = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null;
    final activeCtrl = isWysiwyg ? _wysiwygController! : widget.controller;
    final val = activeCtrl.value;
    final text = val.text;
    final sel = val.selection;
    if (!sel.isValid) return;

    final cursor = sel.start;
    if (cursor < 0 || cursor > text.length) return;

    // Check if tapped inside a table
    final sourceText = widget.controller.text;
    final sourceOffset = isWysiwyg ? _wysiwygController!.mapping.visualToSource(cursor) : cursor;

    final table = _tableParser.findTableAtOffset(sourceText, sourceOffset);
    if (table != null && !widget.readOnly) {
      final pos = table.findPositionAtSourceOffset(sourceOffset) ?? const TablePosition(row: 0, column: 0);
      _activateTable(table, pos);
      return;
    }

    // Find line surrounding tap for checklist toggling
    if (isWysiwyg) {
      // In WYSIWYG mode, check if tapped on visual checkbox (e.g. "☐ " or "☑ ")
      var lineStart = 0;
      if (cursor > 0) {
        lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
      }
      var lineEnd = text.indexOf('\n', cursor);
      if (lineEnd == -1) lineEnd = text.length;
      final line = text.substring(lineStart, lineEnd);
      final isCheckboxLine = line.startsWith('☐ ') ||
          line.startsWith('☑ ') ||
          line.startsWith(WysiwygProjectionBuilder.uncheckedGlyph) ||
          line.startsWith(WysiwygProjectionBuilder.checkedGlyph);
      if (isCheckboxLine && cursor <= lineStart + 3) {
        // Toggle checkbox in source
        var srcLineStart = 0;
        if (sourceOffset > 0) {
          srcLineStart = sourceText.lastIndexOf('\n', sourceOffset - 1) + 1;
        }
        var srcLineEnd = sourceText.indexOf('\n', sourceOffset);
        if (srcLineEnd == -1) srcLineEnd = sourceText.length;

        final srcLine = sourceText.substring(srcLineStart, srcLineEnd);
        final match = RegExp(r'^(\s*[-*+]\s*\[)([ xX])(\])').firstMatch(srcLine);
        if (match != null) {
          final state = match.group(2);
          final newState = (state == 'x' || state == 'X') ? ' ' : 'x';
          final stateOffset = srcLineStart + (match.group(1)?.length ?? 3);
          final newSourceText = sourceText.replaceRange(stateOffset, stateOffset + 1, newState);

          widget.controller.value = TextEditingValue(
            text: newSourceText,
            selection: widget.controller.selection,
          );
          _wysiwygController!.setSourceValue(widget.controller.value);
          widget.onChanged?.call(newSourceText);
          return;
        }
      }
    } else {
      // In Markdown mode, check if tapped on - [ ]
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = widget.controller.text;

    // Fast path: Check for tables
    final tables = _tableParser.findTables(text);

    // If no tables exist or in large-document plain mode, render normal single TextField
    if (tables.isEmpty || text.length > 60000) {
      return _buildSingleTextField(context, colors);
    }

    // Segmented hybrid table view
    return _buildSegmentedTableEditor(context, colors, tables);
  }

  Widget _buildSingleTextField(BuildContext context, AppColors colors) {
    final isWysiwyg = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null;
    final activeCtrl = isWysiwyg ? _wysiwygController! : widget.controller;

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
          controller: activeCtrl,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          cursorColor: colors.accent,
          style: (widget.controller.styles?.body ?? AppTypography.editorBody).copyWith(
            color: colors.textPrimary,
          ),
          inputFormatters: const [MarkdownTextInputFormatter()],
          onTap: () {
            widget.onActiveTargetChanged?.call(activeCtrl, widget.focusNode);
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
            if (!isWysiwyg) {
              widget.onChanged?.call(val);
            }
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
              if (_wysiwygController != null) {
                _wysiwygController!.sourceText = newFullText;
              }
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
            if (_wysiwygController != null) {
              _wysiwygController!.sourceText = newFullText;
            }
            widget.onChanged?.call(newFullText);
          },
        ),
      );
    } else if (tables.isNotEmpty && currentOffset == text.length && !widget.readOnly) {
      // Empty slot at bottom to continue writing after table
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
            if (_wysiwygController != null) {
              _wysiwygController!.sourceText = newFullText;
            }
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
    final isSelectionActive =
        !editableTextState.textEditingValue.selection.isCollapsed;
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
                if (_wysiwygController != null) {
                  _wysiwygController!.setSourceValue(updated);
                }
                widget.onChanged?.call(updated.text);
                if (!widget.focusNode.hasFocus) {
                  widget.focusNode.requestFocus();
                }
              }
            },
          )
        : null;

    if (isSelectionActive) {
      final formattingButtons = [
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
    this.editingStyle = EditorEditingStyle.wysiwyg,
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
  WysiwygEditingController? _wysiwygController;
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

    if (widget.editingStyle == EditorEditingStyle.wysiwyg) {
      _wysiwygController = WysiwygEditingController(
        sourceText: widget.initialText,
        styles: widget.styles,
        onSourceChanged: (newSrc) {
          if (_sourceController.text != newSrc) {
            _sourceController.text = newSrc;
          }
        },
      );
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      final active = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null
          ? _wysiwygController!
          : _sourceController;
      widget.onActiveTarget?.call(active, _focusNode);
    }
  }

  @override
  void didUpdateWidget(_TextSegmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _sourceController.text) {
      _sourceController.text = widget.initialText;
      if (_wysiwygController != null) {
        _wysiwygController!.sourceText = widget.initialText;
      }
    }
    if (oldWidget.styles != widget.styles) {
      _sourceController.styles = widget.styles;
      if (_wysiwygController != null) {
        _wysiwygController!.styles = widget.styles;
      }
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _sourceController.searchQuery = widget.searchQuery;
      if (_wysiwygController != null) {
        _wysiwygController!.searchQuery = widget.searchQuery;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _sourceController.removeListener(_onTextChanged);
    _wysiwygController?.dispose();
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
    final isWysiwyg = widget.editingStyle == EditorEditingStyle.wysiwyg && _wysiwygController != null;
    final activeCtrl = isWysiwyg ? _wysiwygController! : _sourceController;

    return CodeBlockOverlay(
      controller: _sourceController,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      child: TextField(
        controller: activeCtrl,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        cursorColor: colors.accent,
        style: (widget.styles?.body ?? AppTypography.editorBody).copyWith(
          color: colors.textPrimary,
        ),
        inputFormatters: const [MarkdownTextInputFormatter()],
        onTap: () {
          widget.onActiveTarget?.call(activeCtrl, _focusNode);
          widget.onTap?.call();
        },
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
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}
