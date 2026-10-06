import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a discrete cursor position within a [RichDocument].
@immutable
class RichDocumentPosition implements Comparable<RichDocumentPosition> {
  const RichDocumentPosition({
    required this.blockIndex,
    required this.blockId,
    required this.offset,
  });

  /// Index of the block in the document's `blocks` list.
  final int blockIndex;

  /// Identifier of the block.
  final String blockId;

  /// Character offset within the block's text content.
  final int offset;

  @override
  int compareTo(RichDocumentPosition other) {
    if (blockIndex != other.blockIndex) {
      return blockIndex.compareTo(other.blockIndex);
    }
    return offset.compareTo(other.offset);
  }

  RichDocumentPosition copyWith({
    int? blockIndex,
    String? blockId,
    int? offset,
  }) {
    return RichDocumentPosition(
      blockIndex: blockIndex ?? this.blockIndex,
      blockId: blockId ?? this.blockId,
      offset: offset ?? this.offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichDocumentPosition &&
          runtimeType == other.runtimeType &&
          blockIndex == other.blockIndex &&
          blockId == other.blockId &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(blockIndex, blockId, offset);

  @override
  String toString() => 'RichDocumentPosition(block: $blockIndex, id: $blockId, offset: $offset)';
}

/// Represents a selection range across blocks and spans in a [RichDocument].
@immutable
class RichDocumentSelection {
  const RichDocumentSelection({
    required this.base,
    required this.extent,
    this.affinity = TextAffinity.downstream,
  });

  factory RichDocumentSelection.collapsed(RichDocumentPosition position) =>
      RichDocumentSelection(base: position, extent: position);

  /// Selection start/anchor position.
  final RichDocumentPosition base;

  /// Selection end/active caret position.
  final RichDocumentPosition extent;

  /// Text affinity for cursor rendering.
  final TextAffinity affinity;

  /// Whether the selection is a single collapsed caret point.
  bool get isCollapsed => base == extent;

  /// Earliest position in the document between [base] and [extent].
  RichDocumentPosition get start => base.compareTo(extent) <= 0 ? base : extent;

  /// Latest position in the document between [base] and [extent].
  RichDocumentPosition get end => base.compareTo(extent) <= 0 ? extent : base;

  /// Whether the selection spans across different blocks.
  bool get spansMultipleBlocks => base.blockIndex != extent.blockIndex;

  RichDocumentSelection copyWith({
    RichDocumentPosition? base,
    RichDocumentPosition? extent,
    TextAffinity? affinity,
  }) {
    return RichDocumentSelection(
      base: base ?? this.base,
      extent: extent ?? this.extent,
      affinity: affinity ?? this.affinity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichDocumentSelection &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          extent == other.extent &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(base, extent, affinity);

  @override
  String toString() => 'RichDocumentSelection(start: $start, end: $end, isCollapsed: $isCollapsed)';
}
