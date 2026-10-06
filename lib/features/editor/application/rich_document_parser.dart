import 'package:uuid/uuid.dart';
import '../domain/rich_block.dart';
import '../domain/rich_document.dart';
import '../domain/rich_inline.dart';
import '../domain/text_attributes.dart';
import 'markdown_table_parser.dart';

const _uuid = Uuid();

/// Dedicated parser compiling Markdown into an authoritative [RichDocument].
///
/// Designed specifically for entering Visual mode and initializing the visual model.
/// Does not depend on editor controller state, Flutter widgets, or BuildContext.
class RichDocumentParser {
  const RichDocumentParser();

  static const _tableParser = MarkdownTableParser();

  /// Parses the canonical Markdown [source] into a structured [RichDocument].
  RichDocument parse(String source) {
    if (source.isEmpty) {
      return RichDocument.empty();
    }

    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final blocks = <RichBlock>[];

    var i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i];

      // 1. Fenced Code Block: ```lang ... ```
      if (line.trimLeft().startsWith('```') || line.trimLeft().startsWith('~~~')) {
        final fence = line.trimLeft().substring(0, 3);
        final lang = line.trimLeft().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < rawLines.length) {
          if (rawLines[i].trimLeft().startsWith(fence)) {
            i++;
            break;
          }
          codeLines.add(rawLines[i]);
          i++;
        }
        blocks.add(CodeBlock(
          id: _uuid.v4(),
          language: lang,
          code: codeLines.join('\n'),
        ));
        continue;
      }

      // 2. Markdown Table
      if (_isTableLine(line)) {
        // Collect candidate table lines
        final tableLines = <String>[];
        var tableIndex = i;
        while (tableIndex < rawLines.length && _isTableLine(rawLines[tableIndex])) {
          tableLines.add(rawLines[tableIndex]);
          tableIndex++;
        }

        final tableCandidate = tableLines.join('\n');
        final tables = _tableParser.findTables(tableCandidate);
        if (tables.isNotEmpty && tables.first.columnCount > 0) {
          blocks.add(TableBlock(
            id: _uuid.v4(),
            table: tables.first,
          ));
          i = tableIndex;
          continue;
        }
      }

      // 3. Horizontal Rule (---, ***, ___)
      if (_isHorizontalRule(line)) {
        blocks.add(HorizontalRuleBlock.create(_uuid.v4()));
        i++;
        continue;
      }

      // 4. Standalone Image: ![alt](url "title")
      final standaloneImage = _parseStandaloneImage(line);
      if (standaloneImage != null) {
        blocks.add(standaloneImage);
        i++;
        continue;
      }

      // 5. Heading: # to ######
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2) ?? '';
        blocks.add(HeadingBlock(
          id: _uuid.v4(),
          level: level,
          spans: parseInlines(text),
        ));
        i++;
        continue;
      }

      // 6. Checklist Item: - [ ] Task or - [x] Task
      final checklistMatch = RegExp(r'^(\s*)[-*+]\s+\[([ xX])\]\s*(.*)$').firstMatch(line);
      if (checklistMatch != null) {
        final isChecked = checklistMatch.group(2)!.toLowerCase() == 'x';
        final text = checklistMatch.group(3) ?? '';
        blocks.add(ChecklistItemBlock(
          id: _uuid.v4(),
          isChecked: isChecked,
          spans: parseInlines(text),
        ));
        i++;
        continue;
      }

      // 7. Bulleted List Item: - Item, * Item, + Item
      final bulletMatch = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final indentStr = bulletMatch.group(1) ?? '';
        final indent = (indentStr.length / 2).floor();
        final text = bulletMatch.group(2) ?? '';
        blocks.add(BulletedListItemBlock(
          id: _uuid.v4(),
          indent: indent,
          spans: parseInlines(text),
        ));
        i++;
        continue;
      }

      // 8. Ordered List Item: 1. Item
      final orderedMatch = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(line);
      if (orderedMatch != null) {
        final indentStr = orderedMatch.group(1) ?? '';
        final indent = (indentStr.length / 2).floor();
        final order = int.tryParse(orderedMatch.group(2) ?? '1') ?? 1;
        final text = orderedMatch.group(3) ?? '';
        blocks.add(OrderedListItemBlock(
          id: _uuid.v4(),
          order: order,
          indent: indent,
          spans: parseInlines(text),
        ));
        i++;
        continue;
      }

      // 9. Blockquote: > Quote
      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        final text = quoteMatch.group(1) ?? '';
        blocks.add(QuoteBlock(
          id: _uuid.v4(),
          spans: parseInlines(text),
        ));
        i++;
        continue;
      }

      // 10. Standard Paragraph (including empty line)
      blocks.add(ParagraphBlock(
        id: _uuid.v4(),
        spans: parseInlines(line),
      ));
      i++;
    }

    if (blocks.isEmpty) {
      return RichDocument.empty();
    }

    return RichDocument(blocks: blocks);
  }

  /// Parses inline formatting into a list of [RichInlineSpan] with [TextAttributes].
  static List<RichInlineSpan> parseInlines(String text) {
    if (text.isEmpty) {
      return const [RichInlineSpan(text: '')];
    }

    final spans = <RichInlineSpan>[];
    _parseInlineRange(text, 0, text.length, TextAttributes.none, spans);
    return spans.normalized();
  }

  static void _parseInlineRange(
    String text,
    int start,
    int end,
    TextAttributes currentAttr,
    List<RichInlineSpan> output,
  ) {
    var cursor = start;

    while (cursor < end) {
      // Find the next syntax match
      _InlineMatch? earliestMatch;

      // Check all supported inline syntaxes
      for (final matcher in _inlineMatchers) {
        final match = matcher(text, cursor, end);
        if (match != null) {
          if (earliestMatch == null || match.start < earliestMatch.start) {
            earliestMatch = match;
          }
        }
      }

      if (earliestMatch == null) {
        // No more markup in range: emit remainder as text
        if (cursor < end) {
          output.add(RichInlineSpan(
            text: text.substring(cursor, end),
            attributes: currentAttr,
          ));
        }
        break;
      }

      // Emit plain text preceding the match
      if (earliestMatch.start > cursor) {
        output.add(RichInlineSpan(
          text: text.substring(cursor, earliestMatch.start),
          attributes: currentAttr,
        ));
      }

      // Apply match attributes
      final newAttr = currentAttr.merge(earliestMatch.attributes);

      if (earliestMatch.isAtomic) {
        // Atomic text (e.g. inline code or link label where inner parsing is literal)
        output.add(RichInlineSpan(
          text: earliestMatch.content,
          attributes: newAttr,
        ));
      } else {
        // Nested inline parsing inside the matched content
        _parseInlineRange(
          text,
          earliestMatch.contentStart,
          earliestMatch.contentEnd,
          newAttr,
          output,
        );
      }

      cursor = earliestMatch.end;
    }
  }

  static bool _isTableLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length >= 2;
  }

  static bool _isHorizontalRule(String line) {
    final trimmed = line.trim();
    return RegExp(r'^(?:---|\*\*\*|___)$').hasMatch(trimmed);
  }

  static ImageBlock? _parseStandaloneImage(String line) {
    final trimmed = line.trim();
    final match = RegExp(r'^!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)$').firstMatch(trimmed);
    if (match != null) {
      return ImageBlock(
        id: _uuid.v4(),
        alt: match.group(1) ?? '',
        url: match.group(2) ?? '',
        title: match.group(3),
      );
    }
    return null;
  }

  static final List<_InlineMatcher> _inlineMatchers = [
    // Inline code: `code`
    (text, start, end) {
      final match = RegExp(r'`([^`\n]+)`').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 1,
          contentEnd: match.end - 1,
          content: match.group(1)!,
          attributes: const TextAttributes(isCode: true),
          isAtomic: true,
        );
      }
      return null;
    },

    // Note link: [[Title]]
    (text, start, end) {
      final match = RegExp(r'\[\[([^\]\n]+)\]\]').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        final target = match.group(1)!;
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 2,
          contentEnd: match.end - 2,
          content: target,
          attributes: TextAttributes(noteLinkTarget: target),
          isAtomic: true,
        );
      }
      return null;
    },

    // External link: [text](url)
    (text, start, end) {
      final match = RegExp(r'\[([^\]\n]+)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        final label = match.group(1)!;
        final url = match.group(2)!;
        final title = match.group(3);
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 1,
          contentEnd: match.start + 1 + label.length,
          content: label,
          attributes: TextAttributes(linkUrl: url, linkTitle: title),
          isAtomic: false,
        );
      }
      return null;
    },

    // Bold + Italic: ***text*** or ___text___
    (text, start, end) {
      final match = RegExp(r'(\*\*\*|___)(.+?)\1').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        final delim = match.group(1)!.length;
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + delim,
          contentEnd: match.end - delim,
          content: match.group(2)!,
          attributes: const TextAttributes(isBold: true, isItalic: true),
          isAtomic: false,
        );
      }
      return null;
    },

    // Bold: **text** or __text__
    (text, start, end) {
      final match = RegExp(r'(\*\*|__)(.+?)\1').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        final delim = match.group(1)!.length;
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + delim,
          contentEnd: match.end - delim,
          content: match.group(2)!,
          attributes: const TextAttributes(isBold: true),
          isAtomic: false,
        );
      }
      return null;
    },

    // Italic: *text* or _text_
    (text, start, end) {
      final match = RegExp(r'(\*|_)([^*\n_]+?)\1').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 1,
          contentEnd: match.end - 1,
          content: match.group(2)!,
          attributes: const TextAttributes(isItalic: true),
          isAtomic: false,
        );
      }
      return null;
    },

    // Strikethrough: ~~text~~
    (text, start, end) {
      final match = RegExp(r'~~([^~\n]+?)~~').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 2,
          contentEnd: match.end - 2,
          content: match.group(1)!,
          attributes: const TextAttributes(isStrike: true),
          isAtomic: false,
        );
      }
      return null;
    },

    // Highlight: ==text==
    (text, start, end) {
      final match = RegExp(r'==([^=\n]+?)==').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start + 2,
          contentEnd: match.end - 2,
          content: match.group(1)!,
          attributes: const TextAttributes(isHighlight: true),
          isAtomic: false,
        );
      }
      return null;
    },

    // Tag: #tag (word boundary or space, not heading)
    (text, start, end) {
      final match = RegExp(r'(?:^|(?<=\s))#([a-zA-Z0-9_\-]+)').allMatches(text, start).firstOrNull;
      if (match != null && match.end <= end) {
        final tagName = match.group(1)!;
        return _InlineMatch(
          start: match.start,
          end: match.end,
          contentStart: match.start,
          contentEnd: match.end,
          content: match.group(0)!,
          attributes: TextAttributes(tag: tagName),
          isAtomic: true,
        );
      }
      return null;
    },
  ];
}

typedef _InlineMatcher = _InlineMatch? Function(String text, int start, int end);

class _InlineMatch {
  final int start;
  final int end;
  final int contentStart;
  final int contentEnd;
  final String content;
  final TextAttributes attributes;
  final bool isAtomic;

  const _InlineMatch({
    required this.start,
    required this.end,
    required this.contentStart,
    required this.contentEnd,
    required this.content,
    required this.attributes,
    required this.isAtomic,
  });
}
