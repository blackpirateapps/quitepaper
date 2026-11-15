import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_table_component.dart';

void main() {
  test('raw source and unknown annotations survive visual/reopen roundtrip', () {
    const table =
        '| Item | Qty | Price | Total |\n| --- | ---: | ---: | ---: |\n| A \\| B | 2 | 125 | =B2*C2 |\n| Pens | 3 | 40 | =B3*C3 |\n| Total | | | =SUM(D2:D3) |\n<!-- quiet-paper-table:v99 {"unknown":true} -->';
    var source = 'Before\n\n$table\n\nAfter';
    for (var i = 0; i < 3; i++) {
      final doc = deserializeQuietMarkdown(source);
      final node = doc.whereType<TableBlockNode>().single;
      expect(node.metadata[quietTableSourceKey], table);
      source = serializeDocumentToMarkdown(
        doc,
        customNodeSerializers: const [QuietTableBlockNodeSerializer()],
      );
      expect(source, contains(table));
      expect(source, contains('Before'));
      expect(source, contains('After'));
    }
    final projected = projectSmartTableResults(source);
    expect(projected, contains('| A \\| B | 2 | 125 | 250 |'));
    expect(projected, contains('| Total | | | 370 |'));
    expect(source, contains('=B2*C2'));
  });
  test('code fences remain code and literal formulas remain literal', () {
    const source =
        "```text\n| A | B |\n| --- | --- |\n| 2 | =A2 |\n```\n\n| A | B |\n| --- | --- |\n| '=A1 | =1/0 |";
    final doc = deserializeQuietMarkdown(source);
    expect(doc.whereType<TableBlockNode>().length, 1);
    final projection = projectSmartTableResults(source);
    expect(projection, contains('| 2 | =A2 |'));
    expect(projection, contains('| =A1 | #DIV/0! |'));
  });
}
