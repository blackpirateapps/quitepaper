import 'package:flutter/foundation.dart';
import 'markdown_table.dart';
import 'source_range.dart';

/// Base interface for any element in the semantic document tree.
@immutable
abstract class SemanticNode {
  const SemanticNode();

  /// The range in the canonical Markdown source corresponding to this node.
  SourceRange get sourceRange;
}

/// Abstract representation of inline content inside a block.
@immutable
abstract class SemanticInline extends SemanticNode {
  const SemanticInline();

  /// The visible rendered text of this inline run.
  String get text;

  /// Source range of the inner content excluding Markdown delimiters, if applicable.
  SourceRange? get contentRange;
}

/// Plain, unstyled text run.
class PlainRun extends SemanticInline {
  const PlainRun(this.text, this.sourceRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  SourceRange? get contentRange => sourceRange;

  @override
  String toString() => 'PlainRun("$text", $sourceRange)';
}

/// Bold text run (**text** or __text__).
class BoldRun extends SemanticInline {
  const BoldRun(this.text, this.sourceRange, this.contentRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  final SourceRange contentRange;

  @override
  String toString() => 'BoldRun("$text", src: $sourceRange, content: $contentRange)';
}

/// Italic text run (*text* or _text_).
class ItalicRun extends SemanticInline {
  const ItalicRun(this.text, this.sourceRange, this.contentRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  final SourceRange contentRange;

  @override
  String toString() => 'ItalicRun("$text", src: $sourceRange, content: $contentRange)';
}

/// Strikethrough text run (~~text~~).
class StrikeRun extends SemanticInline {
  const StrikeRun(this.text, this.sourceRange, this.contentRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  final SourceRange contentRange;

  @override
  String toString() => 'StrikeRun("$text", src: $sourceRange, content: $contentRange)';
}

/// Highlighted text run (==text==).
class HighlightRun extends SemanticInline {
  const HighlightRun(this.text, this.sourceRange, this.contentRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  final SourceRange contentRange;

  @override
  String toString() => 'HighlightRun("$text", src: $sourceRange, content: $contentRange)';
}

/// Inline monospace code run (`code`).
class InlineCodeRun extends SemanticInline {
  const InlineCodeRun(this.text, this.sourceRange, this.contentRange);

  @override
  final String text;

  @override
  final SourceRange sourceRange;

  @override
  final SourceRange contentRange;

  @override
  String toString() => 'InlineCodeRun("$text", src: $sourceRange, content: $contentRange)';
}

/// Hyperlink run ([label](url)).
class LinkRun extends SemanticInline {
  const LinkRun({
    required this.text,
    required this.destination,
    required this.sourceRange,
    required this.labelRange,
    required this.urlRange,
  });

  @override
  final String text;

  final String destination;

  @override
  final SourceRange sourceRange;

  final SourceRange labelRange;
  final SourceRange urlRange;

  @override
  SourceRange? get contentRange => labelRange;

  @override
  String toString() => 'LinkRun("$text" -> "$destination", src: $sourceRange)';
}

/// Note wiki-link run ([[Note Title]]).
class NoteLinkRun extends SemanticInline {
  const NoteLinkRun({
    required this.noteTitle,
    required this.sourceRange,
    required this.titleRange,
  });

  final String noteTitle;

  @override
  String get text => noteTitle;

  @override
  final SourceRange sourceRange;

  final SourceRange titleRange;

  @override
  SourceRange? get contentRange => titleRange;

  @override
  String toString() => 'NoteLinkRun("[[$noteTitle]]", src: $sourceRange)';
}

/// Tag run (#tag).
class TagRun extends SemanticInline {
  const TagRun(this.tag, this.sourceRange);

  final String tag;

  @override
  String get text => '#$tag';

  @override
  final SourceRange sourceRange;

  @override
  SourceRange? get contentRange => sourceRange;

  @override
  String toString() => 'TagRun("#$tag", src: $sourceRange)';
}

// ---------------------------------------------------------------------------
// Block Nodes
// ---------------------------------------------------------------------------

/// Abstract base class for all semantic document blocks.
@immutable
abstract class SemanticBlock extends SemanticNode {
  const SemanticBlock();

  /// Unique stable identifier for this block during an editing session.
  String get id;

  /// Plain text content of this block without syntax markers.
  String get plainText;

  /// Whether this block directly contains editable text runs.
  bool get isEditable => true;
}

/// Heading block (# Heading, ## Heading, etc.).
class HeadingBlock extends SemanticBlock {
  const HeadingBlock({
    required this.id,
    required this.level,
    required this.runs,
    required this.sourceRange,
    required this.markerRange,
    required this.contentRange,
  });

  @override
  final String id;

  /// Heading level (1 to 6).
  final int level;

  final List<SemanticInline> runs;

  @override
  final SourceRange sourceRange;

  final SourceRange markerRange;
  final SourceRange contentRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'HeadingBlock(H$level, "$plainText", src: $sourceRange)';
}

/// Paragraph block.
class ParagraphBlock extends SemanticBlock {
  const ParagraphBlock({
    required this.id,
    required this.runs,
    required this.sourceRange,
  });

  @override
  final String id;

  final List<SemanticInline> runs;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'ParagraphBlock("$plainText", src: $sourceRange)';
}

/// Unordered bullet list item (- item, * item, + item).
class ListItemBlock extends SemanticBlock {
  const ListItemBlock({
    required this.id,
    required this.runs,
    required this.indent,
    required this.marker,
    required this.sourceRange,
    required this.markerRange,
    required this.contentRange,
  });

  @override
  final String id;

  final List<SemanticInline> runs;
  final int indent;
  final String marker;

  @override
  final SourceRange sourceRange;

