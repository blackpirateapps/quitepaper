import 'package:flutter/foundation.dart';
import 'markdown_table_alignment.dart';
import 'markdown_table_cell.dart';
import 'markdown_table_position.dart';
import 'markdown_table_row.dart';

/// Immutable model representing a parsed GitHub-Flavored Markdown table.
/// Acts as a temporary projection mapping 2D grid coordinates to exact source Markdown offsets.
@immutable
class MarkdownTable {
  const MarkdownTable({
    required this.sourceStart,
    required this.sourceEnd,
    required this.headerRow,
    required this.delimiterRow,
    required this.bodyRows,
    required this.alignments,
    required this.columnCount,
  });

  /// Absolute start offset of the table in the canonical Markdown document.
  final int sourceStart;

  /// Absolute end offset of the table in the canonical Markdown document.
  final int sourceEnd;

  /// The table's header row (row index 0).
  final MarkdownTableRow headerRow;

  /// The table's delimiter/alignment row.
  final MarkdownTableRow delimiterRow;

  /// The table's body rows (row indices 1..N).
  final List<MarkdownTableRow> bodyRows;

  /// Column alignments parsed from the delimiter row.
  final List<MarkdownTableAlignment> alignments;

  /// Total number of columns.
  final int columnCount;

  /// Total number of visible rows (header + body rows).
  int get rowCount => 1 + bodyRows.length;

  /// All visible rows (header row at index 0, followed by body rows).
  List<MarkdownTableRow> get allVisibleRows => [headerRow, ...bodyRows];

  /// Retrieves the cell at the specified [row] (0 = header, 1+ = body) and [column].
  MarkdownTableCell? getCell(int row, int column) {
    if (row < 0 || row >= rowCount) return null;
    if (column < 0 || column >= columnCount) return null;

    if (row == 0) {
      if (column < headerRow.cells.length) {
        return headerRow.cells[column];
      }
      return null;
    }

    final bodyIndex = row - 1;
    if (bodyIndex < bodyRows.length) {
      final bodyRow = bodyRows[bodyIndex];
      if (column < bodyRow.cells.length) {
        return bodyRow.cells[column];
      }
    }
    return null;
  }

  /// Returns the alignment for the specified [column].
  MarkdownTableAlignment getAlignment(int column) {
    if (column >= 0 && column < alignments.length) {
      return alignments[column];
    }
    return MarkdownTableAlignment.none;
  }

  /// Locates the grid position corresponding to a given source Markdown character [offset].
  TablePosition? findPositionAtSourceOffset(int offset) {
    if (offset < sourceStart || offset > sourceEnd) return null;

    // Check header row
    for (final cell in headerRow.cells) {
      if (offset >= cell.sourceStart && offset <= cell.sourceEnd) {
        return TablePosition(row: 0, column: cell.columnIndex);
      }
    }

    // Check body rows
    for (var r = 0; r < bodyRows.length; r++) {
      final row = bodyRows[r];
      for (final cell in row.cells) {
        if (offset >= cell.sourceStart && offset <= cell.sourceEnd) {
          return TablePosition(row: r + 1, column: cell.columnIndex);
        }
      }
    }

    return null;
  }

  /// Locates the [MarkdownTableCell] corresponding to a given source Markdown character [offset].
  MarkdownTableCell? findCellAtSourceOffset(int offset) {
    final pos = findPositionAtSourceOffset(offset);
    if (pos == null) return null;
    return getCell(pos.row, pos.column);
  }

  /// Whether the table spans the given source [offset].
  bool containsOffset(int offset) => offset >= sourceStart && offset <= sourceEnd;

  @override
  String toString() =>
      'MarkdownTable(cols: $columnCount, rows: $rowCount, [$sourceStart, $sourceEnd])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTable &&
          runtimeType == other.runtimeType &&
          sourceStart == other.sourceStart &&
          sourceEnd == other.sourceEnd &&
          headerRow == other.headerRow &&
          delimiterRow == other.delimiterRow &&
          listEquals(bodyRows, other.bodyRows) &&
          listEquals(alignments, other.alignments) &&
          columnCount == other.columnCount;

  @override
  int get hashCode => Object.hash(
        sourceStart,
        sourceEnd,
        headerRow,
        delimiterRow,
        Object.hashAll(bodyRows),
        Object.hashAll(alignments),
        columnCount,
      );
}
