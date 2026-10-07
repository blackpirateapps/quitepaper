import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../application/markdown_table_formatter.dart';
import '../application/markdown_table_parser.dart';
import '../application/rich_document_serializer.dart';
import 'markdown_table.dart';
import 'rich_inline.dart';
import 'text_attributes.dart';

const _uuid = Uuid();

/// Base interface for any structural block in a [RichDocument].
///
/// Blocks represent editing concepts rather than Markdown syntax.
/// Each block holds an editor-local [id] for stable UI rendering and keys,
/// which is never persisted to canonical Markdown or database schemas.
@immutable
abstract class RichBlock {
  const RichBlock({required this.id});

  /// Unique session-local identifier for this block.
  final String id;

  /// Plain text content of this block without syntax formatting.
  String get plainText;

  /// Whether this block represents an inline-formatted text flow
  /// (e.g. Paragraph, Heading, List, Checklist, Quote).
  bool get isTextBlock => false;

  /// Inline spans of this block if it is a text block.
  List<RichInlineSpan> get spans => const [];

  /// Creates a copy of this block with an optional new local identifier.
  RichBlock copyWithId(String newId);

  /// Serializes this block to structured JSON.
  Map<String, dynamic> toJson();

  /// Deserializes a polymorphic [RichBlock] from structured JSON.
  static RichBlock fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'paragraph';
    final id = json['id'] as String? ?? _uuid.v4();
    switch (type) {
      case 'heading':
        return HeadingBlock(
          id: id,
          level: (json['level'] as num?)?.toInt() ?? 1,
          spans: _parseSpansJson(json['spans']),
        );
      case 'checklist_item':
        return ChecklistItemBlock(
          id: id,
          isChecked: json['isChecked'] == true,
          spans: _parseSpansJson(json['spans']),
        );
      case 'bulleted_list_item':
        return BulletedListItemBlock(
          id: id,
          indent: (json['indent'] as num?)?.toInt() ?? 0,
          spans: _parseSpansJson(json['spans']),
        );
      case 'ordered_list_item':
        return OrderedListItemBlock(
          id: id,
          order: (json['order'] as num?)?.toInt() ?? 1,
          indent: (json['indent'] as num?)?.toInt() ?? 0,
          spans: _parseSpansJson(json['spans']),
        );
      case 'quote':
        return QuoteBlock(
          id: id,
          spans: _parseSpansJson(json['spans']),
        );
      case 'code_block':
        return CodeBlock(
          id: id,
          language: json['language'] as String? ?? '',
          code: json['code'] as String? ?? '',
        );
      case 'horizontal_rule':
        return HorizontalRuleBlock(id: id);
      case 'image':
        return ImageBlock(
          id: id,
          url: json['url'] as String? ?? '',
          alt: json['alt'] as String? ?? '',
          title: json['title'] as String?,
        );
      case 'table':
        final md = json['markdown'] as String? ?? '';
        final tables = const MarkdownTableParser().findTables(md);
        if (tables.isNotEmpty) {
          return TableBlock(id: id, table: tables.first);
        }
        final initial = MarkdownTableFormatter.insertTable(
          value: const TextEditingValue(text: ''),
          rows: 3,
          columns: 3,
        );
        return TableBlock(
          id: id,
          table: const MarkdownTableParser().findTables(initial.text).first,
        );
      case 'paragraph':
      default:
        return ParagraphBlock(
          id: id,
          spans: _parseSpansJson(json['spans']),
        );
    }
  }

  static List<RichInlineSpan> _parseSpansJson(dynamic spansJson) {
    if (spansJson is! List) return const [];
    return spansJson
        .whereType<Map<String, dynamic>>()
        .map(RichInlineSpan.fromJson)
        .toList();
  }
}

/// A standard editorial paragraph block.
class ParagraphBlock extends RichBlock {
  const ParagraphBlock({
    required super.id,
    this.spans = const [],
  });

  factory ParagraphBlock.empty([String? id]) => ParagraphBlock(
        id: id ?? _uuid.v4(),
        spans: const [RichInlineSpan(text: '')],
      );

  factory ParagraphBlock.fromText(String text, {String? id, TextAttributes? attributes}) =>
      ParagraphBlock(
        id: id ?? _uuid.v4(),
        spans: [
          RichInlineSpan(
            text: text,
            attributes: attributes ?? TextAttributes.none,
          ),
        ],
      );

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  ParagraphBlock copyWith({
    String? id,
    List<RichInlineSpan>? spans,
  }) {
    return ParagraphBlock(
      id: id ?? this.id,
      spans: spans ?? this.spans,
    );
  }

