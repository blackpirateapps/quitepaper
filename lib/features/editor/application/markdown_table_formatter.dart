import 'dart:math';
import 'package:flutter/services.dart';
import '../domain/markdown_table.dart';
import '../domain/markdown_table_alignment.dart';
import '../domain/markdown_table_row.dart';
import 'markdown_table_parser.dart';

/// Pure functional Markdown source transformations for tables.
/// Operates directly on [TextEditingValue] and strings to guarantee that
/// Markdown remains the single canonical source of truth.
abstract final class MarkdownTableFormatter {
  static const _parser = MarkdownTableParser();

  /// Escapes unescaped pipes `|` that do not appear inside inline code backticks.
  static String escapeCellContent(String text) {
    if (!text.contains('|')) return text;

    final sb = StringBuffer();
    final len = text.length;
    var i = 0;

    while (i < len) {
      final char = text[i];

      // Escaped character: \c
      if (char == '\\' && i + 1 < len) {
        sb.write(char);
        sb.write(text[i + 1]);
        i += 2;
        continue;
      }

      // Inline code block: `code` or ``code``
      if (char == '`') {
        var backtickCount = 0;
        while (i + backtickCount < len && text[i + backtickCount] == '`') {
          backtickCount++;
        }
        final delimiter = '`' * backtickCount;
        final closeIdx = text.indexOf(delimiter, i + backtickCount);
        if (closeIdx != -1) {
          sb.write(text.substring(i, closeIdx + backtickCount));
          i = closeIdx + backtickCount;
          continue;
        } else {
          sb.write(delimiter);
          i += backtickCount;
          continue;
        }
      }

      if (char == '|') {
        sb.write(r'\|');
      } else {
        sb.write(char);
      }

      i++;
    }

    return sb.toString();
  }

