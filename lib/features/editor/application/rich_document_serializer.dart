import '../domain/markdown_table.dart';
import '../domain/markdown_table_alignment.dart';
import '../domain/rich_block.dart';
import '../domain/rich_document.dart';
import '../domain/rich_inline.dart';

/// Dedicated serializer compiling an authoritative [RichDocument] into canonical Markdown.
///
/// Deterministic and idempotent: equivalent document models produce consistent Markdown.
/// Does not leak editor-local state, internal block IDs, or UI metadata into Markdown output.
class RichDocumentSerializer {
  const RichDocumentSerializer();

  /// Serializes [document] into canonical Markdown text.
  String serialize(RichDocument document) {
    if (document.blocks.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();

    for (var i = 0; i < document.blocks.length; i++) {
      final block = document.blocks[i];
      final serializedBlock = _serializeBlock(block);
      buffer.write(serializedBlock);

      if (i < document.blocks.length - 1) {
        buffer.write('\n');
      }
    }

    return buffer.toString();
  }

  String _serializeBlock(RichBlock block) {
    if (block is HeadingBlock) {
      final prefix = '#' * block.level;
      final text = serializeInlines(block.spans);
      return '$prefix $text';
    }

    if (block is ChecklistItemBlock) {
      final mark = block.isChecked ? 'x' : ' ';
      final text = serializeInlines(block.spans);
      return '- [$mark] $text';
    }

    if (block is BulletedListItemBlock) {
      final indent = '  ' * block.indent;
      final text = serializeInlines(block.spans);
      return '$indent- $text';
    }

    if (block is OrderedListItemBlock) {
      final indent = '  ' * block.indent;
      final text = serializeInlines(block.spans);
      return '$indent${block.order}. $text';
    }

    if (block is QuoteBlock) {
      final text = serializeInlines(block.spans);
      return '> $text';
    }

    if (block is CodeBlock) {
      final lang = block.language.trim();
      final code = block.code;
      final codeNormalized = code.endsWith('\n') ? code : '$code\n';
      return '```$lang\n$codeNormalized```';
    }

    if (block is HorizontalRuleBlock) {
      return '---';
    }

    if (block is ImageBlock) {
      final titleAttr = block.title != null && block.title!.isNotEmpty
          ? ' "${block.title}"'
          : '';
      return '![${block.alt}](${block.url}$titleAttr)';
    }

    if (block is TableBlock) {
      return formatTable(block.table);
    }

    if (block is ParagraphBlock) {
      return serializeInlines(block.spans);
    }

    return block.plainText;
  }

  /// Serializes a list of [RichInlineSpan] with [TextAttributes] to formatted Markdown.
  static String serializeInlines(List<RichInlineSpan> spans) {
    final buffer = StringBuffer();
    for (final span in spans) {
      buffer.write(_serializeSpan(span));
    }
    return buffer.toString();
  }

  static String _serializeSpan(RichInlineSpan span) {
    var text = span.text;
    final attr = span.attributes;

    if (attr.isEmpty || text.isEmpty) {
      return text;
    }

    // 1. Inline code: literal delimiters
    if (attr.isCode) {
      return '`$text`';
    }

    // 2. Note Link: [[Target]]
    if (attr.hasNoteLink) {
      return '[[$text]]';
    }

    // 3. Tag: #tag
    if (attr.hasTag) {
      return text.startsWith('#') ? text : '#$text';
    }

    // 4. External link: [text](url)
    if (attr.hasLink) {
      final titleAttr = attr.linkTitle != null && attr.linkTitle!.isNotEmpty
          ? ' "${attr.linkTitle}"'
          : '';
      text = '[$text](${attr.linkUrl}$titleAttr)';
    }

    // 5. Highlight: ==text==
    if (attr.isHighlight) {
      text = '==$text==';
    }

    // 6. Strikethrough: ~~text~~
    if (attr.isStrike) {
      text = '~~$text~~';
    }

    // 7. Bold & Italic composability
    if (attr.isBold && attr.isItalic) {
      text = '***$text***';
    } else if (attr.isBold) {
      text = '**$text**';
    } else if (attr.isItalic) {
      text = '*$text*';
    }

    return text;
  }

  /// Formats a [MarkdownTable] data model into canonical Markdown pipe table text.
  static String formatTable(MarkdownTable table) {
    final sb = StringBuffer();
    // Header row
    final headerCells = table.headerRow.cells.map((c) => ' ${c.trimmedText} ').join('|');
    sb.writeln('|$headerCells|');
    // Delimiter row with alignments
    final delimCells = List.generate(table.columnCount, (col) {
      final align = table.getAlignment(col);
      switch (align) {
        case MarkdownTableAlignment.left:
          return ' :--- ';
        case MarkdownTableAlignment.right:
          return ' ---: ';
        case MarkdownTableAlignment.center:
          return ' :---: ';
        case MarkdownTableAlignment.none:
          return ' --- ';
      }
    }).join('|');
    sb.writeln('|$delimCells|');
    // Body rows
    for (var r = 0; r < table.bodyRows.length; r++) {
      final row = table.bodyRows[r];
      final bodyCells = row.cells.map((c) => ' ${c.trimmedText} ').join('|');
      sb.write('|$bodyCells|');
      if (r < table.bodyRows.length - 1) {
        sb.writeln();
      }
    }
    return sb.toString();
  }
}
