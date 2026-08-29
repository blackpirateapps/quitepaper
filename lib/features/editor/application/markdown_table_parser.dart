import '../domain/markdown_table.dart';
import '../domain/markdown_table_alignment.dart';
import '../domain/markdown_table_cell.dart';
import '../domain/markdown_table_row.dart';

/// Deterministic, high-performance Markdown table parser.
/// Parses GitHub-Flavored Markdown table syntax with exact source offset mappings,
/// escaped pipe support, inline code protection, and code-fence safety.
class MarkdownTableParser {
  const MarkdownTableParser();

  static final _codeFenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');
  static final _delimiterCellRegex = RegExp(r'^\s*:?-{1,}:?\s*$');

  /// Scans the entire [text] and returns all valid, non-code-fenced [MarkdownTable]s.
  List<MarkdownTable> findTables(String text) {
    if (text.isEmpty) return const [];

    final tables = <MarkdownTable>[];
    final lines = _splitLinesWithOffsets(text);
    if (lines.length < 2) return const [];

    var inCodeBlock = false;
    var i = 0;

    while (i < lines.length) {
      final lineInfo = lines[i];
      final lineText = lineInfo.text;

      // 1. Fenced code block boundary check
      if (_codeFenceRegex.hasMatch(lineText)) {
        inCodeBlock = !inCodeBlock;
        i++;
        continue;
      }

      if (inCodeBlock) {
        i++;
        continue;
      }

      // 2. Table detection: Check if lineInfo (header) followed by lines[i + 1] (delimiter) forms a table
      if (i + 1 < lines.length && _isPotentialTableRow(lineText)) {
        final nextLineInfo = lines[i + 1];
        final nextLineText = nextLineInfo.text;

        if (_isValidDelimiterRow(nextLineText)) {
          // Parse header row
          final headerCells = _parseRowCells(
            lineText: lineText,
            lineStart: lineInfo.start,
            rowIndex: 0,
          );

          // Parse delimiter row
          final delimiterCells = _parseRowCells(
            lineText: nextLineText,
            lineStart: nextLineInfo.start,
            rowIndex: -1,
            isDelimiter: true,
          );

          final columnCount = delimiterCells.length;

          if (columnCount > 0) {
            // Adjust header cells count if needed
            final normalizedHeaderCells = _normalizeCellCount(
              cells: headerCells,
              targetCount: columnCount,
              rowIndex: 0,
              lineEnd: lineInfo.end,
            );

            final alignments = delimiterCells.map((c) => _parseAlignment(c.rawText)).toList();

            final headerRow = MarkdownTableRow(
              rowIndex: 0,
              isHeader: true,
              isDelimiter: false,
              cells: normalizedHeaderCells,
              sourceStart: lineInfo.start,
              sourceEnd: lineInfo.end,
              rawLine: lineText,
            );

            final delimiterRow = MarkdownTableRow(
              rowIndex: -1,
              isHeader: false,
              isDelimiter: true,
              cells: delimiterCells,
              sourceStart: nextLineInfo.start,
              sourceEnd: nextLineInfo.end,
              rawLine: nextLineText,
            );

            // Scan subsequent body rows
            final bodyRows = <MarkdownTableRow>[];
            var currentLineIndex = i + 2;
            var tableEndOffset = nextLineInfo.end;

            while (currentLineIndex < lines.length) {
              final bodyLineInfo = lines[currentLineIndex];
              final bodyLineText = bodyLineInfo.text;

              // Break table on blank line, code fence, or non-table line
              if (bodyLineText.trim().isEmpty ||
                  _codeFenceRegex.hasMatch(bodyLineText) ||
                  !_isPotentialTableRow(bodyLineText)) {
                break;
              }

              final bodyCells = _parseRowCells(
                lineText: bodyLineText,
                lineStart: bodyLineInfo.start,
                rowIndex: bodyRows.length + 1,
              );

              final normalizedBodyCells = _normalizeCellCount(
                cells: bodyCells,
                targetCount: columnCount,
                rowIndex: bodyRows.length + 1,
                lineEnd: bodyLineInfo.end,
              );

              bodyRows.add(MarkdownTableRow(
                rowIndex: bodyRows.length + 1,
                isHeader: false,
                isDelimiter: false,
                cells: normalizedBodyCells,
                sourceStart: bodyLineInfo.start,
                sourceEnd: bodyLineInfo.end,
                rawLine: bodyLineText,
              ));

              tableEndOffset = bodyLineInfo.end;
              currentLineIndex++;
            }

            tables.add(MarkdownTable(
              sourceStart: lineInfo.start,
              sourceEnd: tableEndOffset,
              headerRow: headerRow,
              delimiterRow: delimiterRow,
              bodyRows: bodyRows,
              alignments: alignments,
              columnCount: columnCount,
            ));

            i = currentLineIndex;
            continue;
          }
        }
      }

      i++;
    }

    return tables;
  }

