import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/smart_table_edits.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const parser = MarkdownTableParser();
  const initial =
      'Before\n\n| Qty | Price | Total |\n| --- | ---: | ---: |\n| 2 | 125 | =A2*B2 |\n| 3 | 40 | =A3*B3 |\n\nAfter';
  test('summary creation, append/delete rebasing and atomic undo', () {
    var value = const TextEditingValue(text: initial);
    final c = MarkdownTableController(
      table: parser.findTables(initial).first,
      getDocumentValue: () => value,
      onUpdateDocument: (v) => value = v,
      initialPosition: const TablePosition(row: 1, column: 2),
    );
    addTearDown(c.dispose);
    c.createSummary('SUM');
    expect(c.hasSummary, true);
    expect(c.calculations.value(3, 2).display, '370');
    final summarySource = value.text;
    c.setActivePosition(const TablePosition(row: 2, column: 2));
    c.addRowBelow();
    expect(c.table.getCell(4, 2)!.trimmedText, '=SUM(C2:C4)');
    c.undo();
    expect(value.text, summarySource);
    c.redo();
    expect(c.hasSummary, true);
    c.setActivePosition(const TablePosition(row: 1, column: 0));
    c.deleteCurrentRow();
    expect(c.table.getCell(1, 2)!.trimmedText, '=A2*B2');
    expect(c.table.getCell(3, 2)!.trimmedText, '=SUM(C2:C3)');
    expect(value.text, startsWith('Before\n\n'));
    expect(value.text, endsWith('\n\nAfter'));
  });
  test('column structural deletion produces REF and rebases anchors', () {
    const source = r'''| A | B | C |
| --- | --- | --- |
| 2 | 3 | =A2+$B$2 |''';
    final result = SmartTableEdits.structure(
      source,
      parser.findTables(source).first,
      rows: false,
      index: 1,
      delete: true,
    );
    expect(result.text, contains('=A2+#REF!'));
  });
  test('mixed range summary never mutates source and counts errors', () {
    const source = '| A | B |\n| --- | --- |\n| 0 | 3 |\n| text | =1/0 |';
    var value = const TextEditingValue(text: source);
    final c = MarkdownTableController(
      table: parser.findTables(source).first,
      getDocumentValue: () => value,
      onUpdateDocument: (v) => value = v,
    );
    addTearDown(c.dispose);
    c.selectRange(
      const TablePosition(row: 1, column: 0),
      const TablePosition(row: 2, column: 1),
    );
    final s = c.quickSummary;
    expect(s.result('SUM'), '3');
    expect(s.result('COUNT'), '2');
    expect(s.excludedErrors, 1);
    expect(value.text, source);
    expect(c.canUndo, false);
    expect(c.selectionTsv(), '0\t3\ntext\t=1/0');
  });
  test('unknown metadata and externally edited summary are preserved', () {
    const source = '$initial\n';
    final table = parser.findTables(source).first;
    final withSummary = SmartTableEdits.summary(source, table, 2, 'SUM').text;
    final changed = withSummary.replaceFirst('=SUM(C2:C3)', 'Manual total');
    final t = parser.findTables(changed).first;
    expect(
      SmartTableEdits.hasSummary(
        tableRawCells(t),
        SmartTableMetadata.read(changed, t),
      ),
      false,
    );
    final unknown = withSummary.replaceFirst(':v1', ':v88');
    final u = parser.findTables(unknown).first;
    expect(SmartTableEdits.summary(unknown, u, 1, 'MAX').text, unknown);
    final inserted = SmartTableEdits.structure(
      unknown,
      u,
      rows: true,
      index: 1,
      delete: false,
    ).text;
    expect(inserted, contains('<!-- quiet-paper-table:v88'));
  });
}
