import 'package:flutter/foundation.dart';
import 'text_attributes.dart';

/// Immutable representation of a styled contiguous run of text within a block.
///
/// Contains only pure text and semantic [TextAttributes].
/// Does not contain synthetic Markdown syntax characters.
@immutable
class RichInlineSpan {
  const RichInlineSpan({
    required this.text,
    this.attributes = TextAttributes.none,
  });

  /// The raw unformatted string of characters in this span.
  final String text;

  /// Semantic typography and interactive attributes applied to this span.
  final TextAttributes attributes;

  /// Length of the text in UTF-16 code units.
  int get length => text.length;

  /// Whether the text of this span is empty.
  bool get isEmpty => text.isEmpty;

  /// Whether the text of this span is non-empty.
  bool get isNotEmpty => text.isNotEmpty;

  /// Returns a copy of this span with the specified fields replaced.
  RichInlineSpan copyWith({
    String? text,
    TextAttributes? attributes,
  }) {
    return RichInlineSpan(
      text: text ?? this.text,
      attributes: attributes ?? this.attributes,
    );
  }

  /// Extracts a substring slice from this span, preserving the attributes.
  RichInlineSpan slice(int start, [int? end]) {
    final effectiveEnd = end ?? text.length;
    final clampedStart = start.clamp(0, text.length);
    final clampedEnd = effectiveEnd.clamp(clampedStart, text.length);
    return RichInlineSpan(
      text: text.substring(clampedStart, clampedEnd),
      attributes: attributes,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (!attributes.isEmpty) 'attributes': attributes.toJson(),
      };

  factory RichInlineSpan.fromJson(Map<String, dynamic> json) => RichInlineSpan(
        text: json['text'] as String? ?? '',
        attributes: json['attributes'] != null
            ? TextAttributes.fromJson(json['attributes'] as Map<String, dynamic>)
            : TextAttributes.none,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichInlineSpan &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          attributes == other.attributes;

  @override
  int get hashCode => Object.hash(text, attributes);

  @override
  String toString() => 'RichInlineSpan("$text", $attributes)';
}

/// Helper extension on collections of [RichInlineSpan].
extension RichInlineSpanListX on List<RichInlineSpan> {
  /// The combined plain text across all spans in this list.
  String get plainText => map((s) => s.text).join();

  /// Total character length across all spans in this list.
  int get totalLength => fold(0, (sum, s) => sum + s.length);

  /// Normalizes this list by merging adjacent spans with identical attributes
  /// and removing empty spans.
  List<RichInlineSpan> normalized() {
    if (isEmpty) return const [];
    final result = <RichInlineSpan>[];
    for (final span in this) {
      if (span.isEmpty) continue;
      if (result.isNotEmpty && result.last.attributes == span.attributes) {
        final prev = result.removeLast();
        result.add(RichInlineSpan(
          text: prev.text + span.text,
          attributes: prev.attributes,
        ));
      } else {
        result.add(span);
      }
    }
    return List.unmodifiable(result);
  }
}
