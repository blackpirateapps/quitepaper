import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/smart_table_display.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/domain/smart_tables/formula_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'calculated columns fill blanks, preserve overrides and new row intent',
    () {
      const source = r'''| Qty | Price | Total |
| --- | --- | --- |
| 2 | 125 | =A2*B2 |
| 3 | 40 | |
| 7 | 10 | Manual |''';
      var value = const TextEditingValue(text: source);
      final c = MarkdownTableController(
        table: const MarkdownTableParser().findTables(source).single,
        getDocumentValue: () => value,
        onUpdateDocument: (v) => value = v,
        initialPosition: const TablePosition(row: 1, column: 2),
      );
      addTearDown(c.dispose);
      c.fillCalculatedColumn();
      expect(c.table.getCell(2, 2)!.trimmedText, '=A3*B3');
      expect(c.table.getCell(3, 2)!.trimmedText, 'Manual');
      c.createSummary('SUM');
      final before = value.text;
      c.setActivePosition(const TablePosition(row: 3, column: 2));
      c.addRowBelow();
      expect(c.table.getCell(4, 2)!.trimmedText, '=A5*B5');
      expect(c.table.getCell(5, 2)!.trimmedText, '=SUM(C2:C5)');
      c.undo();
      expect(value.text, before);
      c.redo();
      expect(c.hasSummary, true);
      final reopened = deserializeQuietMarkdown(
        value.text,
      ).where((n) => n.metadata[quietTableSourceKey] != null).single;
      expect(reopened.metadata[quietTableSourceKey], value.text);
      c.setNumericFormat({'type': 'currency', 'currency': 'INR', 'digits': 2});
      expect(c.displayedCell(1, 2, locale: 'en_IN'), '₹250.00');
      expect(value.text, contains('=A2*B2'));
      expect(value.text, contains('calculatedColumns'));
    },
  );
  test('format uses exact decimal digits, locale affixes and grouping', () {
    CellValue n(String s) => CellValue.numeric(TableDecimal.parse(s));
    expect(
      SmartTableDisplay.format(n('0.15'), {
        'type': 'percent',
        'digits': 0,
      }, locale: 'en_US'),
      '15%',
    );
    expect(
      SmartTableDisplay.format(n('2500'), {
        'type': 'currency',
        'currency': 'INR',
        'digits': 2,
      }, locale: 'en_IN'),
      '₹2,500.00',
    );
    expect(
      SmartTableDisplay.format(n('1234567.125'), {
        'type': 'decimal',
        'digits': 2,
      }, locale: 'en_IN'),
      '12,34,567.13',
    );
    expect(
      SmartTableDisplay.format(n('1234.5'), {
        'type': 'decimal',
        'digits': 2,
      }, locale: 'de_DE'),
      '1.234,50',
    );
    expect(
      SmartTableDisplay.format(n('9007199254740993.12'), {
        'type': 'decimal',
        'digits': 2,
      }, locale: 'en_US'),
      '9,007,199,254,740,993.12',
    );
    expect(
      SmartTableDisplay.format(n('-1.235'), {
        'type': 'currency',
        'currency': 'USD',
        'digits': 2,
      }, locale: 'en_US'),
      r'-$1.24',
    );
    expect(
      SmartTableDisplay.format(n('2'), {
        'type': 'currency',
        'currency': 'XYZ',
        'digits': 0,
      }, locale: 'en_US'),
      contains('XYZ'),
    );
  });
  test(
    'deleting the example row preserves calculated-column intent for new rows',
    () {
      const source = '| Qty | Total |\n| --- | --- |\n| 2 | =A2*5 |\n| 3 | |';
      var value = const TextEditingValue(text: source);
      final c = MarkdownTableController(
        table: const MarkdownTableParser().findTables(source).single,
        getDocumentValue: () => value,
        onUpdateDocument: (v) => value = v,
        initialPosition: const TablePosition(row: 1, column: 1),
      );
      c.fillCalculatedColumn();
      c.deleteCurrentRow();
      c.setActivePosition(const TablePosition(row: 1, column: 0));
      c.addRowBelow();
      expect(c.table.getCell(2, 1)!.trimmedText, '=A3*5');
      c.undo();
      expect(c.table.rowCount, 2);
      c.redo();
      expect(c.table.getCell(2, 1)!.trimmedText, '=A3*5');
      c.dispose();
    },
  );
}
