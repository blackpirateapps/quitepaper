import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_formatter.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';

void main() {
  const parser = MarkdownTableParser();

  TextEditingValue valueOf(String text) =>
      TextEditingValue(text: text, selection: const TextSelection.collapsed(offset: 0));

  group('MarkdownTableFormatter - moveRow', () {
    const text = '| H1 | H2 |\n'
        '| --- | --- |\n'
        '| a | b |\n'
        '| c | d |\n'
        '| e | f |';

    test('reorders two body rows (first body row moved to the bottom)', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.moveRow(
        value: valueOf(text),
        table: table,
        fromRowIndex: 1,
        toRowIndex: 3,
      );

      expect(
        result.text,
        '| H1 | H2 |\n'
        '| --- | --- |\n'
        '| c | d |\n'
        '| e | f |\n'
        '| a | b |',
      );
    });

    test('moving involving the header (index 0) is a no-op', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.moveRow(
        value: valueOf(text),
        table: table,
        fromRowIndex: 0,
        toRowIndex: 2,
      );
      expect(result.text, text);

      final result2 = MarkdownTableFormatter.moveRow(
        value: valueOf(text),
        table: table,
        fromRowIndex: 2,
        toRowIndex: 0,
      );
      expect(result2.text, text);
    });

    test('from == to is a no-op', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.moveRow(
        value: valueOf(text),
        table: table,
        fromRowIndex: 2,
        toRowIndex: 2,
      );
      expect(result.text, text);
    });
  });

  group('MarkdownTableFormatter - moveColumn', () {
    const text = '| Left | Right |\n'
        '|:---|---:|\n'
        '| a | b |';

    test('reorders columns and the alignment marker travels', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.moveColumn(
        value: valueOf(text),
        table: table,
        fromColumnIndex: 0,
        toColumnIndex: 1,
      );

      final lines = result.text.split('\n');
      expect(lines[0], '| Right | Left |');
      // Alignment travels: originally :--- (left) and ---: (right) swap places.
      expect(lines[1], '|---:|:---|');
      expect(lines[2], '| b | a |');
    });

    test('from == to is a no-op', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.moveColumn(
        value: valueOf(text),
        table: table,
        fromColumnIndex: 1,
        toColumnIndex: 1,
      );
      expect(result.text, text);
    });
  });

  group('MarkdownTableFormatter - duplicateRow', () {
    const text = '| H1 | H2 |\n'
        '| --- | --- |\n'
        '| a | b |';

    test('inserts an identical body row right after', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.duplicateRow(
        value: valueOf(text),
        table: table,
        rowIndex: 1,
      );

      expect(
        result.text,
        '| H1 | H2 |\n'
        '| --- | --- |\n'
        '| a | b |\n'
        '| a | b |',
      );
    });

    test('duplicating the header inserts its content as first body row, header unchanged', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.duplicateRow(
        value: valueOf(text),
        table: table,
        rowIndex: 0,
      );

      final lines = result.text.split('\n');
      // Header line is unchanged.
      expect(lines[0], '| H1 | H2 |');
      expect(lines[1], '| --- | --- |');
      // Header contents inserted as the new first body row.
      expect(lines[2], '| H1 | H2 |');
      expect(lines[3], '| a | b |');
    });
  });

  group('MarkdownTableFormatter - duplicateColumn', () {
    const text = '| H1 | H2 |\n'
        '|:---|---:|\n'
        '| a | b |';

    test('duplicates content and alignment to the right', () {
      final table = parser.findTables(text).first;
      final result = MarkdownTableFormatter.duplicateColumn(
        value: valueOf(text),
        table: table,
        columnIndex: 0,
      );

      final lines = result.text.split('\n');
      expect(lines[0], '| H1 | H1 | H2 |');
      // Alignment of the duplicated column (:--- ) is copied alongside it.
      expect(lines[1], '|:---|:---|---:|');
      expect(lines[2], '| a | a | b |');
    });
  });
}
