import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_table_formatter.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  test('existing source edit and reopen retain formulas and alignment', () {
    const source = 'Before\n\n| Item | Total |\n| --- | ---: |\n| Paper | =2*125 |\n\nAfter';
    const parser = MarkdownTableParser();
    final table = parser.findTables(source).single;
    final edited = MarkdownTableFormatter.updateCell(
      value: const TextEditingValue(text: source), table: table,
      row: 1, column: 0, newCellText: 'Pens',
    );
    final reopened = parser.findTables(edited.text).single;
    expect(reopened.getCell(1, 1)!.trimmedText, '=2*125');
    expect(reopened.getAlignment(1), table.getAlignment(1));
    expect(edited.text, startsWith('Before\n\n'));
    expect(edited.text, endsWith('\n\nAfter'));
    final visual = deserializeMarkdownToDocument(edited.text);
    expect(visual.whereType<TableBlockNode>().single.rowCount, 2);
    expect(serializeDocumentToMarkdown(visual), contains('=2*125'));
  });
}
