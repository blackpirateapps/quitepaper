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
        if (mounted) setState(() {});
      },
      initialPosition: const TablePosition(row: 0, column: 0),
    );
  }

  MarkdownTable? get _table {
    final tables = _parser.findTables(_workingMarkdown);
    return tables.isEmpty ? null : tables.first;
  }

  void _undo() => _controller?.undo();
  void _redo() => _controller?.redo();

  void _runControllerOp(void Function(MarkdownTableController c) op) {
    final c = _controller;
    if (c != null) op(c);
  }

  void _deleteTable() {
    _deleted = true;
    _dirty = true;
    Navigator.of(context).pop<String>('');
  }

  void _promoteActiveRowToHeader() {
    final c = _controller;
    if (c != null) c.promoteRowToHeader();
  }

  Future<void> _pasteTabularData() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || _controller == null) return;
    final rows = TableClipboardParser.parse(data?.text ?? '');
    if (rows.isNotEmpty) _controller!.pasteCells(rows);
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
              onPressed: controller?.canUndo == true ? _undo : null,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowUUpRight),
              tooltip: 'Redo',
              onPressed: controller?.canRedo == true ? _redo : null,
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
                      (c) => c.moveCurrentRow(c.activePosition.row - 1),
                    );
                  case 'row_down':
                    _runControllerOp(
                      (c) => c.moveCurrentRow(c.activePosition.row + 1),
                    );
                  case 'col_left':
                    _runControllerOp(
                      (c) => c.moveCurrentColumn(c.activePosition.column - 1),
                    );
                  case 'col_right':
                    _runControllerOp(
                      (c) => c.moveCurrentColumn(c.activePosition.column + 1),
                    );
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
                _menuItem(
                  'dup_row',
                  PhosphorIconsRegular.copy,
                  'Duplicate row',
                ),
                _menuItem(
                  'dup_col',
                  PhosphorIconsRegular.copy,
                  'Duplicate column',
                ),
                _menuItem(
                  'row_up',
                  PhosphorIconsRegular.arrowUp,
                  'Move row up',
                ),
                _menuItem(
                  'row_down',
                  PhosphorIconsRegular.arrowDown,
                  'Move row down',
                ),
                _menuItem(
                  'col_left',
                  PhosphorIconsRegular.arrowLeft,
                  'Move column left',
                ),
                _menuItem(
                  'col_right',
                  PhosphorIconsRegular.arrowRight,
                  'Move column right',
                ),
                _menuItem(
                  'promote',
                  PhosphorIconsRegular.rows,
                  'Make row the header',
                ),
                _menuItem(
                  'paste',
                  PhosphorIconsRegular.clipboard,
                  'Paste CSV / TSV',
                ),
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
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
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
                        child: MarkdownTableView(
                          table: table,
                          sourceMarkdown: _workingMarkdown,
                          readOnly: true,
                        ),
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
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
