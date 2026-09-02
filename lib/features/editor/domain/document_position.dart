import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Represents a caret or navigation position within a semantic document block.
@immutable
class DocumentPosition {
  const DocumentPosition({
    required this.blockId,
    required this.offset,
    this.affinity = TextAffinity.downstream,
  });

  /// The unique identifier of the target semantic block.
  final String blockId;

  /// The character offset within the visible text of this block.
  final int offset;

  /// Caret affinity when at ambiguous visual boundary.
  final TextAffinity affinity;

  DocumentPosition copyWith({
    String? blockId,
    int? offset,
    TextAffinity? affinity,
  }) {
    return DocumentPosition(
      blockId: blockId ?? this.blockId,
      offset: offset ?? this.offset,
      affinity: affinity ?? this.affinity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPosition &&
          runtimeType == other.runtimeType &&
          blockId == other.blockId &&
          offset == other.offset &&
          affinity == other.affinity;

  @override
  int get hashCode => Object.hash(blockId, offset, affinity);

  @override
  String toString() => 'DocumentPosition($blockId, offset: $offset, affinity: $affinity)';
}

/// Represents an active selection in a semantic document spanning between [base] and [extent].
@immutable
class DocumentSelection {
  const DocumentSelection({
    required this.base,
    required this.extent,
  });

  /// Collapsed selection (caret position) at [position].
  const DocumentSelection.collapsed(DocumentPosition position)
      : base = position,
        extent = position;

  final DocumentPosition base;
  final DocumentPosition extent;

  /// Whether the selection is a single collapsed caret point.
  bool get isCollapsed =>
      base.blockId == extent.blockId && base.offset == extent.offset;

  /// Whether the selection is within valid positive bounds.
  bool get isValid => base.offset >= 0 && extent.offset >= 0;

  /// Whether the selection spans within a single semantic block.
  bool get isSingleBlock => base.blockId == extent.blockId;

  /// Starting position (the earlier offset if single block).
  DocumentPosition get start => (isSingleBlock && base.offset > extent.offset) ? extent : base;

  /// Ending position (the later offset if single block).
  DocumentPosition get end => (isSingleBlock && base.offset > extent.offset) ? base : extent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSelection &&
          runtimeType == other.runtimeType &&
          base == other.base &&
          extent == other.extent;

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() => 'DocumentSelection(base: $base, extent: $extent)';
}
