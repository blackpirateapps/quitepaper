import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../tags/domain/phosphor_icons.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../application/markdown_table_parser.dart';
import '../../../application/table_clipboard_parser.dart';
import '../../../domain/markdown_table.dart';
import '../../../domain/markdown_table_alignment.dart';
import '../../../domain/markdown_table_position.dart';
import 'markdown_table_editor.dart';
import 'markdown_table_view.dart';

/// Full-screen, enhanced table editing workspace.
///
/// Edits a single table's Markdown in isolation (not the whole note) and
/// returns the edited Markdown via [Navigator.pop]. Reuses [MarkdownTableEditor]
/// for the cell grid and layers richer structure/formatting controls, undo/redo,
/// CSV/TSV paste, and a live preview toggle on top.
class TableEditorScreen extends StatefulWidget {
  const TableEditorScreen({
    super.key,
    required this.initialTableMarkdown,
    this.title = 'Edit table',
  });

  final String initialTableMarkdown;
  final String title;

  /// Pushes the screen and resolves to the edited table Markdown, or `null` if
  /// the table was deleted or nothing changed.
  static Future<String?> open(
    BuildContext context, {
    required String initialTableMarkdown,
    String title = 'Edit table',
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => TableEditorScreen(
          initialTableMarkdown: initialTableMarkdown,
          title: title,
        ),
      ),
    );
  }

  @override
  State<TableEditorScreen> createState() => _TableEditorScreenState();
}

class _TableEditorScreenState extends State<TableEditorScreen> {
  static const _parser = MarkdownTableParser();

