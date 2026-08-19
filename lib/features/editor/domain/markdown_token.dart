import 'package:flutter/material.dart';

/// Semantic token types recognized by the Markdown editor tokenizer.
enum MarkdownTokenType {
  // Block-level constructs
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  headingMarker,
  blockquote,
  blockquoteMarker,
  unorderedList,
  unorderedListMarker,
  orderedList,
  orderedListMarker,
  checklistMarkerUnchecked,
  checklistMarkerChecked,
  taskText,
  taskTextCompleted,
  codeBlock,
  codeBlockFence,
  horizontalRule,
  frontmatter,
  frontmatterDelimiter,

  // Inline-level constructs
  body,
  bold,
  italic,
  boldItalic,
  strikethrough,
  highlight,
  inlineCode,
  inlineCodeMarker,
  link,
  linkText,
  linkUrl,
  tag,
  syntaxMarker,
  plainText,
}

/// A parsed token span mapping a slice of the source Markdown to a token type.
@immutable
class MarkdownToken {
  const MarkdownToken({
    required this.start,
    required this.end,
    required this.type,
    this.text,
  });

  final int start;
  final int end;
  final MarkdownTokenType type;
  final String? text;

  int get length => end - start;

  @override
  String toString() => 'MarkdownToken($type, [$start, $end])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownToken &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          type == other.type;

  @override
  int get hashCode => Object.hash(start, end, type);
}

/// A styled segment of text mapped to a specific [TextStyle].
@immutable
class StyledTextSegment {
  const StyledTextSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.style,
  });

  final int start;
  final int end;
  final String text;
  final TextStyle style;

  int get length => end - start;

  @override
  String toString() => 'StyledTextSegment([$start, $end], text: "$text")';
}
