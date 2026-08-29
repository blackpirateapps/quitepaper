import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_formatter.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_alignment.dart';

void main() {
  const parser = MarkdownTableParser();

  group('MarkdownTableFormatter - Pure Transformations', () {
    test('insertTable creates a valid 3x3 table at cursor', () {
      const initialText = '# Notes\n';
      final initialVal = TextEditingValue(
        text: initialText,
        selection: const TextSelection.collapsed(offset: initialText.length),
      );

      final result = MarkdownTableFormatter.insertTable(
        value: initialVal,
        rows: 3,
        columns: 3,
      );

      expect(result.text.contains('| Header 1 | Header 2 | Header 3 |'), isTrue);
      expect(result.text.contains('| --- | --- | --- |'), isTrue);

      final tables = parser.findTables(result.text);
      expect(tables.length, 1);
      expect(tables.first.columnCount, 3);
      expect(tables.first.rowCount, 4); // 1 header + 3 body rows
    });

    test('updateCell updates target cell and escapes unescaped pipes', () {
      const initialText = '''
| Name | Description |
| --- | --- |
| Foo | Bar |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(
        text: initialText,
        selection: const TextSelection.collapsed(offset: 0),
      );

      final result = MarkdownTableFormatter.updateCell(
        value: initialVal,
        table: table,
        row: 1,
        column: 1,
        newCellText: 'Baz | Qux',
      );

      expect(result.text.contains(r'Baz \| Qux'), isTrue);

      final reloaded = parser.findTables(result.text).first;
      expect(reloaded.bodyRows[0].cells[1].trimmedText, r'Baz \| Qux');
    });

    test('addRow inserts a row below specified row index', () {
      const initialText = '''
| Name | Status |
| --- | --- |
| Task 1 | Done |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      final result = MarkdownTableFormatter.addRow(
        value: initialVal,
        table: table,
        afterRowIndex: 1,
      );

      final reloaded = parser.findTables(result.text).first;
      expect(reloaded.rowCount, 3); // 1 header + 2 body rows
      expect(reloaded.bodyRows[0].cells[0].trimmedText, 'Task 1');
      expect(reloaded.bodyRows[1].cells[0].trimmedText, '');
    });

    test('deleteRow removes target body row and preserves surrounding structure', () {
      const initialText = '''
| Name | Status |
| --- | --- |
| Task 1 | Done |
| Task 2 | WIP |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      final result = MarkdownTableFormatter.deleteRow(
        value: initialVal,
        table: table,
        rowIndex: 1, // Task 1
      );

      final reloaded = parser.findTables(result.text).first;
      expect(reloaded.rowCount, 2); // 1 header + 1 body row
      expect(reloaded.bodyRows[0].cells[0].trimmedText, 'Task 2');
    });

    test('addColumn adds a column to header, delimiter, and all body rows', () {
      const initialText = '''
| A | B |
| --- | --- |
| 1 | 2 |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      final result = MarkdownTableFormatter.addColumn(
        value: initialVal,
        table: table,
        afterColumnIndex: 1,
      );

      final reloaded = parser.findTables(result.text).first;
      expect(reloaded.columnCount, 3);
      expect(reloaded.headerRow.cells.length, 3);
      expect(reloaded.bodyRows[0].cells.length, 3);
    });

    test('deleteColumn deletes a column but protects the final column from deletion', () {
      const initialText = '''
| A | B |
| --- | --- |
| 1 | 2 |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      final result = MarkdownTableFormatter.deleteColumn(
        value: initialVal,
        table: table,
        columnIndex: 0,
      );

      final reloaded = parser.findTables(result.text).first;
      expect(reloaded.columnCount, 1);
      expect(reloaded.headerRow.cells[0].trimmedText, 'B');
      expect(reloaded.bodyRows[0].cells[0].trimmedText, '2');

      // Attempting to delete the final column should be prevented
      final finalResult = MarkdownTableFormatter.deleteColumn(
        value: result,
        table: reloaded,
        columnIndex: 0,
      );
      expect(finalResult.text, result.text);
    });

    test('setColumnAlignment modifies the delimiter cell appropriately', () {
      const initialText = '''
| Left | Center | Right |
| --- | --- | --- |
| 1 | 2 | 3 |
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      var res = MarkdownTableFormatter.setColumnAlignment(
        value: initialVal,
        table: table,
        columnIndex: 0,
        alignment: MarkdownTableAlignment.left,
      );
      var reloaded = parser.findTables(res.text).first;

      res = MarkdownTableFormatter.setColumnAlignment(
        value: res,
        table: reloaded,
        columnIndex: 1,
        alignment: MarkdownTableAlignment.center,
      );
      reloaded = parser.findTables(res.text).first;

      res = MarkdownTableFormatter.setColumnAlignment(
        value: res,
        table: reloaded,
        columnIndex: 2,
        alignment: MarkdownTableAlignment.right,
      );
      reloaded = parser.findTables(res.text).first;

      expect(reloaded.alignments[0], MarkdownTableAlignment.left);
      expect(reloaded.alignments[1], MarkdownTableAlignment.center);
      expect(reloaded.alignments[2], MarkdownTableAlignment.right);
    });

    test('deleteTable removes entire table block cleanly', () {
      const initialText = '''
Before text

| A | B |
| --- | --- |
| 1 | 2 |

After text
''';
      final table = parser.findTables(initialText).first;
      final initialVal = TextEditingValue(text: initialText);

      final result = MarkdownTableFormatter.deleteTable(
        value: initialVal,
        table: table,
      );

      expect(result.text.contains('| A | B |'), isFalse);
      expect(result.text.contains('Before text'), isTrue);
      expect(result.text.contains('After text'), isTrue);
    });
  });
}
