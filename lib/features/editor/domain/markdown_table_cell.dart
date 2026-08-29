import 'package:flutter/foundation.dart';

/// Immutable model representing a single cell inside a Markdown table.
/// Preserves exact 1:1 character ranges back to the original source Markdown document.
@immutable
class MarkdownTableCell {
  const MarkdownTableCell({
    required this.rowIndex,
    required this.columnIndex,
    required this.rawText,
    required this.sourceStart,
    required this.sourceEnd,
    required this.contentStart,
    required this.contentEnd,
  });

  /// 0-indexed row index (0 = header, 1+ = body rows).
  final int rowIndex;

  /// 0-indexed column index.
  final int columnIndex;

  /// The raw unescaped slice of text in the cell (excluding enclosing structural pipes).
  final String rawText;

  /// Absolute character start offset of the cell boundary in the source Markdown.
  final int sourceStart;

  /// Absolute character end offset of the cell boundary in the source Markdown.
  final int sourceEnd;

  /// Absolute character start offset of the trimmed/actual cell content.
  final int contentStart;

  /// Absolute character end offset of the trimmed/actual cell content.
  final int contentEnd;

  /// Cell text stripped of leading and trailing whitespace.
  String get trimmedText => rawText.trim();

  /// Whether the cell has no visible text content.
  bool get isEmpty => trimmedText.isEmpty;

  @override
  String toString() =>
      'MarkdownTableCell(r: $rowIndex, c: $columnIndex, "$trimmedText", [$contentStart, $contentEnd])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTableCell &&
          runtimeType == other.runtimeType &&
          rowIndex == other.rowIndex &&
          columnIndex == other.columnIndex &&
          rawText == other.rawText &&
          sourceStart == other.sourceStart &&
          sourceEnd == other.sourceEnd &&
          contentStart == other.contentStart &&
          contentEnd == other.contentEnd;

  @override
  int get hashCode => Object.hash(
        rowIndex,
        columnIndex,
        rawText,
        sourceStart,
        sourceEnd,
        contentStart,
        contentEnd,
      );
}
