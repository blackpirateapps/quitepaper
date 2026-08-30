import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/text/attachment_csv_parser.dart';

void main() {
  group('AttachmentCsvParser Tests', () {
    test('parses basic comma-separated CSV with headers', () {
      final csvText = 'Item,Quantity,Price\nKeyboard,2,80\nMonitor,1,300\nMouse,3,25';

      final table = AttachmentCsvParser.parse(csvText);

      expect(table.hasHeaders, isTrue);
      expect(table.columnCount, 3);
      expect(table.rowCount, 3);
      expect(table.headers, ['Item', 'Quantity', 'Price']);
      expect(table.rows[0], ['Keyboard', '2', '80']);
      expect(table.rows[1], ['Monitor', '1', '300']);
      expect(table.rows[2], ['Mouse', '3', '25']);
    });

    test('parses TSV (tab-delimited) data correctly', () {
      final tsvText = 'ID\tName\tRole\n101\tAlice\tAdmin\n102\tBob\tEditor';

      final table = AttachmentCsvParser.parse(tsvText, delimiter: '\t');

      expect(table.columnCount, 3);
      expect(table.rowCount, 2);
      expect(table.headers, ['ID', 'Name', 'Role']);
      expect(table.rows[0], ['101', 'Alice', 'Admin']);
      expect(table.rows[1], ['102', 'Bob', 'Editor']);
    });

    test('handles quoted fields with commas inside quotes', () {
      final csvText = 'Name,Address,Notes\n"Smith, John","123 Main St, Apt 4","Customer, preferred"';

      final table = AttachmentCsvParser.parse(csvText);

      expect(table.columnCount, 3);
      expect(table.rowCount, 1);
      expect(table.headers, ['Name', 'Address', 'Notes']);
      expect(table.rows[0][0], 'Smith, John');
      expect(table.rows[0][1], '123 Main St, Apt 4');
      expect(table.rows[0][2], 'Customer, preferred');
    });

    test('handles escaped double quotes ("") properly', () {
      final csvText = 'Key,Value\nQuote,"He said ""Hello world"" to everyone"\nPlain,Simple';

      final table = AttachmentCsvParser.parse(csvText);

      expect(table.rowCount, 2);
      expect(table.rows[0][1], 'He said "Hello world" to everyone');
      expect(table.rows[1][1], 'Simple');
    });

    test('handles multiline fields with embedded newlines', () {
      final csvText = 'ID,Description\n1,"Line one\nLine two\nLine three"\n2,Single line';

      final table = AttachmentCsvParser.parse(csvText);

      expect(table.rowCount, 2);
      expect(table.rows[0][1], 'Line one\nLine two\nLine three');
      expect(table.rows[1][1], 'Single line');
    });

    test('handles empty cells and trailing delimiters safely', () {
      final csvText = 'A,B,C,D\n1,,,4\n,2,,';

      final table = AttachmentCsvParser.parse(csvText);

      expect(table.columnCount, 4);
      expect(table.rowCount, 2);
      expect(table.rows[0], ['1', '', '', '4']);
      expect(table.rows[1], ['', '2', '', '']);
    });

    test('normalizes inconsistent row lengths safely without crashing or losing data', () {
      // Row 1 has 2 items, Row 2 has 4 items, Row 3 has 1 item
      final csvText = 'Col1,Col2\nA,B,C,D\nSingle';

      final table = AttachmentCsvParser.parse(csvText);

      // Max columns is 4
      expect(table.columnCount, 4);
      expect(table.headers, ['Col1', 'Col2', '', '']);
      expect(table.rows[0], ['A', 'B', 'C', 'D']);
      expect(table.rows[1], ['Single', '', '', '']);
    });

    test('recovers safely from malformed CSV with unclosed quotes', () {
      final csvText = 'Col1,Col2\n"Unclosed quote without end,Value 2';

      expect(() => AttachmentCsvParser.parse(csvText), returnsNormally);

      final table = AttachmentCsvParser.parse(csvText);
      expect(table.isNotEmpty, isTrue);
    });

    test('converts CsvTableData to clean GitHub Flavored Markdown table', () {
      final table = CsvTableData(
        headers: ['Feature', 'Status', 'Cost'],
        rows: [
          ['OCR', 'Done', r'$0'],
          ['Sync', 'Active', r'$50|mo'],
          ['Multiline', 'A\nB', 'Normal'],
        ],
        columnCount: 3,
        rowCount: 3,
        hasHeaders: true,
      );

      final mdTable = AttachmentCsvParser.convertToMarkdownTable(table);

      // Verify header structure
      expect(mdTable.contains('| Feature | Status | Cost |'), isTrue);
      expect(mdTable.contains('| --- | --- | --- |'), isTrue);

      // Verify escaped pipe in cell
      expect(mdTable.contains(r'\|mo'), isTrue);

      // Verify multiline replacement
      expect(mdTable.contains('A<br>B'), isTrue);
    });

    test('handles empty CSV input cleanly', () {
      final empty = AttachmentCsvParser.parse('');
      expect(empty.isEmpty, isTrue);
      expect(empty.columnCount, 0);
      expect(empty.rowCount, 0);

      final md = AttachmentCsvParser.convertToMarkdownTable(empty);
      expect(md, '');
    });
  });
}
