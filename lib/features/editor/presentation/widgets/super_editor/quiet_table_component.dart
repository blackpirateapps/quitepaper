import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_radii.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_table.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_view.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/table_editor_screen.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

/// Custom [ComponentBuilder] for SuperEditor that renders [TableBlockNode]
/// using Quiet Paper's [MarkdownTableView] and provides tap-to-edit
/// via [MarkdownTableEditor].
class QuietTableComponentBuilder implements ComponentBuilder {
  QuietTableComponentBuilder({required this.editor});

  final Editor editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! TableBlockNode) {
      return null;
    }

    return MarkdownTableViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      columnWidth: const IntrinsicColumnWidth(),
      fit: TableComponentFit.scale,
      cells: [
        for (int i = 0; i < node.rowCount; i += 1)
          [
            for (final cell in node.getRow(i))
              MarkdownTableCellViewModel(
                nodeId: cell.id,
                createdAt: cell.metadata[NodeMetadata.createdAt],
                text: cell.text,
                textAlign: TextAlign.left,
                textStyleBuilder: noStyleBuilder,
                padding: const EdgeInsets.all(8.0),
                metadata: cell.metadata,
              ),
          ],
      ],
      selectionColor: const Color(0x00000000),
      caretColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! MarkdownTableViewModel) {
      return null;
    }

    final node = editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! TableBlockNode) {
      return null;
    }

    return QuietTableComponent(
      key: ValueKey('quiet_table_${componentViewModel.nodeId}'),
      componentKey: componentContext.componentKey,
      node: node,
      editor: editor,
    );
  }
}

/// A document component that renders a Markdown table and enables
/// cell editing via [MarkdownTableEditor].
class QuietTableComponent extends StatefulWidget {
  const QuietTableComponent({
    super.key,
    required this.componentKey,
    required this.node,
    required this.editor,
  });

  final GlobalKey componentKey;
  final TableBlockNode node;
  final Editor editor;

  @override
  State<QuietTableComponent> createState() => _QuietTableComponentState();
}

class _QuietTableComponentState extends State<QuietTableComponent> {
  /// Non-null while the table is being edited inline (tap-to-activate).
  MarkdownTableController? _editController;
  String _workingMarkdown = '';

  bool get _isEditing => _editController != null;

  @override
  void dispose() {
    _editController?.dispose();
    super.dispose();
  }

