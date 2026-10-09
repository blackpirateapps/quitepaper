/// Parses clipboard text pasted by the user into a rectangular grid of cell
/// strings, for filling a Markdown table.
abstract final class TableClipboardParser {
  /// Parses [text] into rows of cells.
  ///
  /// Detection: if any line contains a TAB character, the text is treated as
  /// TSV (split each line on '\t', no quoting). Otherwise it is treated as CSV
  /// following RFC-4180: fields separated by ',', a field may be wrapped in
  /// double quotes, "" inside a quoted field is a literal quote, and a quoted
  /// field may contain commas and newlines.
  ///
  /// Trailing empty line(s) are dropped. Returns an empty list for empty/blank
  /// input. Rows are NOT padded to equal length — the caller decides how to fit
  /// them into a table.
  static List<List<String>> parse(String text) {
    if (text.trim().isEmpty) return <List<String>>[];

    // A TAB anywhere means tab-separated values; otherwise parse as CSV.
    if (text.contains('\t')) return _parseTsv(text);
    return _parseCsv(text);
  }

  /// Simple per-line TSV parsing with no quoting rules.
  static List<List<String>> _parseTsv(String text) {
    final lines = text.split(RegExp(r'\r\n|\r|\n'));

    // Drop trailing empty line(s), e.g. from a terminating newline.
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    return lines.map((line) => line.split('\t')).toList();
  }

  /// RFC-4180 CSV state machine supporting quoted fields, escaped `""`, and
  /// embedded commas / newlines inside quotes. Accepts \r\n, \r and \n line
  /// endings between records.
  static List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    final length = text.length;
    var i = 0;

    while (i < length) {
      final char = text[i];

      if (inQuotes) {
        if (char == '"') {
          // An escaped quote ("") emits a single literal quote.
          if (i + 1 < length && text[i + 1] == '"') {
            field.write('"');
            i += 2;
          } else {
            inQuotes = false;
            i++;
          }
        } else {
          field.write(char);
          i++;
        }
        continue;
      }

      if (char == '"') {
        inQuotes = true;
        i++;
      } else if (char == ',') {
        row.add(field.toString());
        field.clear();
        i++;
      } else if (char == '\n' || char == '\r') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        // Consume \r\n as a single line ending.
        if (char == '\r' && i + 1 < length && text[i + 1] == '\n') {
          i += 2;
        } else {
          i++;
        }
      } else {
        field.write(char);
        i++;
      }
    }

    // Flush the final field and row.
    row.add(field.toString());
    rows.add(row);

    // Drop trailing empty row(s) produced by a terminating newline.
    while (rows.isNotEmpty &&
        rows.last.length == 1 &&
        rows.last.first.isEmpty) {
      rows.removeLast();
    }

    return rows;
  }
}
