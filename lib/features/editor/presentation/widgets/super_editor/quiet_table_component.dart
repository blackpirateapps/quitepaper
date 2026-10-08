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

  Future<void> _openTableEditor(
    BuildContext context,
    MarkdownTable table,
    String tableMarkdown, [
    TablePosition? initialPos,
  ]) async {
    var workingMarkdown = tableMarkdown;
    var currentTable = table;

    final controller = MarkdownTableController(
      table: currentTable,
      getDocumentValue: () => TextEditingValue(text: workingMarkdown),
      onUpdateDocument: (newVal) {
        workingMarkdown = newVal.text;
        final reParsed = const MarkdownTableParser().findTables(workingMarkdown);
        if (reParsed.isNotEmpty) {
          currentTable = reParsed.first;
        }
      },
      initialPosition: initialPos,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.appColors;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIconsRegular.table, size: 20, color: colors.textPrimary),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Table',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: MarkdownTableEditor(
                        controller: controller,
                        onClose: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (workingMarkdown.trim() != tableMarkdown.trim() && mounted) {
      try {
        final doc = deserializeMarkdownToDocument(workingMarkdown);
        if (doc.isNotEmpty) {
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
        }
      } catch (_) {}
    }
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

    return BoxComponent(
      key: widget.componentKey,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: colors.divider),
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
                    'Table (${widget.node.rowCount} × ${widget.node.columnCount})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (markdownTable != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _openTableEditor(context, markdownTable, tableMarkdown),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIconsRegular.pencilSimple, size: 13, color: colors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _deleteTable,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(PhosphorIconsRegular.trash, size: 13, color: colors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
            // Table content
            if (markdownTable != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: MarkdownTableView(
                  table: markdownTable,
                  readOnly: false,
                  onCellTap: (pos) => _openTableEditor(context, markdownTable, tableMarkdown, pos),
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
