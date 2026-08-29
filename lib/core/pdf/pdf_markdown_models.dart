import 'dart:typed_data';

/// Text alignment within a table column.
enum PdfTableCellAlignment {
  left,
  center,
  right,
}

/// A formatted inline text span with semantic styles.
class PdfInlineRun {
  const PdfInlineRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isStrike = false,
    this.isHighlight = false,
    this.isCode = false,
    this.linkUrl,
    this.isTag = false,
  });

  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isStrike;
  final bool isHighlight;
  final bool isCode;
  final String? linkUrl;
  final bool isTag;

  bool get isLink => linkUrl != null && linkUrl!.isNotEmpty;
  bool get isBoldItalic => isBold && isItalic;

  PdfInlineRun copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isStrike,
    bool? isHighlight,
    bool? isCode,
    String? linkUrl,
    bool? isTag,
  }) {
    return PdfInlineRun(
      text: text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isStrike: isStrike ?? this.isStrike,
      isHighlight: isHighlight ?? this.isHighlight,
      isCode: isCode ?? this.isCode,
      linkUrl: linkUrl ?? this.linkUrl,
      isTag: isTag ?? this.isTag,
    );
  }

  @override
  String toString() =>
      'PdfInlineRun("$text"${isBold ? ", bold" : ""}${isItalic ? ", italic" : ""}${isCode ? ", code" : ""}${isHighlight ? ", highlight" : ""}${isStrike ? ", strike" : ""}${isLink ? ", link=$linkUrl" : ""})';
}

/// Abstract base class for high-level semantic blocks.
abstract class PdfBlock {
  const PdfBlock();
}

/// A Markdown heading (# to ######) with styled inlines.
class PdfHeadingBlock extends PdfBlock {
  const PdfHeadingBlock({
    required this.level,
    required this.inlines,
  });

  final int level; // 1 to 6
  final List<PdfInlineRun> inlines;

  String get plainText => inlines.map((i) => i.text).join();
}

/// A standard paragraph of text containing styled inlines.
class PdfParagraphBlock extends PdfBlock {
  const PdfParagraphBlock({
    required this.inlines,
  });

  final List<PdfInlineRun> inlines;

  String get plainText => inlines.map((i) => i.text).join();
}

/// Single item within an unordered or ordered list.
class PdfListItem {
  const PdfListItem({
    required this.inlines,
    this.number,
    this.indentLevel = 0,
  });

  final List<PdfInlineRun> inlines;
  final int? number; // Non-null if ordered
  final int indentLevel;

  String get plainText => inlines.map((i) => i.text).join();
}

/// A list block containing bullet or numbered items.
class PdfListBlock extends PdfBlock {
  const PdfListBlock({
    required this.items,
    this.isOrdered = false,
  });

  final List<PdfListItem> items;
  final bool isOrdered;
}

/// Single item within a task checklist.
class PdfChecklistItem {
  const PdfChecklistItem({
    required this.isChecked,
    required this.inlines,
    this.indentLevel = 0,
  });

  final bool isChecked;
  final List<PdfInlineRun> inlines;
  final int indentLevel;

  String get plainText => inlines.map((i) => i.text).join();
}

/// A checklist block containing interactive/visual task checkboxes.
class PdfChecklistBlock extends PdfBlock {
  const PdfChecklistBlock({
    required this.items,
  });

  final List<PdfChecklistItem> items;
}

/// A blockquote containing styled inline runs or nested lines.
class PdfBlockquoteBlock extends PdfBlock {
  const PdfBlockquoteBlock({
    required this.inlines,
  });

  final List<PdfInlineRun> inlines;

  String get plainText => inlines.map((i) => i.text).join();
}

/// A fenced code block (```lang ... ```).
class PdfCodeBlock extends PdfBlock {
  const PdfCodeBlock({
    required this.code,
    this.language = '',
  });

  final String code;
  final String language;
}

/// A GitHub Flavored Markdown table.
class PdfTableBlock extends PdfBlock {
  const PdfTableBlock({
    required this.headers,
    required this.alignments,
    required this.rows,
  });

  final List<List<PdfInlineRun>> headers;
  final List<PdfTableCellAlignment> alignments;
  final List<List<List<PdfInlineRun>>> rows;
}

/// An embedded or linked image.
class PdfImageBlock extends PdfBlock {
  const PdfImageBlock({
    required this.uri,
    this.alt = '',
    this.bytes,
  });

  final String uri;
  final String alt;
  final Uint8List? bytes;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

/// A horizontal divider line (---, ***, ___).
class PdfHorizontalRuleBlock extends PdfBlock {
  const PdfHorizontalRuleBlock();
}