  /// Locates the [MarkdownTable] spanning the given source [offset], if any.
  MarkdownTable? findTableAtOffset(String text, int offset) {
    final tables = findTables(text);
    for (final table in tables) {
      if (table.containsOffset(offset)) {
        return table;
      }
    }
    return null;
  }

  /// Parses a single standalone Markdown table block.
  MarkdownTable? parseSingleTable(String tableMarkdown, {int baseOffset = 0}) {
    final tables = findTables(tableMarkdown);
    if (tables.isEmpty) return null;
    final t = tables.first;
    if (baseOffset == 0) return t;

    // Shift offsets by baseOffset if non-zero
    return MarkdownTable(
      sourceStart: t.sourceStart + baseOffset,
      sourceEnd: t.sourceEnd + baseOffset,
      headerRow: _shiftRow(t.headerRow, baseOffset),
      delimiterRow: _shiftRow(t.delimiterRow, baseOffset),
      bodyRows: t.bodyRows.map((r) => _shiftRow(r, baseOffset)).toList(),
      alignments: t.alignments,
      columnCount: t.columnCount,
    );
  }

  MarkdownTableRow _shiftRow(MarkdownTableRow row, int offset) {
    return MarkdownTableRow(
      rowIndex: row.rowIndex,
      isHeader: row.isHeader,
      isDelimiter: row.isDelimiter,
      cells: row.cells.map((c) => _shiftCell(c, offset)).toList(),
      sourceStart: row.sourceStart + offset,
      sourceEnd: row.sourceEnd + offset,
      rawLine: row.rawLine,
    );
  }

  MarkdownTableCell _shiftCell(MarkdownTableCell cell, int offset) {
    return MarkdownTableCell(
      rowIndex: cell.rowIndex,
      columnIndex: cell.columnIndex,
      rawText: cell.rawText,
      sourceStart: cell.sourceStart + offset,
      sourceEnd: cell.sourceEnd + offset,
      contentStart: cell.contentStart + offset,
      contentEnd: cell.contentEnd + offset,
    );
  }

