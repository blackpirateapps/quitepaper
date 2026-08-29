import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_alignment.dart';

void main() {
  const parser = MarkdownTableParser();

  group('MarkdownTableParser - Standard GFM Tables', () {
    test('parses simple 2x2 table with leading and trailing pipes', () {
      const text = '''
# Heading

| Name | Status |
| --- | --- |
| OCR | Done |
| Sync | WIP |

More text
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.columnCount, 2);
      expect(table.rowCount, 3); // 1 header + 2 body rows

      // Header row
      expect(table.headerRow.cells[0].trimmedText, 'Name');
      expect(table.headerRow.cells[1].trimmedText, 'Status');

      // Delimiter row alignments
      expect(table.alignments[0], MarkdownTableAlignment.none);
      expect(table.alignments[1], MarkdownTableAlignment.none);

      // Body rows
      expect(table.bodyRows[0].cells[0].trimmedText, 'OCR');
      expect(table.bodyRows[0].cells[1].trimmedText, 'Done');
      expect(table.bodyRows[1].cells[0].trimmedText, 'Sync');
      expect(table.bodyRows[1].cells[1].trimmedText, 'WIP');

      // Exact source slice matches
      final tableSlice = text.substring(table.sourceStart, table.sourceEnd);
      expect(tableSlice.contains('| Name | Status |'), isTrue);
      expect(tableSlice.contains('| Sync | WIP |'), isTrue);
      expect(tableSlice.contains('More text'), isFalse);
    });

    test('parses tables without outer pipes', () {
      const text = '''
Name | Status | Notes
---|:---:|---:
OCR | Done | Local
Sync | Done | E2E
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.columnCount, 3);
      expect(table.rowCount, 3);

      expect(table.headerRow.cells[0].trimmedText, 'Name');
      expect(table.headerRow.cells[1].trimmedText, 'Status');
      expect(table.headerRow.cells[2].trimmedText, 'Notes');

      expect(table.alignments[0], MarkdownTableAlignment.none);
      expect(table.alignments[1], MarkdownTableAlignment.center);
      expect(table.alignments[2], MarkdownTableAlignment.right);
    });

    test('parses table with escaped pipes without treating them as separators', () {
      const text = r'''
| Feature | Description |
| --- | --- |
| Option A | Value \| Sub-value |
| Option B | Normal |
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.columnCount, 2);
      expect(table.bodyRows[0].cells.length, 2);
      expect(table.bodyRows[0].cells[0].trimmedText, 'Option A');
      expect(table.bodyRows[0].cells[1].trimmedText, r'Value \| Sub-value');
    });

    test('parses table with inline code containing pipes without treating them as separators', () {
      const text = '''
| Syntax | Example |
| --- | --- |
| Pipe in code | `a|b` |
| Double backtick | ``c|d`` |
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.columnCount, 2);
      expect(table.bodyRows[0].cells[1].trimmedText, '`a|b`');
      expect(table.bodyRows[1].cells[1].trimmedText, '``c|d``');
    });

    test('ignores tables inside fenced code blocks', () {
      const text = '''
```markdown
| In Code | Block |
| --- | --- |
| 1 | 2 |
```

| Real Table | Col 2 |
| --- | --- |
| A | B |
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.headerRow.cells[0].trimmedText, 'Real Table');
    });

    test('handles empty cells gracefully', () {
      const text = '''
| A | B | C |
| --- | --- | --- |
| | Value | |
| | | |
''';

      final tables = parser.findTables(text);
      expect(tables.length, 1);

      final table = tables.first;
      expect(table.columnCount, 3);
      expect(table.bodyRows[0].cells[0].trimmedText, '');
      expect(table.bodyRows[0].cells[1].trimmedText, 'Value');
      expect(table.bodyRows[0].cells[2].trimmedText, '');
      expect(table.bodyRows[1].cells.every((c) => c.isEmpty), isTrue);
    });

    test('tolerates incomplete table while typing without crashing', () {
      const incomplete1 = '| A | B |';
      expect(parser.findTables(incomplete1), isEmpty);

      const incomplete2 = '| A |\n|';
      expect(parser.findTables(incomplete2), isEmpty);

      const incomplete3 = '| A | B |\n| invalid | delimiter |';
      expect(parser.findTables(incomplete3), isEmpty);
    });

    test('maps source offsets accurately to cell coordinates', () {
      const text = '''
| Col1 | Col2 |
| --- | --- |
| Apple | Banana |
''';

      final tables = parser.findTables(text);
      final table = tables.first;

      final appleIndex = text.indexOf('Apple');
      final pos = table.findPositionAtSourceOffset(appleIndex);
      expect(pos, isNotNull);
      expect(pos!.row, 1);
      expect(pos.column, 0);

      final cell = table.getCell(pos.row, pos.column);
      expect(cell!.trimmedText, 'Apple');
      expect(text.substring(cell.contentStart, cell.contentEnd), 'Apple');
    });
  });
}
