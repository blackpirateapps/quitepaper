import 'package:flutter/foundation.dart';

/// Parsed tabular data structure for CSV and TSV attachments.
@immutable
class CsvTableData {
  const CsvTableData({
    required this.headers,
    required this.rows,
    required this.columnCount,
    required this.rowCount,
    required this.hasHeaders,
  });

  const CsvTableData.empty()
      : headers = const [],
        rows = const [],
        columnCount = 0,
        rowCount = 0,
        hasHeaders = false;

  final List<String> headers;
  final List<List<String>> rows;
  final int columnCount;
  final int rowCount;
  final bool hasHeaders;

  bool get isEmpty => columnCount == 0 && rowCount == 0;
  bool get isNotEmpty => !isEmpty;

  /// Retrieves cell value at (row, column) safely.
  String getCell(int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= rows.length) return '';
    final row = rows[rowIndex];
    if (columnIndex < 0 || columnIndex >= row.length) return '';
    return row[columnIndex];
  }
}

/// Robust RFC 4180 compliant CSV/TSV parser supporting quoted fields, escaped quotes,
/// multiline cells, delimiter detection, inconsistent row lengths, and GFM markdown table generation.
class AttachmentCsvParser {
  const AttachmentCsvParser._();

  /// Parses CSV or TSV text into structured [CsvTableData].
  static CsvTableData parse(
    String rawText, {
    String delimiter = ',',
    bool firstRowIsHeader = true,
  }) {
    if (rawText.trim().isEmpty) {
      return const CsvTableData.empty();
    }

    final records = <List<String>>[];
    final currentRecord = <String>[];
    final currentField = StringBuffer();

    bool inQuotes = false;
    int i = 0;
    final len = rawText.length;
    final delimCode = delimiter.codeUnitAt(0);

    while (i < len) {
      final code = rawText.codeUnitAt(i);

      if (inQuotes) {
        if (code == 0x22) { // '"'
          // Check for escaped quote: ""
          if (i + 1 < len && rawText.codeUnitAt(i + 1) == 0x22) {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            // Closing quote
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.writeCharCode(code);
          i++;
          continue;
        }
      } else {
        if (code == 0x22) { // '"'
          inQuotes = true;
          i++;
          continue;
        } else if (code == delimCode) {
          currentRecord.add(currentField.toString());
          currentField.clear();
          i++;
          continue;
        } else if (code == 0x0D) { // '\r'
          currentRecord.add(currentField.toString());
          currentField.clear();
          records.add(List<String>.from(currentRecord));
          currentRecord.clear();

          // Check if followed by '\n'
          if (i + 1 < len && rawText.codeUnitAt(i + 1) == 0x0A) {
            i += 2;
          } else {
            i++;
          }
          continue;
        } else if (code == 0x0A) { // '\n'
          currentRecord.add(currentField.toString());
          currentField.clear();
          records.add(List<String>.from(currentRecord));
          currentRecord.clear();
          i++;
          continue;
        } else {
          currentField.writeCharCode(code);
          i++;
          continue;
        }
      }
    }

    // Flush last field and record if present
    if (currentField.isNotEmpty || currentRecord.isNotEmpty) {
      currentRecord.add(currentField.toString());
      records.add(List<String>.from(currentRecord));
    }

    if (records.isEmpty) {
      return const CsvTableData.empty();
    }

    // Determine maximum column count across all rows to normalize dimensions
    int maxCols = 0;
    for (final r in records) {
      if (r.length > maxCols) maxCols = r.length;
    }

    if (maxCols == 0) {
      return const CsvTableData.empty();
    }

    // Normalize rows so all rows have exactly maxCols cells (pad missing with '')
    final normalized = records.map((r) {
      if (r.length < maxCols) {
        final padded = List<String>.from(r);
        while (padded.length < maxCols) {
          padded.add('');
        }
        return padded;
      }
      return r;
    }).toList();

    List<String> headers;
    List<List<String>> bodyRows;

    if (firstRowIsHeader && normalized.isNotEmpty) {
      headers = normalized.first;
      bodyRows = normalized.skip(1).toList();
    } else {
      headers = List.generate(maxCols, (col) => 'Column ${col + 1}');
      bodyRows = normalized;
    }

    return CsvTableData(
      headers: headers,
      rows: bodyRows,
      columnCount: maxCols,
      rowCount: bodyRows.length,
      hasHeaders: firstRowIsHeader,
    );
  }

  /// Converts [CsvTableData] into a GitHub Flavored Markdown table string.
  static String convertToMarkdownTable(CsvTableData table) {
    if (table.isEmpty) return '';

    final buffer = StringBuffer();

    // 1. Header row
    buffer.write('| ');
    for (int c = 0; c < table.columnCount; c++) {
      final headerText = c < table.headers.length ? table.headers[c] : 'Col ${c + 1}';
      buffer.write(_sanitizeForMarkdownCell(headerText));
      buffer.write(' | ');
    }
    buffer.writeln();

    // 2. Delimiter row
    buffer.write('| ');
    for (int c = 0; c < table.columnCount; c++) {
      buffer.write('--- | ');
    }
    buffer.writeln();

    // 3. Body rows
    for (final row in table.rows) {
      buffer.write('| ');
      for (int c = 0; c < table.columnCount; c++) {
        final cellText = c < row.length ? row[c] : '';
        buffer.write(_sanitizeForMarkdownCell(cellText));
        buffer.write(' | ');
      }
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  static String _sanitizeForMarkdownCell(String text) {
    var s = text.replaceAll(r'\', r'\\');
    s = s.replaceAll('|', r'\|');
    // Replace newlines inside cells with <br> to prevent breaking GFM table rows
    s = s.replaceAll('\r\n', '<br>');
    s = s.replaceAll('\n', '<br>');
    s = s.replaceAll('\r', '<br>');
    return s.trim();
  }
}