  String _serializeTableNode(TableBlockNode node) {
    try {
      final doc = MutableDocument(nodes: [node]);
      final md = serializeDocumentToMarkdown(doc);
      if (md.trim().isNotEmpty) return md;
    } catch (_) {}

    final buffer = StringBuffer();
    if (node.rowCount > 0) {
      buffer.write('|');
      for (final cell in node.getRow(0)) {
        buffer.write(' ${cell.text.toPlainText()} |');
      }
      buffer.writeln();
      buffer.write('|');
      for (int i = 0; i < node.columnCount; i++) {
        buffer.write(' --- |');
      }
      buffer.writeln();
      for (int r = 1; r < node.rowCount; r++) {
        buffer.write('|');
        for (final cell in node.getRow(r)) {
          buffer.write(' ${cell.text.toPlainText()} |');
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  MarkdownTable? _parseMarkdownTable(String markdown) {
    if (markdown.trim().isEmpty) return null;
    final tables = const MarkdownTableParser().findTables(markdown);
    if (tables.isNotEmpty) {
      return tables.first;
    }
    return null;
  }

  /// Enters inline tap-to-activate editing, seeding a controller from the
  /// node's current Markdown. Edits stay local until [_commitEdit].
  void _startInlineEdit([TablePosition? initialPos]) {
    if (_isEditing) {
      if (initialPos != null) _editController!.setActivePosition(initialPos);
      return;
    }
    _workingMarkdown = _serializeTableNode(widget.node);
    final tables = const MarkdownTableParser().findTables(_workingMarkdown);
    if (tables.isEmpty) return;

    _editController = MarkdownTableController(
      table: tables.first,
      getDocumentValue: () => TextEditingValue(text: _workingMarkdown),
      onUpdateDocument: (newVal) => _workingMarkdown = newVal.text,
      initialPosition: initialPos,
    );
    setState(() {});

    if (initialPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editController?.setActivePosition(initialPos);
      });
    }
  }

  /// Commits the working Markdown back into the document node and leaves edit
  /// mode. Mirrors the §155 frontmatter lesson: we only rewrite the node when
  /// the user is done, so typing never tears down the live component.
  void _commitEdit() {
    final original = _serializeTableNode(widget.node);
    final working = _workingMarkdown;
    _editController?.dispose();
    _editController = null;
    if (working.trim() != original.trim()) {
      _applyMarkdownToNode(working);
    }
    if (mounted) setState(() {});
  }

  void _applyMarkdownToNode(String markdown) {
    if (!mounted) return;
    try {
      final doc = deserializeMarkdownToDocument(markdown);
      if (doc.isEmpty) return;
      final newTableNode = doc.firstWhere(
        (n) => n is TableBlockNode,
        orElse: () => doc.first,
      );
      if (newTableNode is TableBlockNode) {
        widget.editor.execute([
          ReplaceNodeRequest(
            existingNodeId: widget.node.id,
            newNode: newTableNode,
          ),
        ]);
      }
    } catch (_) {}
  }

  /// Opens the full-screen enhanced table editor as a new page (not a popup).
  Future<void> _openFullScreen() async {
    final current =
        _isEditing ? _workingMarkdown : _serializeTableNode(widget.node);
    final result = await TableEditorScreen.open(
      context,
      initialTableMarkdown: current,
    );
    if (!mounted || result == null) return;

    if (result.trim().isEmpty) {
      _editController?.dispose();
      _editController = null;
      _deleteTable();
      return;
    }

    if (_isEditing) {
      _workingMarkdown = result;
      _editController?.reloadFrom(TextEditingValue(text: result));
    }
    _applyMarkdownToNode(result);
    if (mounted) setState(() {});
  }


  void _deleteTable() {
    widget.editor.execute([
      DeleteNodeRequest(nodeId: widget.node.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tableMarkdown = _serializeTableNode(widget.node);
    final markdownTable = _parseMarkdownTable(tableMarkdown);
    final editing = _isEditing && _editController != null;

    final rowCount = editing ? _editController!.table.rowCount : widget.node.rowCount;
    final colCount =
        editing ? _editController!.table.columnCount : widget.node.columnCount;

    return BoxComponent(
      key: widget.componentKey,
      child: Container(
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
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4.0),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.table, size: 14, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Table ($rowCount × $colCount)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (editing)
                    _HeaderAction(
                      icon: PhosphorIconsRegular.check,
                      label: 'Done',
                      color: colors.accent,
                      onTap: _commitEdit,
                    ),
                  _HeaderAction(
                    icon: PhosphorIconsRegular.arrowsOut,
                    tooltip: 'Open full screen',
                    color: colors.textSecondary,
                    onTap: _openFullScreen,
                  ),
                  const SizedBox(width: 4),
                  _HeaderAction(
                    icon: PhosphorIconsRegular.trash,
                    tooltip: 'Delete table',
                    color: colors.textTertiary,
                    onTap: () {
                      _editController?.dispose();
                      _editController = null;
                      _deleteTable();
                    },
                  ),
                ],
              ),
            ),
            // Table content
            if (editing)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: MarkdownTableEditor(
                  controller: _editController!,
                  onClose: _commitEdit,
                ),
              )
            else if (markdownTable != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: MarkdownTableView(
                  table: markdownTable,
                  readOnly: false,
                  onCellTap: _startInlineEdit,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  tableMarkdown,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small tappable icon (+ optional label) used in the table component header.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: child) : child;
  }
}

/// A specialized [DocumentNodeMarkdownSerializer] that serializes [TableBlockNode]
/// to Markdown and guarantees a blank line before following nodes.
class QuietTableBlockNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<TableBlockNode> {
  const QuietTableBlockNodeSerializer();

  @override
  String doSerialization(
    Document document,
    TableBlockNode node, {
    NodeSelection? selection,
  }) {
    const defaultSerializer = TableBlockNodeSerializer();
    final serialized = defaultSerializer.serialize(document, node, selection: selection);
    if (serialized == null || serialized.isEmpty) return serialized ?? '';

    final buffer = StringBuffer(serialized);
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }
    return buffer.toString();
  }
}