  late String _workingMarkdown;
  MarkdownTableController? _controller;

  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];
  bool _deleted = false;
  bool _dirty = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _workingMarkdown = widget.initialTableMarkdown.trim();
    _buildController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _buildController() {
    _controller?.dispose();
    final tables = _parser.findTables(_workingMarkdown);
    if (tables.isEmpty) {
      _controller = null;
      return;
    }
    _controller = MarkdownTableController(
      table: tables.first,
      getDocumentValue: () => TextEditingValue(text: _workingMarkdown),
      onUpdateDocument: (newValue) {
        _workingMarkdown = newValue.text;
        _dirty = true;
      },
      initialPosition: const TablePosition(row: 0, column: 0),
    );
  }

  MarkdownTable? get _table {
    final tables = _parser.findTables(_workingMarkdown);
    return tables.isEmpty ? null : tables.first;
  }

  /// Snapshots the current Markdown onto the undo stack before a mutation.
  void _snapshot() {
    _undoStack.add(_workingMarkdown);
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  /// Rebuilds the controller + UI after [_workingMarkdown] changed externally
  /// (undo/redo, CSV paste, header promote), keeping the active cell if valid.
  void _reloadAfterExternalChange({TablePosition? active}) {
    _dirty = true;
    final tables = _parser.findTables(_workingMarkdown);
    if (tables.isEmpty) {
      _controller?.dispose();
      _controller = null;
    } else if (_controller != null) {
      _controller!.reloadFrom(
        TextEditingValue(text: _workingMarkdown),
        newActivePosition: active,
      );
    } else {
      _buildController();
    }
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_workingMarkdown);
    _workingMarkdown = _undoStack.removeLast();
    _reloadAfterExternalChange();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_workingMarkdown);
    _workingMarkdown = _redoStack.removeLast();
    _reloadAfterExternalChange();
  }

  // ----- Structure ops routed through the controller (snapshot + rebuild) -----

  void _runControllerOp(void Function(MarkdownTableController c) op) {
    final c = _controller;
    if (c == null) return;
    _snapshot();
    op(c);
    setState(() {});
  }

  void _deleteTable() {
    _snapshot();
    _deleted = true;
    _dirty = true;
    Navigator.of(context).pop<String>('');
  }

  // ----- Grid helpers -----

  List<List<String>> _cellsOf(MarkdownTable table) {
    return [
      for (final row in table.allVisibleRows)
        [
          for (var c = 0; c < table.columnCount; c++)
            (c < row.cells.length ? row.cells[c].trimmedText : ''),
        ],
    ];
  }

  List<MarkdownTableAlignment> _alignmentsOf(MarkdownTable table) {
    return [
      for (var c = 0; c < table.columnCount; c++) table.getAlignment(c),
    ];
  }

  String _buildTableMarkdown(
    List<List<String>> cells,
    List<MarkdownTableAlignment> alignments,
  ) {
    if (cells.isEmpty) return '';
    final colCount = cells.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    String pad(List<String> row) {
      final out = [...row];
      while (out.length < colCount) {
        out.add('');
      }
      return '| ${out.map((c) => c.replaceAll('|', r'\|')).join(' | ')} |';
    }

    final header = pad(cells.first);
    final delimCells = [
      for (var c = 0; c < colCount; c++)
        (c < alignments.length ? alignments[c] : MarkdownTableAlignment.none)
            .toDelimiterString(),
    ];
    final delimiter = '| ${delimCells.join(' | ')} |';
    final body = cells.skip(1).map(pad);
    return [header, delimiter, ...body].join('\n');
  }

  void _promoteActiveRowToHeader() {
    final c = _controller;
    final table = _table;
    if (c == null || table == null) return;
    final activeRow = c.activePosition.row;
    if (activeRow <= 0) return; // already header
    _snapshot();
    final cells = _cellsOf(table);
    final tmp = cells[0];
    cells[0] = cells[activeRow];
    cells[activeRow] = tmp;
    _workingMarkdown = _buildTableMarkdown(cells, _alignmentsOf(table));
    _reloadAfterExternalChange(active: const TablePosition(row: 0, column: 0));
  }

  Future<void> _pasteTabularData() async {
    final table = _table;
    final c = _controller;
    if (table == null || c == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final rows = TableClipboardParser.parse(text);
    if (rows.isEmpty) return;

    _snapshot();
    final cells = _cellsOf(table);
    final startRow = c.activePosition.row;
    final startCol = c.activePosition.column;
    final colCount = cells.first.length;

    for (var r = 0; r < rows.length; r++) {
      final targetRow = startRow + r;
      while (targetRow >= cells.length) {
        cells.add(List<String>.filled(colCount, ''));
      }
      for (var cc = 0; cc < rows[r].length; cc++) {
        final targetCol = startCol + cc;
        if (targetCol >= cells[targetRow].length) continue;
        cells[targetRow][targetCol] = rows[r][cc];
      }
    }

    _workingMarkdown = _buildTableMarkdown(cells, _alignmentsOf(table));
    _reloadAfterExternalChange(
      active: TablePosition(row: startRow, column: startCol),
    );
  }

  String? _result() {
    if (_deleted) return '';
    return _dirty ? _workingMarkdown : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final controller = _controller;
    final table = _table;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop<String>(_result());
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.check),
            tooltip: 'Done',
            onPressed: () => Navigator.of(context).pop<String>(_result()),
          ),
          title: Text(
            widget.title,
            style: AppTypography.title.copyWith(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowUUpLeft),
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowUUpRight),
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
              color: colors.surface,
              onSelected: (v) {
                switch (v) {
                  case 'dup_row':
                    _runControllerOp((c) => c.duplicateCurrentRow());
                  case 'dup_col':
                    _runControllerOp((c) => c.duplicateCurrentColumn());
                  case 'row_up':
                    _runControllerOp(
                        (c) => c.moveCurrentRow(c.activePosition.row - 1));
                  case 'row_down':
                    _runControllerOp(
                        (c) => c.moveCurrentRow(c.activePosition.row + 1));
                  case 'col_left':
                    _runControllerOp(
                        (c) => c.moveCurrentColumn(c.activePosition.column - 1));
                  case 'col_right':
                    _runControllerOp(
                        (c) => c.moveCurrentColumn(c.activePosition.column + 1));
                  case 'promote':
                    _promoteActiveRowToHeader();
                  case 'paste':
                    _pasteTabularData();
                  case 'preview':
                    setState(() => _showPreview = !_showPreview);
                  case 'delete':
                    _deleteTable();
                }
              },
              itemBuilder: (_) => [
                _menuItem('dup_row', PhosphorIconsRegular.copy, 'Duplicate row'),
                _menuItem('dup_col', PhosphorIconsRegular.copy, 'Duplicate column'),
                _menuItem('row_up', PhosphorIconsRegular.arrowUp, 'Move row up'),
                _menuItem('row_down', PhosphorIconsRegular.arrowDown, 'Move row down'),
                _menuItem('col_left', PhosphorIconsRegular.arrowLeft, 'Move column left'),
                _menuItem('col_right', PhosphorIconsRegular.arrowRight, 'Move column right'),
                _menuItem('promote', PhosphorIconsRegular.rows, 'Make row the header'),
                _menuItem('paste', PhosphorIconsRegular.clipboard, 'Paste CSV / TSV'),
                _menuItem(
                  'preview',
                  PhosphorIconsRegular.eye,
                  _showPreview ? 'Hide preview' : 'Show preview',
                ),
                const PopupMenuDivider(),
                _menuItem('delete', PhosphorIconsRegular.trash, 'Delete table'),
              ],
            ),
          ],
        ),
        body: controller == null || table == null
            ? Center(
                child: Text(
                  'This table could not be parsed.',
                  style: AppTypography.body.copyWith(color: colors.textSecondary),
                ),
              )
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showPreview)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          0,
                        ),
                        child: MarkdownTableView(table: table, readOnly: true),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: MarkdownTableEditor(
                          key: ValueKey(controller),
                          controller: controller,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    final colors = context.appColors;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}


