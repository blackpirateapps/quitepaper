import 'package:flutter/foundation.dart';
import 'markdown_table_cell.dart';

/// Immutable model representing a single row in a Markdown table.
@immutable
class MarkdownTableRow {
  const MarkdownTableRow({
    required this.rowIndex,
    required this.isHeader,
    required this.isDelimiter,
    required this.cells,
    required this.sourceStart,
    required this.sourceEnd,
    required this.rawLine,
  });

  /// 0-indexed row index.
  final int rowIndex;

  /// Whether this row is the header row.
  final bool isHeader;

  /// Whether this row is the separator/delimiter row (`|---|---|`).
  final bool isDelimiter;

  /// Cells contained in this row.
  final List<MarkdownTableCell> cells;

  /// Absolute character start offset of the row in the source Markdown.
  final int sourceStart;

  /// Absolute character end offset of the row in the source Markdown (excluding newline).
  final int sourceEnd;

  /// Raw text line of this row.
  final String rawLine;

  /// Total number of cells in this row.
  int get cellCount => cells.length;

  @override
  String toString() =>
      'MarkdownTableRow(r: $rowIndex, cells: ${cells.length}, [$sourceStart, $sourceEnd])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTableRow &&
          runtimeType == other.runtimeType &&
          rowIndex == other.rowIndex &&
          isHeader == other.isHeader &&
          isDelimiter == other.isDelimiter &&
          listEquals(cells, other.cells) &&
          sourceStart == other.sourceStart &&
          sourceEnd == other.sourceEnd &&
          rawLine == other.rawLine;

  @override
  int get hashCode => Object.hash(
        rowIndex,
        isHeader,
        isDelimiter,
        Object.hashAll(cells),
        sourceStart,
        sourceEnd,
        rawLine,
      );
}