  @override
  ParagraphBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'paragraph',
        'id': id,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParagraphBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(spans));

  @override
  String toString() => 'ParagraphBlock($id, plainText: "$plainText")';
}

/// A document heading block (H1 through H6).
class HeadingBlock extends RichBlock {
  const HeadingBlock({
    required super.id,
    required this.level,
    this.spans = const [],
  }) : assert(level >= 1 && level <= 6, 'Heading level must be between 1 and 6');

  factory HeadingBlock.fromText(String text, {int level = 1, String? id}) =>
      HeadingBlock(
        id: id ?? _uuid.v4(),
        level: level,
        spans: [RichInlineSpan(text: text)],
      );

  /// Heading level: 1 (H1) through 6 (H6).
  final int level;

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  HeadingBlock copyWith({
    String? id,
    int? level,
    List<RichInlineSpan>? spans,
  }) {
    return HeadingBlock(
      id: id ?? this.id,
      level: level ?? this.level,
      spans: spans ?? this.spans,
    );
  }

  @override
  HeadingBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'heading',
        'id': id,
        'level': level,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadingBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          level == other.level &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, level, Object.hashAll(spans));

  @override
  String toString() => 'HeadingBlock($id, H$level, plainText: "$plainText")';
}

/// An interactive checklist task item.
class ChecklistItemBlock extends RichBlock {
  const ChecklistItemBlock({
    required super.id,
    required this.isChecked,
    this.spans = const [],
  });

  factory ChecklistItemBlock.fromText(
    String text, {
    bool isChecked = false,
    String? id,
  }) =>
      ChecklistItemBlock(
        id: id ?? _uuid.v4(),
        isChecked: isChecked,
        spans: [RichInlineSpan(text: text)],
      );

  /// Whether the task is checked / completed.
  final bool isChecked;

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  ChecklistItemBlock copyWith({
    String? id,
    bool? isChecked,
    List<RichInlineSpan>? spans,
  }) {
    return ChecklistItemBlock(
      id: id ?? this.id,
      isChecked: isChecked ?? this.isChecked,
      spans: spans ?? this.spans,
    );
  }

  @override
  ChecklistItemBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'checklist_item',
        'id': id,
        'isChecked': isChecked,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItemBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isChecked == other.isChecked &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, isChecked, Object.hashAll(spans));

  @override
  String toString() =>
      'ChecklistItemBlock($id, checked: $isChecked, plainText: "$plainText")';
}

/// An unordered bulleted list item.
class BulletedListItemBlock extends RichBlock {
  const BulletedListItemBlock({
    required super.id,
    this.indent = 0,
    this.spans = const [],
  });

  factory BulletedListItemBlock.fromText(
    String text, {
    int indent = 0,
    String? id,
  }) =>
      BulletedListItemBlock(
        id: id ?? _uuid.v4(),
        indent: indent,
        spans: [RichInlineSpan(text: text)],
      );

  /// Indentation depth (0 for root, 1+ for nested sub-bullets).
  final int indent;

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  BulletedListItemBlock copyWith({
    String? id,
    int? indent,
    List<RichInlineSpan>? spans,
  }) {
    return BulletedListItemBlock(
      id: id ?? this.id,
      indent: indent ?? this.indent,
      spans: spans ?? this.spans,
    );
  }

  @override
  BulletedListItemBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'bulleted_list_item',
        'id': id,
        'indent': indent,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BulletedListItemBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          indent == other.indent &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, indent, Object.hashAll(spans));

  @override
  String toString() =>
      'BulletedListItemBlock($id, indent: $indent, plainText: "$plainText")';
}

/// An ordered numbered list item.
class OrderedListItemBlock extends RichBlock {
  const OrderedListItemBlock({
    required super.id,
    required this.order,
    this.indent = 0,
    this.spans = const [],
  });

  factory OrderedListItemBlock.fromText(
    String text, {
    required int order,
    int indent = 0,
    String? id,
  }) =>
      OrderedListItemBlock(
        id: id ?? _uuid.v4(),
        order: order,
        indent: indent,
        spans: [RichInlineSpan(text: text)],
      );

  /// Number prefix of this list item (e.g. 1, 2, 3).
  final int order;

  /// Indentation depth (0 for root).
  final int indent;

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  OrderedListItemBlock copyWith({
    String? id,
    int? order,
    int? indent,
    List<RichInlineSpan>? spans,
  }) {
    return OrderedListItemBlock(
      id: id ?? this.id,
      order: order ?? this.order,
      indent: indent ?? this.indent,
      spans: spans ?? this.spans,
    );
  }