  final SourceRange markerRange;
  final SourceRange contentRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'ListItemBlock("$marker $plainText", src: $sourceRange)';
}

/// Unordered list container block.
class ListBlock extends SemanticBlock {
  const ListBlock({
    required this.id,
    required this.items,
    required this.sourceRange,
  });

  @override
  final String id;

  final List<ListItemBlock> items;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => items.map((i) => i.plainText).join('\n');

  @override
  bool get isEditable => false;

  @override
  String toString() => 'ListBlock(${items.length} items, src: $sourceRange)';
}

/// Ordered list item (1. item, 2. item, etc.).
class OrderedListItemBlock extends SemanticBlock {
  const OrderedListItemBlock({
    required this.id,
    required this.number,
    required this.delimiter,
    required this.runs,
    required this.indent,
    required this.sourceRange,
    required this.markerRange,
    required this.contentRange,
  });

  @override
  final String id;

  final int number;
  final String delimiter;
  final List<SemanticInline> runs;
  final int indent;

  @override
  final SourceRange sourceRange;

  final SourceRange markerRange;
  final SourceRange contentRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'OrderedListItemBlock("$number$delimiter $plainText", src: $sourceRange)';
}

/// Ordered list container block.
class OrderedListBlock extends SemanticBlock {
  const OrderedListBlock({
    required this.id,
    required this.items,
    required this.startNumber,
    required this.sourceRange,
  });

  @override
  final String id;

  final List<OrderedListItemBlock> items;
  final int startNumber;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => items.map((i) => i.plainText).join('\n');

  @override
  bool get isEditable => false;

  @override
  String toString() => 'OrderedListBlock(${items.length} items, src: $sourceRange)';
}

/// Checklist item (- [ ] task, - [x] task).
class ChecklistItemBlock extends SemanticBlock {
  const ChecklistItemBlock({
    required this.id,
    required this.checked,
    required this.runs,
    required this.indent,
    required this.sourceRange,
    required this.boxRange,
    required this.contentRange,
  });

  @override
  final String id;

  final bool checked;
  final List<SemanticInline> runs;
  final int indent;

  @override
  final SourceRange sourceRange;

  final SourceRange boxRange;
  final SourceRange contentRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'ChecklistItemBlock([${checked ? 'x' : ' '}] "$plainText", src: $sourceRange)';
}

/// Checklist container block.
class ChecklistBlock extends SemanticBlock {
  const ChecklistBlock({
    required this.id,
    required this.items,
    required this.sourceRange,
  });

  @override
  final String id;

  final List<ChecklistItemBlock> items;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => items.map((i) => i.plainText).join('\n');

  @override
  bool get isEditable => false;

  @override
  String toString() => 'ChecklistBlock(${items.length} items, src: $sourceRange)';
}

/// Blockquote block (> quote).
class QuoteBlock extends SemanticBlock {
  const QuoteBlock({
    required this.id,
    required this.runs,
    required this.sourceRange,
    required this.markerRange,
    required this.contentRange,
  });

  @override
  final String id;

  final List<SemanticInline> runs;

  @override
  final SourceRange sourceRange;

  final SourceRange markerRange;
  final SourceRange contentRange;

  @override
  String get plainText => runs.map((r) => r.text).join();

  @override
  String toString() => 'QuoteBlock("> $plainText", src: $sourceRange)';
}

/// Horizontal rule block (---, ***, ___).
class HorizontalRuleBlock extends SemanticBlock {
  const HorizontalRuleBlock({
    required this.id,
    required this.marker,
    required this.sourceRange,
  });

  @override
  final String id;

  final String marker;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => '';

  @override
  bool get isEditable => false;

  @override
  String toString() => 'HorizontalRuleBlock("$marker", src: $sourceRange)';
}

/// Fenced code block (```lang ... ```).
class CodeBlock extends SemanticBlock {
  const CodeBlock({
    required this.id,
    required this.language,
    required this.code,
    required this.sourceRange,
    required this.openingFenceRange,
    required this.codeRange,
    this.closingFenceRange,
  });

  @override
  final String id;

  final String? language;
  final String code;

  @override
  final SourceRange sourceRange;

  final SourceRange openingFenceRange;
  final SourceRange codeRange;
  final SourceRange? closingFenceRange;

  @override
  String get plainText => code;

  @override
  String toString() => 'CodeBlock(${language ?? "plain"}, length: ${code.length}, src: $sourceRange)';
}

/// GFM Table block embedded into the semantic document.
class TableBlock extends SemanticBlock {
  const TableBlock({
    required this.id,
    required this.table,
    required this.sourceRange,
  });

  @override
  final String id;

  final MarkdownTable table;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => '';

  @override
  bool get isEditable => false;

  @override
  String toString() => 'TableBlock(${table.rowCount}x${table.columnCount}, src: $sourceRange)';
}

/// Image block (![alt](url)).
class ImageBlock extends SemanticBlock {
  const ImageBlock({
    required this.id,
    required this.altText,
    required this.url,
    required this.sourceRange,
  });

  @override
  final String id;

  final String altText;
  final String url;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => altText;

  @override
  bool get isEditable => false;

  @override
  String toString() => 'ImageBlock(![$altText]($url), src: $sourceRange)';
}

/// Fallback block for unsupported or unrecognized Markdown constructs.
class UnsupportedMarkdownBlock extends SemanticBlock {
  const UnsupportedMarkdownBlock({
    required this.id,
    required this.rawSource,
    required this.sourceRange,
  });

  @override
  final String id;

  final String rawSource;

  @override
  final SourceRange sourceRange;

  @override
  String get plainText => rawSource;

  @override
  String toString() => 'UnsupportedMarkdownBlock(length: ${rawSource.length}, src: $sourceRange)';
}
