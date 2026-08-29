import 'package:flutter/foundation.dart';

/// 2D grid position inside a Markdown table.
/// [row] is 0-indexed where row 0 corresponds to the header row, and rows 1..N correspond to body rows.
/// [column] is 0-indexed where column 0 corresponds to the leftmost column.
@immutable
class TablePosition {
  const TablePosition({
    required this.row,
    required this.column,
  });

  final int row;
  final int column;

  bool get isHeader => row == 0;

  TablePosition copyWith({int? row, int? column}) {
    return TablePosition(
      row: row ?? this.row,
      column: column ?? this.column,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TablePosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          column == other.column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => 'TablePosition(row: $row, col: $column)';
}
