import 'package:flutter/foundation.dart';

import '../../../core/utils/tag_parser.dart';

/// Canonical identity for a (possibly nested) tag.
///
/// Tags are identified by their full slash-separated path
/// (`work/projects/alpha`). There is deliberately no persisted `parentId`:
/// hierarchy is derived from the path, which keeps tag identity stable across
/// offline creation, imports, Markdown edits, and encrypted sync.
@immutable
class TagPath implements Comparable<TagPath> {
  const TagPath._(this.segments);

  /// Parses and validates [input] as a tag path.
  ///
  /// Throws [ArgumentError] for empty paths, leading/trailing slashes, empty
  /// segments, or any segment that fails the shared tag validation rules.
  factory TagPath.parse(String input) {
    final normalized = TagParser.normalizeTag(input);
    if (!TagParser.isValidTag(normalized)) {
      throw ArgumentError.value(input, 'input', 'Invalid tag path');
    }
    return TagPath._(List.unmodifiable(normalized.split('/')));
  }

  /// Returns a [TagPath] when [input] is valid, otherwise `null`.
  static TagPath? tryParse(String input) {
    final normalized = TagParser.normalizeTag(input);
    if (!TagParser.isValidTag(normalized)) return null;
    return TagPath._(List.unmodifiable(normalized.split('/')));
  }

  /// Whether [input] is a syntactically valid tag path.
  static bool isValid(String input) =>
      TagParser.isValidTag(TagParser.normalizeTag(input));

  /// Path segments, e.g. `['work', 'projects']`.
  final List<String> segments;

  /// Canonical, normalized full path (no leading `#`).
  String get value => segments.join('/');

  /// Final segment, which is what note chips display.
  String get leaf => segments.last;

  /// Number of segments in this path.
  int get depth => segments.length;

  /// Whether this tag has a parent.
  bool get isNested => segments.length > 1;

  /// Full path of the parent, or `null` for a top-level tag.
  String? get parentValue =>
      isNested ? segments.sublist(0, segments.length - 1).join('/') : null;

  /// Parent path, or `null` for a top-level tag.
  TagPath? get parent {
    if (!isNested) return null;
    return TagPath._(
      List.unmodifiable(segments.sublist(0, segments.length - 1)),
    );
  }

  /// Every ancestor path from the top level down to the direct parent.
  List<TagPath> get ancestors => [
    for (var i = 1; i < segments.length; i++)
      TagPath._(List.unmodifiable(segments.sublist(0, i))),
  ];

  /// Every ancestor path (as strings) from the top level down to the parent.
  List<String> get ancestorValues => [
    for (final ancestor in ancestors) ancestor.value,
  ];

  /// Whether this path is a strict descendant of [other].
  bool isDescendantOf(TagPath other) {
    if (other.segments.length >= segments.length) return false;
    for (var i = 0; i < other.segments.length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }

  /// Whether this path is [other] or one of its descendants.
  bool isSelfOrDescendantOf(TagPath other) =>
      this == other || isDescendantOf(other);

  /// Whether [other] is a strict descendant of this path.
  bool isAncestorOf(TagPath other) => other.isDescendantOf(this);

  /// Returns the path of a direct child.
  TagPath child(String segment) => TagPath.parse('$value/$segment');

  /// Human-readable breadcrumb, e.g. `#work / projects / alpha`.
  String get breadcrumb => '#${segments.join(' / ')}';

  /// Full tag token, e.g. `#work/projects/alpha`.
  String get token => '#$value';

  @override
  int compareTo(TagPath other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagPath && listEquals(segments, other.segments);

  @override
  int get hashCode => Object.hashAll(segments);

  @override
  String toString() => 'TagPath($value)';
}
