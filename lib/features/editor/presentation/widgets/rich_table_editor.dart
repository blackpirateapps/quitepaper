import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../application/markdown_table_controller.dart';
import '../../application/markdown_table_parser.dart';
import '../../application/rich_document_controller.dart';
import '../../domain/markdown_table.dart';
import '../../domain/markdown_table_position.dart';
import '../../domain/rich_block.dart';
import 'table/markdown_table_editor.dart';
import 'table/markdown_table_view.dart';
import 'table/table_editor_screen.dart';

/// Specialized table widget embedded in Quiet Paper's Visual (WYSIWYG) editor.
///
/// Supports inline tap-to-activate cell editing (reusing [MarkdownTableEditor])
/// and an expand button that opens the full-screen [TableEditorScreen]. Edits
/// are written back into the authoritative [TableBlock] via
/// [RichDocumentController.updateTable].
class RichTableEditor extends StatefulWidget {
  const RichTableEditor({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    this.readOnly = false,
  });

  final TableBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;

  @override
  State<RichTableEditor> createState() => _RichTableEditorState();
}

class _RichTableEditorState extends State<RichTableEditor> {
  static const _parser = MarkdownTableParser();

  MarkdownTableController? _editController;
  String _workingMarkdown = '';

  bool get _editing => _editController != null;

  @override
  void dispose() {
    _editController?.dispose();
    super.dispose();
  }

  String _tableToMarkdown(MarkdownTable t) {
    return [
      t.headerRow.rawLine,
      t.delimiterRow.rawLine,
      ...t.bodyRows.map((r) => r.rawLine),
    ].join('\n');
  }

  void _enterEdit([TablePosition? pos]) {
    if (widget.readOnly) return;
    if (_editing) {
      if (pos != null) _editController!.setActivePosition(pos);
      return;
    }
    _workingMarkdown = _tableToMarkdown(widget.block.table);
    final tables = _parser.findTables(_workingMarkdown);
    if (tables.isEmpty) return;
    _editController = MarkdownTableController(
      table: tables.first,
      getDocumentValue: () => TextEditingValue(text: _workingMarkdown),
      onUpdateDocument: (v) => _workingMarkdown = v.text,
      initialPosition: pos,
    );
    setState(() {});
    if (pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editController?.setActivePosition(pos);
      });
    }
  }

  void _commit() {
    final working = _workingMarkdown;
    final original = _tableToMarkdown(widget.block.table);
    _editController?.dispose();
    _editController = null;
    if (working.trim() != original.trim()) {
      final tables = _parser.findTables(working);
      if (tables.isNotEmpty) {
        widget.controller.updateTable(widget.blockIndex, tables.first);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _openFullScreen() async {
    final current =
        _editing ? _workingMarkdown : _tableToMarkdown(widget.block.table);
    final result = await TableEditorScreen.open(
      context,
      initialTableMarkdown: current,
    );
    if (!mounted || result == null) return;
    if (result.trim().isEmpty) {
      _editController?.dispose();
      _editController = null;
      widget.controller.convertBlockToParagraph(widget.blockIndex);
      setState(() {});
      return;
    }
    final tables = _parser.findTables(result);
    if (tables.isNotEmpty) {
      widget.controller.updateTable(widget.blockIndex, tables.first);
    }
    if (_editing) {
      _workingMarkdown = result;
      _editController?.reloadFrom(TextEditingValue(text: result));
    }
    setState(() {});
  }

  void _deleteTable() {
    _editController?.dispose();
    _editController = null;
    widget.controller.convertBlockToParagraph(widget.blockIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final editing = _editing && _editController != null;
    final table = widget.block.table;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: editing ? colors.accent.withValues(alpha: 0.6) : colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(editing ? AppSpacing.xs : AppSpacing.sm),
            child: editing
                ? MarkdownTableEditor(
                    controller: _editController!,
                    onClose: _commit,
                  )
                : MarkdownTableView(
                    table: table,
                    readOnly: widget.readOnly,
                    onCellTap: widget.readOnly ? null : _enterEdit,
                  ),
          ),
          if (!widget.readOnly)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Text(
                    '${table.columnCount}×${table.rowCount} Table',
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                  const Spacer(),
                  if (editing)
                    QuietIconButton(
                      icon: PhosphorIconsRegular.check,
                      tooltip: 'Done editing',
                      size: 16,
                      onPressed: _commit,
                    )
                  else
                    QuietIconButton(
                      icon: PhosphorIconsRegular.pencilSimple,
                      tooltip: 'Edit inline',
                      size: 16,
                      onPressed: () => _enterEdit(const TablePosition(row: 0, column: 0)),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  QuietIconButton(
                    icon: PhosphorIconsRegular.arrowsOut,
                    tooltip: 'Open full screen',
                    size: 16,
                    onPressed: _openFullScreen,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  QuietIconButton(
                    icon: PhosphorIconsRegular.trash,
                    tooltip: 'Delete table',
                    size: 16,
                    onPressed: _deleteTable,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