  /// Whether a line contains structural pipe characteristics to potentially be a table row.
  bool _isPotentialTableRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    // Must contain at least one pipe '|'
    return trimmed.contains('|');
  }

  /// Checks whether a line satisfies GFM delimiter row requirements (`|:---|:---:|---:|`).
  bool _isValidDelimiterRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    final cells = _extractRawCellSlices(line);
    if (cells.isEmpty) return false;

    return cells.every((c) => _delimiterCellRegex.hasMatch(c.text));
  }

  /// Extracts cell boundaries and text slices from a row line, correctly ignoring
  /// escaped pipes (`\|`) and pipes inside inline code (`` `a|b` ``).
  List<_CellSlice> _extractRawCellSlices(String line) {
    final slices = <_CellSlice>[];
    final len = line.length;
    final structuralPipeIndices = <int>[];

    var i = 0;
    while (i < len) {
      final char = line[i];

      // Escaped character: \c
      if (char == '\\' && i + 1 < len) {
        i += 2;
        continue;
      }

      // Inline code block: `code` or ``code``
      if (char == '`') {
        var backtickCount = 0;
        while (i + backtickCount < len && line[i + backtickCount] == '`') {
          backtickCount++;
        }
        final delimiter = '`' * backtickCount;
        final closeIdx = line.indexOf(delimiter, i + backtickCount);
        if (closeIdx != -1) {
          i = closeIdx + backtickCount;
          continue;
        } else {
          i += backtickCount;
          continue;
        }
      }

      if (char == '|') {
        structuralPipeIndices.add(i);
      }

      i++;
    }

    if (structuralPipeIndices.isEmpty) {
      return const [];
    }

    final hasLeadingPipe = structuralPipeIndices.first == 0 ||
        line.substring(0, structuralPipeIndices.first).trim().isEmpty;
    final hasTrailingPipe = structuralPipeIndices.last == len - 1 ||
        line.substring(structuralPipeIndices.last + 1).trim().isEmpty;

    final segmentStarts = <int>[];
    final segmentEnds = <int>[];

    if (!hasLeadingPipe) {
      segmentStarts.add(0);
      segmentEnds.add(structuralPipeIndices.first);
    }

    for (var k = 0; k < structuralPipeIndices.length - 1; k++) {
      segmentStarts.add(structuralPipeIndices[k] + 1);
      segmentEnds.add(structuralPipeIndices[k + 1]);
    }

    if (!hasTrailingPipe) {
      segmentStarts.add(structuralPipeIndices.last + 1);
      segmentEnds.add(len);
    }

    for (var s = 0; s < segmentStarts.length; s++) {
      final start = segmentStarts[s];
      final end = segmentEnds[s];
      if (end >= start) {
        slices.add(_CellSlice(
          start: start,
          end: end,
          text: line.substring(start, end),
        ));
      }
    }

    return slices;
  }

  /// Parses row cells with exact source offsets.
  List<MarkdownTableCell> _parseRowCells({
    required String lineText,
    required int lineStart,
    required int rowIndex,
    bool isDelimiter = false,
  }) {
    final slices = _extractRawCellSlices(lineText);
    final cells = <MarkdownTableCell>[];

    for (var col = 0; col < slices.length; col++) {
      final slice = slices[col];
      final sliceText = slice.text;

      // Compute trimmed content bounds within the slice
      var leadingWhitespace = 0;
      while (leadingWhitespace < sliceText.length &&
          (sliceText[leadingWhitespace] == ' ' || sliceText[leadingWhitespace] == '\t')) {
        leadingWhitespace++;
      }

      var trailingWhitespace = 0;
      while (trailingWhitespace < (sliceText.length - leadingWhitespace) &&
          (sliceText[sliceText.length - 1 - trailingWhitespace] == ' ' ||
              sliceText[sliceText.length - 1 - trailingWhitespace] == '\t')) {
        trailingWhitespace++;
      }

      final contentStartRel = leadingWhitespace;
      final contentEndRel = sliceText.length - trailingWhitespace;

      final sourceStart = lineStart + slice.start;
      final sourceEnd = lineStart + slice.end;
      final contentStart = sourceStart + contentStartRel;
      final contentEnd = sourceStart + contentEndRel;

      cells.add(MarkdownTableCell(
        rowIndex: rowIndex,
        columnIndex: col,
        rawText: sliceText,
        sourceStart: sourceStart,
        sourceEnd: sourceEnd,
        contentStart: contentStart,
        contentEnd: contentEnd,
      ));
    }

    return cells;
  }

  /// Pads or clamps cells to match [targetCount].
  List<MarkdownTableCell> _normalizeCellCount({
    required List<MarkdownTableCell> cells,
    required int targetCount,
    required int rowIndex,
    required int lineEnd,
  }) {
    if (cells.length == targetCount) return cells;

    final result = List<MarkdownTableCell>.from(cells);
    if (result.length > targetCount) {
      return result.sublist(0, targetCount);
    }

    // Pad missing cells with empty slots
    while (result.length < targetCount) {
      final col = result.length;
      result.add(MarkdownTableCell(
        rowIndex: rowIndex,
        columnIndex: col,
        rawText: '',
        sourceStart: lineEnd,
        sourceEnd: lineEnd,
        contentStart: lineEnd,
        contentEnd: lineEnd,
      ));
    }

    return result;
  }

  /// Parses [MarkdownTableAlignment] from delimiter cell content.
  MarkdownTableAlignment _parseAlignment(String delimiterCell) {
    final trimmed = delimiterCell.trim();
    final startsWithColon = trimmed.startsWith(':');
    final endsWithColon = trimmed.endsWith(':');

    if (startsWithColon && endsWithColon) {
      return MarkdownTableAlignment.center;
    } else if (startsWithColon) {
      return MarkdownTableAlignment.left;
    } else if (endsWithColon) {
      return MarkdownTableAlignment.right;
    } else {
      return MarkdownTableAlignment.none;
    }
  }

  List<_LineInfo> _splitLinesWithOffsets(String text) {
    final result = <_LineInfo>[];
    var start = 0;
    while (start <= text.length) {
      final newline = text.indexOf('\n', start);
      if (newline == -1) {
        result.add(_LineInfo(start: start, end: text.length, text: text.substring(start)));
        break;
      } else {
        result.add(_LineInfo(start: start, end: newline, text: text.substring(start, newline)));
        start = newline + 1;
      }
    }
    return result;
  }
}

class _LineInfo {
  const _LineInfo({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

class _CellSlice {
  const _CellSlice({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}
