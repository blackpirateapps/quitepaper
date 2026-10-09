import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/table_clipboard_parser.dart';

void main() {
  group('TableClipboardParser.parse', () {
    test('parses TSV into rows of cells', () {
      expect(
        TableClipboardParser.parse('a\tb\tc\n1\t2\t3'),
        <List<String>>[
          <String>['a', 'b', 'c'],
          <String>['1', '2', '3'],
        ],
      );
    });

    test('parses simple CSV', () {
      expect(
        TableClipboardParser.parse('a,b\n1,2'),
        <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      );
    });

    test('keeps commas embedded in a quoted field', () {
      expect(
        TableClipboardParser.parse('x,"a,b",y'),
        <List<String>>[
          <String>['x', 'a,b', 'y'],
        ],
      );
    });

    test('unescapes doubled quotes inside a quoted field', () {
      expect(
        TableClipboardParser.parse('"he said ""hi"""'),
        <List<String>>[
          <String>['he said "hi"'],
        ],
      );
    });

    test('keeps a newline embedded in a quoted field as one cell/row', () {
      expect(
        TableClipboardParser.parse('"a\nb",c'),
        <List<String>>[
          <String>['a\nb', 'c'],
        ],
      );
    });

    test('handles \\r\\n line endings', () {
      expect(
        TableClipboardParser.parse('a,b\r\n1,2'),
        <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      );
    });

    test('handles bare \\r line endings', () {
      expect(
        TableClipboardParser.parse('a,b\r1,2'),
        <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      );
    });

    test('returns an empty list for an empty string', () {
      expect(TableClipboardParser.parse(''), <List<String>>[]);
    });

    test('returns an empty list for blank input', () {
      expect(TableClipboardParser.parse('   \n  '), <List<String>>[]);
    });

    test('does not add an empty row for a trailing newline (CSV)', () {
      expect(
        TableClipboardParser.parse('a,b\n1,2\n'),
        <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      );
    });

    test('does not add an empty row for a trailing newline (TSV)', () {
      expect(
        TableClipboardParser.parse('a\tb\n1\t2\n'),
        <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      );
    });

    test('parses a single value with no delimiter', () {
      expect(
        TableClipboardParser.parse('value'),
        <List<String>>[
          <String>['value'],
        ],
      );
    });

    test('preserves intentionally empty trailing cells', () {
      expect(
        TableClipboardParser.parse('a,'),
        <List<String>>[
          <String>['a', ''],
        ],
      );
    });
  });
}