  @override
  OrderedListItemBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ordered_list_item',
        'id': id,
        'order': order,
        'indent': indent,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderedListItemBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          order == other.order &&
          indent == other.indent &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, order, indent, Object.hashAll(spans));

  @override
  String toString() =>
      'OrderedListItemBlock($id, order: $order, indent: $indent, plainText: "$plainText")';
}

/// A blockquote element.
class QuoteBlock extends RichBlock {
  const QuoteBlock({
    required super.id,
    this.spans = const [],
  });

  factory QuoteBlock.fromText(String text, {String? id}) => QuoteBlock(
        id: id ?? _uuid.v4(),
        spans: [RichInlineSpan(text: text)],
      );

  @override
  final List<RichInlineSpan> spans;

  @override
  bool get isTextBlock => true;

  @override
  String get plainText => spans.plainText;

  QuoteBlock copyWith({
    String? id,
    List<RichInlineSpan>? spans,
  }) {
    return QuoteBlock(
      id: id ?? this.id,
      spans: spans ?? this.spans,
    );
  }

  @override
  QuoteBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'quote',
        'id': id,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listEquals(spans, other.spans);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(spans));

  @override
  String toString() => 'QuoteBlock($id, plainText: "$plainText")';
}

/// A fenced code block with optional programming language identifier.
class CodeBlock extends RichBlock {
  const CodeBlock({
    required super.id,
    this.language = '',
    required this.code,
  });

  /// Programming language identifier (e.g. `dart`, `json`, `yaml`, `bash`).
  final String language;

  /// Verbatim code text content.
  final String code;

  @override
  String get plainText => code;

  CodeBlock copyWith({
    String? id,
    String? language,
    String? code,
  }) {
    return CodeBlock(
      id: id ?? this.id,
      language: language ?? this.language,
      code: code ?? this.code,
    );
  }

  @override
  CodeBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'code_block',
        'id': id,
        'language': language,
        'code': code,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          language == other.language &&
          code == other.code;

  @override
  int get hashCode => Object.hash(id, language, code);

  @override
  String toString() => 'CodeBlock($id, lang: "$language", length: ${code.length})';
}

/// A horizontal dividing rule (`---`).
class HorizontalRuleBlock extends RichBlock {
  const HorizontalRuleBlock({required super.id});

  factory HorizontalRuleBlock.create([String? id]) =>
      HorizontalRuleBlock(id: id ?? _uuid.v4());

  @override
  String get plainText => '';

  @override
  HorizontalRuleBlock copyWithId(String newId) => HorizontalRuleBlock(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'horizontal_rule',
        'id': id,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HorizontalRuleBlock &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HorizontalRuleBlock($id)';
}

/// An embedded image reference.
class ImageBlock extends RichBlock {
  const ImageBlock({
    required super.id,
    required this.url,
    this.alt = '',
    this.title,
  });

  /// Target image URL or local file path reference.
  final String url;

  /// Accessible alternative description.
  final String alt;

  /// Optional tooltip title.
  final String? title;

  @override
  String get plainText => alt;

  ImageBlock copyWith({
    String? id,
    String? url,
    String? alt,
    String? title,
  }) {
    return ImageBlock(
      id: id ?? this.id,
      url: url ?? this.url,
      alt: alt ?? this.alt,
      title: title ?? this.title,
    );
  }

  @override
  ImageBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'id': id,
        'url': url,
        'alt': alt,
        if (title != null) 'title': title,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          alt == other.alt &&
          title == other.title;

  @override
  int get hashCode => Object.hash(id, url, alt, title);

  @override
  String toString() => 'ImageBlock($id, url: "$url", alt: "$alt")';
}

/// A Markdown table block.
class TableBlock extends RichBlock {
  const TableBlock({
    required super.id,
    required this.table,
  });

  /// The underlying structured [MarkdownTable] data model.
  final MarkdownTable table;

  @override
  String get plainText => '';

  TableBlock copyWith({
    String? id,
    MarkdownTable? table,
  }) {
    return TableBlock(
      id: id ?? this.id,
      table: table ?? this.table,
    );
  }

  @override
  TableBlock copyWithId(String newId) => copyWith(id: newId);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'table',
        'id': id,
        'markdown': RichDocumentSerializer.formatTable(table),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableBlock &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          table == other.table;

  @override
  int get hashCode => Object.hash(id, table);

  @override
  String toString() => 'TableBlock($id, cols: ${table.columnCount}, rows: ${table.rowCount})';
}
