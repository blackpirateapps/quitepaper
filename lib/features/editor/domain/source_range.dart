import 'dart:math';
import 'package:flutter/foundation.dart';

/// Represents an exact continuous slice [start, end) within canonical Markdown source text.
@immutable
class SourceRange {
  const SourceRange(this.start, this.end);

  final int start;
  final int end;

  /// Empty source range at offset 0.
  static const SourceRange zero = SourceRange(0, 0);

  /// Character length of this range in the source.
  int get length => max(0, end - start);

  /// Whether this range spans zero characters.
  bool get isEmpty => start >= end;

  /// Whether this range spans at least one character.
  bool get isNotEmpty => !isEmpty;

  /// Returns true if [offset] falls inside [start, end] (inclusive boundaries).
  bool contains(int offset) => offset >= start && offset <= end;

  /// Returns true if [offset] falls strictly inside [start, end) (exclusive end).
  bool containsStrict(int offset) => offset >= start && offset < end;

  /// Returns true if this range overlaps with [other].
  bool overlaps(SourceRange other) => start < other.end && end > other.start;

  /// Clamps boundaries between 0 and [maxSourceLength].
  SourceRange clamp(int maxSourceLength) {
    final clampedStart = start.clamp(0, maxSourceLength);
    final clampedEnd = end.clamp(clampedStart, maxSourceLength);
    return SourceRange(clampedStart, clampedEnd);
  }

  /// Shifts start and end by [delta].
  SourceRange shift(int delta) => SourceRange(start + delta, end + delta);

  /// Extracts the substring corresponding to this range from [source].
  String slice(String source) {
    if (source.isEmpty) return '';
    final s = start.clamp(0, source.length);
    final e = end.clamp(s, source.length);
    return source.substring(s, e);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SourceRange($start..$end)';
}
