import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import '../domain/markdown_table.dart';
import '../domain/smart_tables/formula_engine.dart';
import 'markdown_table_parser.dart';

const quietTableSourceKey = 'quietPaperTableSource';

List<List<String>> tableRawCells(MarkdownTable table) => [
  for (var r = 0; r < table.rowCount; r++) [
    for (var c = 0; c < table.columnCount; c++) table.getCell(r,c)?.trimmedText ?? '',
  ],
];

/// Preserve the source table (including annotations) through SuperEditor's
/// inline parser. The node is still an ordinary TableBlockNode.
class QuietTableSyntax extends md.BlockSyntax {
  const QuietTableSyntax();
  @override
  RegExp get pattern => RegExp(r'\|');
  @override
  bool canParse(md.BlockParser parser) {
    final next = parser.peek(1)?.content;
    return next != null && const MarkdownTableParser().findTables('${parser.current.content}\n$next').isNotEmpty;
  }
  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[parser.current.content]; parser.advance();
    lines.add(parser.current.content); parser.advance();
    while (!parser.isDone && parser.current.content.trim().isNotEmpty && parser.current.content.contains('|') && !parser.current.content.trimLeft().startsWith('<!--')) {
      lines.add(parser.current.content); parser.advance();
    }
    if (!parser.isDone && parser.current.content.startsWith('<!-- quiet-paper-table:') && parser.current.content.endsWith('-->')) {
      lines.add(parser.current.content); parser.advance();
    }
    return md.Element.empty('quiet-table')..attributes['source'] = lines.join('\n');
  }
}

class QuietTableConverter implements ElementToNodeConverter {
  const QuietTableConverter();
  @override
  DocumentNode? handleElement(md.Element element) {
    if (element.tag != 'quiet-table') return null;
    return quietTableNode(element.attributes['source']!);
  }
}

TableBlockNode quietTableNode(String source, {String? id}) {
  final table = const MarkdownTableParser().findTables(source).first;
  return TableBlockNode(
    id: id ?? Editor.createNodeId(),
    metadata: {quietTableSourceKey: source},
    cells: [for (final row in tableRawCells(table)) [for (final cell in row)
      ParagraphNode(id: Editor.createNodeId(), text: AttributedText(cell)),
    ]],
  );
}

MutableDocument deserializeQuietMarkdown(String source) => deserializeMarkdownToDocument(
  source,
  customBlockSyntax: const [QuietTableSyntax()],
  customElementToNodeConverters: const [QuietTableConverter()],
);

/// A display-only projection for native Markdown preview. Never use this as a
/// save or export source. Source offsets outside tables remain authoritative.
String projectSmartTableResults(String source) {
  final tables = const MarkdownTableParser().findTables(source);
  for (final table in tables.reversed) {
    final engine = FormulaEngine(tableRawCells(table));
    for (final row in table.allVisibleRows.reversed) {
      for (final cell in row.cells.reversed) {
        final raw = cell.trimmedText;
        if (!raw.startsWith('=') && !raw.startsWith("'=")) continue;
        source = source.replaceRange(cell.contentStart, cell.contentEnd,
          engine.value(cell.rowIndex, cell.columnIndex).display);
      }
    }
  }
  return source;
}
