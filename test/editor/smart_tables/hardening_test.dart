import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/application/smart_table_edits.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/domain/smart_tables/formula_engine.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_image_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_table_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const parser = MarkdownTableParser();
  const source =
      '| Qty | Price | Total |\n| --- | ---: | ---: |\n| 2 | 125 | =A2 * B2 |\n| 3 | 40 | =A3*B3 |';
  test(
    'legacy AST and normalizer preserve metadata and formula whitespace',
    () {
      final annotated = SmartTableEdits.summary(
        source,
        parser.findTables(source).single,
        2,
        'SUM',
      ).text;
      var markdown = 'Before\n\n$annotated\n\nAfter';
      final annotation = parser.findTables(markdown).single.annotation;
      for (var i = 0; i < 3; i++) {
        markdown = transformOutsideQuietTables(
          markdown,
          normalizeMarkdownForSuperEditor,
          isolate: true,
        );
        final doc = deserializeQuietMarkdown(markdown);
        markdown = serializeDocumentToMarkdown(
          doc,
          customNodeSerializers: const [QuietTableBlockNodeSerializer()],
        );
        markdown = transformOutsideQuietTables(
          markdown,
          normalizeInlineMarkdownSpacing,
        );
        expect(markdown, contains('=A2 * B2'));
        expect(markdown, contains(annotation));
      }
      final legacy = const RichDocumentParser().parse(markdown);
      final serialized = const RichDocumentSerializer().serialize(legacy);
      expect(serialized, contains(annotation));
      expect(serialized, contains('=A2 * B2'));
    },
  );
  test(
    'unknown multiline, malformed metadata, Unicode and escaped pipes survive',
    () {
      for (final comment in [
        '<!-- quiet-paper-table:v99\n{"x":"数据 \\u003e"}\n-->',
        '<!-- quiet-paper-table:v1 not json -->',
      ]) {
        final text = '$source\n$comment';
        final document = deserializeQuietMarkdown(text);
        expect(
          serializeDocumentToMarkdown(
            document,
            customNodeSerializers: const [QuietTableBlockNodeSerializer()],
          ),
          contains(comment),
        );
        final changed = SmartTableEdits.structure(
          text,
          parser.findTables(text).single,
          rows: true,
          index: 2,
          delete: false,
        ).text;
        expect(changed, contains(comment));
      }
      const raw = r'''| 数据 | Raw |
| --- | --- |
| A \| B | `x|y` |
| '=A1 | =SUM(A1:A1) |''';
      final node = deserializeQuietMarkdown(
        raw,
      ).whereType<TableBlockNode>().single;
      expect(node.metadata[quietTableSourceKey], raw);
    },
  );
  test(
    'external structural edits disengage automation without discarding metadata',
    () {
      var text = SmartTableEdits.calculatedColumn(
        source,
        parser.findTables(source).single,
        1,
        2,
      ).text;
      text = text.replaceFirst('| Qty |', '| External name |');
      final table = parser.findTables(text).single;
      final meta = SmartTableMetadata.read(text, table);
      expect(meta.editable, false);
      final changed = SmartTableEdits.structure(
        text,
        table,
        rows: true,
        index: 2,
        delete: false,
      ).text;
      expect(changed, contains(meta.opaque));
      expect(parser.findTables(changed).single.getCell(2, 2)!.trimmedText, '');
    },
  );
  test(
    'summary overrides persist while other summary cells keep automation',
    () {
      var text = SmartTableEdits.summary(
        source,
        parser.findTables(source).single,
        2,
        'SUM',
      ).text;
      text = SmartTableEdits.summary(
        text,
        parser.findTables(text).single,
        0,
        'COUNT',
      ).text;
      text = SmartTableEdits.updateCell(
        text,
        parser.findTables(text).single,
        3,
        2,
        'Custom total',
      ).text;
      text = SmartTableEdits.structure(
        text,
        parser.findTables(text).single,
        rows: true,
        index: 3,
        delete: false,
      ).text;
      final t = parser.findTables(text).single;
      expect(t.getCell(4, 2)!.trimmedText, 'Custom total');
      expect(t.getCell(4, 0)!.trimmedText, '=COUNT(A2:A4)');
    },
  );
  test(
    'row/column moves and duplicates follow identity, format and anchors',
    () {
      var text = SmartTableEdits.format(
        source,
        parser.findTables(source).single,
        2,
        {'type': 'percent', 'digits': 1},
      ).text;
      text = SmartTableEdits.move(
        text,
        parser.findTables(text).single,
        rows: false,
        from: 2,
        to: 0,
      ).text;
      var t = parser.findTables(text).single;
      expect(t.getCell(1, 0)!.trimmedText, '=B2 * C2');
      expect(SmartTableMetadata.read(text, t).section('formats')['0'], {
        'type': 'percent',
        'digits': 1,
      });
      text = SmartTableEdits.move(text, t, rows: true, from: 1, to: 2).text;
      t = parser.findTables(text).single;
      expect(t.getCell(2, 0)!.trimmedText, '=B3 * C3');
      text = SmartTableEdits.duplicate(text, t, rows: true, index: 2).text;
      expect(
        parser.findTables(text).single.getCell(3, 0)!.trimmedText,
        '=B4 * C4',
      );
    },
  );
  test('mixed fence markers and comments do not create formula tables', () {
    final text =
        '````text\n~~~\n$source\n```\n$source\n````\n\n<!--\n$source\n-->\n\n$source';
    expect(parser.findTables(text).length, 1);
    expect(
      deserializeQuietMarkdown(text).whereType<TableBlockNode>().length,
      1,
    );
  });
  test('large table caching and bounded aggregate computation', () {
    final rows = [
      ['Number', 'Total'],
      ...List.generate(3000, (i) => ['${i + 1}', '=A${i + 2}*2']),
    ];
    final watch = Stopwatch()..start();
    final engine = FormulaEngine(rows);
    for (var r = 1; r < rows.length; r++) {
      expect(engine.value(r, 1).display, '${r * 2}');
    }
    rows[1][0] = '5';
    engine.update(rows);
    expect(engine.value(1, 1).display, '10');
    expect(engine.value(3000, 1).display, '6000');
    watch.stop();
    // A generous bound catches accidental document-size work for every cell.
    expect(watch.elapsedMilliseconds, lessThan(10000));
    final costly = FormulaEngine([
      ['N', 'T'],
      ...List.generate(400, (i) => ['1', '=SUM(A2:A401)']),
    ]);
    var limited = false;
    for (var r = 1; r <= 400; r++) {
      limited = costly.value(r, 1).display == '#LIMIT!' || limited;
    }
    expect(limited, true);
  });
  test('bulk paste preserves surrounding text and summary stays last', () {
    var text =
        'Before\n\n${SmartTableEdits.summary(source, parser.findTables(source).single, 2, 'SUM').text}\n\nAfter';
    final t = parser.findTables(text).single;
    text = SmartTableEdits.paste(
      text,
      t,
      const TablePosition(row: 2, column: 0),
      [
        ['4', '50', '=A3*B3'],
        ['5', '10', '=A4*B4'],
      ],
    ).text;
    final result = parser.findTables(text).single;
    expect(result.rowCount, 5);
    expect(result.getCell(4, 2)!.trimmedText, '=SUM(C2:C4)');
    expect(FormulaEngine(tableRawCells(result)).value(4, 2).display, '500');
    expect(text, startsWith('Before\n\n'));
    expect(text, endsWith('\n\nAfter'));
  });
  test('oversized paste is rejected without mutation or history entries', () {
    var value = const TextEditingValue(text: source);
    final c = MarkdownTableController(
      table: parser.findTables(source).single,
      getDocumentValue: () => value,
      onUpdateDocument: (v) => value = v,
    );
    c.pasteCells(List.generate(4000, (_) => ['1', '2', '3']));
    expect(value.text, source);
    expect(c.canUndo, false);
    expect(c.operationError, '#LIMIT!');
    c.dispose();
  });
}
