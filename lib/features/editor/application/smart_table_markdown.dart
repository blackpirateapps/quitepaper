import 'smart_table_edits.dart';
import 'smart_table_display.dart';

import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';

import '../presentation/widgets/super_editor/math/quiet_math_parser.dart';
import '../domain/markdown_table.dart';
import '../domain/smart_tables/formula_engine.dart';
import 'markdown_table_parser.dart';

const quietTableSourceKey = 'quietPaperTableSource';

List<List<String>> tableRawCells(MarkdownTable table) => [
  for (var r = 0; r < table.rowCount; r++)
    [
      for (var c = 0; c < table.columnCount; c++)
        table.getCell(r, c)?.trimmedText ?? '',
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
    return next != null &&
        const MarkdownTableParser()
            .findTables('${parser.current.content}\n$next')
            .isNotEmpty;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[parser.current.content];
    parser.advance();
    lines.add(parser.current.content);
    parser.advance();
    while (!parser.isDone &&
        parser.current.content.trim().isNotEmpty &&
        parser.current.content.contains('|') &&
        !parser.current.content.trimLeft().startsWith('<!--') &&
        !RegExp(r'^\s*(`{3,}|~{3,})').hasMatch(parser.current.content)) {
      lines.add(parser.current.content);
      parser.advance();
    }
    if (!parser.isDone &&
        parser.current.content.startsWith('<!-- quiet-paper-table:')) {
      while (!parser.isDone) {
        final line = parser.current.content;
        lines.add(line);
        parser.advance();
        if (line.contains('-->')) break;
      }
    }
    return md.Element.empty('quiet-table')
      ..attributes['source'] = lines.join('\n');
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
    cells: [
      for (final row in tableRawCells(table))
        [
          for (final cell in row)
            ParagraphNode(
              id: Editor.createNodeId(),
              text: AttributedText(cell),
            ),
        ],
    ],
  );
}

MutableDocument deserializeQuietMarkdown(String source) =>
    deserializeMarkdownToDocument(
      source,
      customBlockSyntax: const [QuietMathBlockSyntax(), QuietTableSyntax()],
      customElementToNodeConverters: const [
        QuietMathElementToNodeConverter(),
        QuietTableConverter(),
      ],
      inlineMarkdownSyntaxes: [
        QuietMathInlineSyntax(),
        ...defaultSuperEditorInlineSyntaxes,
      ],
    );

/// A display-only projection for native Markdown preview. Never use this as a
/// save or export source. Source offsets outside tables remain authoritative.
String projectSmartTableResults(String source, {String? locale}) {
  final tables = const MarkdownTableParser().findTables(source);
  for (final table in tables.reversed) {
    final engine = FormulaEngine(tableRawCells(table));
    final formats = SmartTableMetadata.read(source, table).section('formats');
    for (final row in table.allVisibleRows.reversed) {
      for (final cell in row.cells.reversed) {
        final raw = cell.trimmedText;
        final config = formats['${cell.columnIndex}'];
        if (config == null && !raw.startsWith('=') && !raw.startsWith("'=")) {
          continue;
        }
        source = source.replaceRange(
          cell.contentStart,
          cell.contentEnd,
          SmartTableDisplay.format(
            engine.value(cell.rowIndex, cell.columnIndex),
            config,
            locale: locale,
          ),
        );
      }
    }
  }
  return source;
}

/// Existing prose normalization must never reinterpret formula operators or
/// insert a blank line between a table and its attached annotation.
String transformOutsideQuietTables(
  String source,
  String Function(String) transform, {
  bool isolate = false,
}) {
  final tables = const MarkdownTableParser().findTables(source);
  if (tables.isEmpty) return transform(source);
  final output = StringBuffer();
  var offset = 0;
  for (final table in tables) {
    if (table.sourceStart < offset) continue;
    output.write(transform(source.substring(offset, table.sourceStart)));
    if (isolate && output.isNotEmpty && !output.toString().endsWith('\n\n')) {
      output.write('\n\n');
    }
    final end = SmartTableMetadata.read(source, table).sourceEnd;
    output.write(source.substring(table.sourceStart, end));
    if (isolate && !source.substring(end).startsWith('\n\n')) {
      output.write(source.substring(end).startsWith('\n') ? '\n' : '\n\n');
    }
    offset = end;
  }
  output.write(transform(source.substring(offset)));
  return output.toString();
}