  /// Inserts a new Markdown table at the current cursor/selection.
  static TextEditingValue insertTable({
    required TextEditingValue value,
    int rows = 3,
    int columns = 3,
  }) {
    final text = value.text;
    final selection = value.selection;

    final effectiveRows = rows.clamp(1, 50);
    final effectiveCols = columns.clamp(1, 20);

    // Build header row
    final headerCells = List.generate(effectiveCols, (c) => ' Header ${c + 1} ');
    final headerLine = '|${headerCells.join('|')}|';

    // Build delimiter row
    final delimiterCells = List.generate(effectiveCols, (_) => ' --- ');
    final delimiterLine = '|${delimiterCells.join('|')}|';

    // Build body rows
    final bodyLines = <String>[];
    for (var r = 0; r < effectiveRows; r++) {
      final cells = List.generate(effectiveCols, (_) => '  ');
      bodyLines.add('|${cells.join('|')}|');
    }

    final tableLines = [headerLine, delimiterLine, ...bodyLines];
    final tableMarkdown = tableLines.join('\n');

    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final minOffset = min(start, end);
    final maxOffset = max(start, end);

    // Determine clean block boundaries
    var prefix = '';
    if (minOffset > 0 && !text.substring(0, minOffset).endsWith('\n\n')) {
      if (text.substring(0, minOffset).endsWith('\n')) {
        prefix = '\n';
      } else {
        prefix = '\n\n';
      }
    }

    var suffix = '';
    if (maxOffset < text.length && !text.substring(maxOffset).startsWith('\n\n')) {
      if (text.substring(maxOffset).startsWith('\n')) {
        suffix = '\n';
      } else {
        suffix = '\n\n';
      }
    }

    final insertion = '$prefix$tableMarkdown$suffix';
    final newText = text.replaceRange(minOffset, maxOffset, insertion);

    // Calculate cursor position inside first header cell
    final firstCellOffset = minOffset + prefix.length + 2; // "| "

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: firstCellOffset),
    );
  }

  /// Updates the content of a single cell at [row] and [column].
  static TextEditingValue updateCell({
    required TextEditingValue value,
    required MarkdownTable table,
    required int row,
    required int column,
    required String newCellText,
  }) {
    final cell = table.getCell(row, column);
    if (cell == null) return value;

    final text = value.text;
    final escapedContent = escapeCellContent(newCellText);

    // If cell currently has content
    int replaceStart;
    int replaceEnd;

    if (cell.contentStart < cell.contentEnd) {
      replaceStart = cell.contentStart;
      replaceEnd = cell.contentEnd;
    } else {
      // Cell was empty, replace at contentStart
      replaceStart = cell.contentStart;
      replaceEnd = cell.contentStart;
    }

    final newText = text.replaceRange(replaceStart, replaceEnd, escapedContent);
    final newCursor = replaceStart + escapedContent.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Adds a new row below [afterRowIndex] (or at bottom if [afterRowIndex] is rowCount - 1).
  static TextEditingValue addRow({
    required TextEditingValue value,
    required MarkdownTable table,
    required int afterRowIndex,
  }) {
    final text = value.text;
    final colCount = table.columnCount;
    final newRowCells = List.generate(colCount, (_) => '  ');
    final newRowLine = '|${newRowCells.join('|')}|';

    int insertOffset;
    if (afterRowIndex <= 0) {
      // After header + delimiter row
      insertOffset = table.delimiterRow.sourceEnd;
    } else {
      final bodyIdx = (afterRowIndex - 1).clamp(0, table.bodyRows.length - 1);
      insertOffset = table.bodyRows[bodyIdx].sourceEnd;
    }

    final insertion = '\n$newRowLine';
    final newText = text.replaceRange(insertOffset, insertOffset, insertion);

    // Position cursor in the first cell of the newly added row
    final newCellOffset = insertOffset + 1 + 2; // "\n| "

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCellOffset),
    );
  }

  /// Deletes the row at [rowIndex].
  static TextEditingValue deleteRow({
    required TextEditingValue value,
    required MarkdownTable table,
    required int rowIndex,
  }) {
    // Disallow deleting header row via ordinary delete row (protect header invariant)
    if (rowIndex <= 0 || table.bodyRows.isEmpty) {
      return value;
    }

    final text = value.text;
    final bodyIdx = rowIndex - 1;
    if (bodyIdx < 0 || bodyIdx >= table.bodyRows.length) {
      return value;
    }

    final targetRow = table.bodyRows[bodyIdx];
    var startOffset = targetRow.sourceStart;
    var endOffset = targetRow.sourceEnd;

    // Check if there is a preceding newline to remove
    if (startOffset > 0 && text[startOffset - 1] == '\n') {
      startOffset -= 1;
    } else if (endOffset < text.length && text[endOffset] == '\n') {
      endOffset += 1;
    }

    final newText = text.replaceRange(startOffset, endOffset, '');

    // Move cursor to surviving row
    final survivingRowIndex = (rowIndex - 1).clamp(0, table.rowCount - 2);
    final reloadedTable = _parser.findTableAtOffset(newText, startOffset > 0 ? startOffset - 1 : 0);
    final survivingCell = reloadedTable?.getCell(survivingRowIndex, 0);
    final newCursor = survivingCell?.contentStart ?? (startOffset.clamp(0, newText.length));

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Adds a new column after [afterColumnIndex] (or at rightmost end).
  static TextEditingValue addColumn({
    required TextEditingValue value,
    required MarkdownTable table,
    required int afterColumnIndex,
  }) {
    final text = value.text;

    // Reconstruct each row of the table
    final allRows = <MarkdownTableRow>[
      table.headerRow,
      table.delimiterRow,
      ...table.bodyRows,
    ];

    final updatedLines = <String>[];
    final insertCol = (afterColumnIndex + 1).clamp(0, table.columnCount);

    for (final row in allRows) {
      final cells = List<String>.from(row.cells.map((c) => c.rawText));
      if (row.isHeader) {
        cells.insert(insertCol, ' Header ${table.columnCount + 1} ');
      } else if (row.isDelimiter) {
        cells.insert(insertCol, ' --- ');
      } else {
        cells.insert(insertCol, '  ');
      }
      updatedLines.add('|${cells.join('|')}|');
    }

    final newTableMarkdown = updatedLines.join('\n');
    final newText = text.replaceRange(table.sourceStart, table.sourceEnd, newTableMarkdown);

    final reloadedTable = _parser.findTableAtOffset(newText, table.sourceStart);
    final targetCell = reloadedTable?.getCell(0, insertCol);
    final newCursor = targetCell?.contentStart ?? table.sourceStart;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Deletes the column at [columnIndex].
  static TextEditingValue deleteColumn({
    required TextEditingValue value,
    required MarkdownTable table,
    required int columnIndex,
  }) {
    // Invariant: Prevent deleting the final column
    if (table.columnCount <= 1) {
      return value;
    }

    if (columnIndex < 0 || columnIndex >= table.columnCount) {
      return value;
    }

    final text = value.text;
    final allRows = <MarkdownTableRow>[
      table.headerRow,
      table.delimiterRow,
      ...table.bodyRows,
    ];

    final updatedLines = <String>[];
    for (final row in allRows) {
      final cells = List<String>.from(row.cells.map((c) => c.rawText));
      if (columnIndex < cells.length) {
        cells.removeAt(columnIndex);
      }
      updatedLines.add('|${cells.join('|')}|');
    }

    final newTableMarkdown = updatedLines.join('\n');
    final newText = text.replaceRange(table.sourceStart, table.sourceEnd, newTableMarkdown);

    final survivingCol = min(columnIndex, table.columnCount - 2);
    final reloadedTable = _parser.findTableAtOffset(newText, table.sourceStart);
    final targetCell = reloadedTable?.getCell(0, survivingCol);
    final newCursor = targetCell?.contentStart ?? table.sourceStart;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Sets the alignment for column [columnIndex].
  static TextEditingValue setColumnAlignment({
    required TextEditingValue value,
    required MarkdownTable table,
    required int columnIndex,
    required MarkdownTableAlignment alignment,
  }) {
    if (columnIndex < 0 || columnIndex >= table.columnCount) {
      return value;
    }

    final delimCell = table.delimiterRow.cells[columnIndex];
    final delimString = alignment.toDelimiterString(minWidth: delimCell.rawText.trim().length);

    final text = value.text;
    final newText = text.replaceRange(delimCell.contentStart, delimCell.contentEnd, delimString);

    return TextEditingValue(
      text: newText,
      selection: value.selection,
    );
  }

  /// Deletes the entire table Markdown block atomically.
  static TextEditingValue deleteTable({
    required TextEditingValue value,
    required MarkdownTable table,
  }) {
    final text = value.text;
    var startOffset = table.sourceStart;
    var endOffset = table.sourceEnd;

    // Clean up surrounding newline if appropriate
    if (startOffset > 0 && text[startOffset - 1] == '\n') {
      startOffset -= 1;
    } else if (endOffset < text.length && text[endOffset] == '\n') {
      endOffset += 1;
    }

    final newText = text.replaceRange(startOffset, endOffset, '');
    final newCursor = startOffset.clamp(0, newText.length);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
