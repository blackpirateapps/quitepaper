import 'package:flutter/material.dart';

/// Represents a single key-value property inside a YAML frontmatter block.
@immutable
class FrontmatterProperty {
  const FrontmatterProperty({
    required this.key,
    required this.rawValue,
    required this.displayValue,
    required this.keyRange,
    required this.valueRange,
    required this.lineRange,
    this.isKnown = true,
    this.isEditable = true,
  });

  /// The normalized property key (e.g. 'title', 'author', 'created', 'source', 'description', 'tags').
  final String key;

  /// The raw value string extracted from source.
  final String rawValue;

  /// The parsed display value (e.g. `String` or `List<String>`).
  final dynamic displayValue;

  /// Exact source range of the key name in the full document.
  final TextRange keyRange;

  /// Exact source range of the value in the full document.
  final TextRange valueRange;

  /// Exact source range of the complete line/lines in the full document.
  final TextRange lineRange;

  /// Whether this is one of Quiet Paper's recognized semantic properties.
  final bool isKnown;

  /// Whether this property can be safely edited via the visual Properties UI.
  final bool isEditable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrontmatterProperty &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          rawValue == other.rawValue &&
          keyRange == other.keyRange &&
          valueRange == other.valueRange &&
          lineRange == other.lineRange;

  @override
  int get hashCode => Object.hash(key, rawValue, keyRange, valueRange, lineRange);
}

/// Represents an in-memory parsed YAML frontmatter document with exact source locations.
@immutable
class FrontmatterDocument {
  const FrontmatterDocument({
    required this.hasFrontmatter,
    this.rawFrontmatter = '',
    this.frontmatterRange = TextRange.empty,
    this.properties = const [],
    this.title,
    this.author,
    this.created,
    this.source,
    this.description,
    this.tags = const [],
    this.unknownProperties = const {},
    this.isMalformed = false,
    this.errorMessage,
    this.bodyStartOffset = 0,
  });

  /// Whether a YAML frontmatter block was detected at document start.
  final bool hasFrontmatter;

  /// The complete raw frontmatter block text including opening/closing `---`.
  final String rawFrontmatter;

  /// The character range of the entire frontmatter block in the document.
  final TextRange frontmatterRange;

  /// List of parsed individual properties with source ranges.
  final List<FrontmatterProperty> properties;

  /// Recognized Title property value.
  final String? title;

  /// Recognized Author property value.
  final String? author;

  /// Recognized Created/Date property value.
  final String? created;

  /// Recognized Source URL/text property value.
  final String? source;

  /// Recognized Description property value.
  final String? description;

  /// Recognized Tags list.
  final List<String> tags;

  /// Map of unrecognized or custom frontmatter properties preserved verbatim.
  final Map<String, String> unknownProperties;

  /// Whether frontmatter syntax was invalid or could not be parsed safely.
  final bool isMalformed;

  /// Optional error message if parsing encountered an issue.
  final String? errorMessage;

  /// The character index where the main markdown body starts.
  final int bodyStartOffset;

  /// Returns true if there are recognized properties to display in the visual Properties UI.
  bool get hasDisplayableProperties {
    if (!hasFrontmatter) return false;
    if (isMalformed) return true; // Show error notice
    return (title != null && title!.trim().isNotEmpty) ||
        (author != null && author!.trim().isNotEmpty) ||
        (created != null && created!.trim().isNotEmpty) ||
        (source != null && source!.trim().isNotEmpty) ||
        (description != null && description!.trim().isNotEmpty) ||
        tags.isNotEmpty;
  }

  /// Finds a parsed property by its normalized key name.
  FrontmatterProperty? getProperty(String key) {
    final lowerKey = key.toLowerCase();
    for (final prop in properties) {
      if (prop.key.toLowerCase() == lowerKey) return prop;
    }
    return null;
  }

  static const empty = FrontmatterDocument(hasFrontmatter: false);
}
