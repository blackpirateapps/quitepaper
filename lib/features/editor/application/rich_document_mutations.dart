import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../domain/document_selection.dart';
import '../domain/markdown_table.dart';
import '../domain/rich_block.dart';
import '../domain/rich_document.dart';
import '../domain/rich_inline.dart';
import '../domain/text_attributes.dart';
import 'markdown_table_formatter.dart';
import 'markdown_table_parser.dart';

const _uuid = Uuid();

/// Pure functional domain mutation engine for [RichDocument].
///
/// Every mutation produces an updated immutable [RichDocument] directly,
/// with zero reliance on Markdown source manipulation, hidden syntax tokens, or regex string-rewriting.
abstract final class RichDocumentMutations {
  static const _tableParser = MarkdownTableParser();

  // ===========================================================================
  // Inline Formatting Mutations
  // ===========================================================================

  /// Toggles bold formatting across [selection].
  static RichDocument toggleBold(RichDocument doc, RichDocumentSelection selection) =>
      _toggleInlineAttribute(
        doc,
        selection,
        hasAttr: (a) => a.isBold,
        applyAttr: (a, active) => a.copyWith(isBold: active),
      );

  /// Toggles italic formatting across [selection].
  static RichDocument toggleItalic(RichDocument doc, RichDocumentSelection selection) =>
      _toggleInlineAttribute(
        doc,
        selection,
        hasAttr: (a) => a.isItalic,
        applyAttr: (a, active) => a.copyWith(isItalic: active),
      );

  /// Toggles strikethrough formatting across [selection].
  static RichDocument toggleStrike(RichDocument doc, RichDocumentSelection selection) =>
      _toggleInlineAttribute(
        doc,
        selection,
        hasAttr: (a) => a.isStrike,
        applyAttr: (a, active) => a.copyWith(isStrike: active),
      );

  /// Toggles highlight background tint across [selection].
  static RichDocument toggleHighlight(RichDocument doc, RichDocumentSelection selection) =>
      _toggleInlineAttribute(
        doc,
        selection,
        hasAttr: (a) => a.isHighlight,
        applyAttr: (a, active) => a.copyWith(isHighlight: active),
      );

  /// Toggles inline code formatting across [selection].
  static RichDocument toggleCode(RichDocument doc, RichDocumentSelection selection) =>
      _toggleInlineAttribute(
        doc,
        selection,
        hasAttr: (a) => a.isCode,
        applyAttr: (a, active) => a.copyWith(isCode: active),
      );

  /// Applies or updates a hyperlink on [selection].
  static RichDocument applyLink(
    RichDocument doc,
    RichDocumentSelection selection, {
    required String url,
    String? title,
  }) {
    if (selection.isCollapsed) {
      final label = (title != null && title.isNotEmpty) ? title : url;
      return _insertSpanAtPosition(
        doc,
        selection.extent,
        RichInlineSpan(
          text: label,
          attributes: TextAttributes(linkUrl: url),
        ),
      );
    }
    return _applyAttributeRange(
      doc,
      selection,
      (a) => a.copyWith(linkUrl: url, linkTitle: title),
    );
  }

  /// Removes an active hyperlink across [selection].
  static RichDocument removeLink(RichDocument doc, RichDocumentSelection selection) {
    return _applyAttributeRange(
      doc,
      selection,
      (a) => a.copyWith(clearLink: true),
    );
  }

  /// Applies a wiki-style internal note link on [selection].
  static RichDocument applyNoteLink(
    RichDocument doc,
    RichDocumentSelection selection, {
    required String target,
  }) {
    if (selection.isCollapsed) {
      return _insertSpanAtPosition(
        doc,
        selection.extent,
        RichInlineSpan(
          text: target,
          attributes: TextAttributes(noteLinkTarget: target),
        ),
      );
    }
    return _applyAttributeRange(
      doc,
      selection,
      (a) => a.copyWith(noteLinkTarget: target),
    );
  }

  /// Applies a hashtag on [selection].
  static RichDocument applyTag(
    RichDocument doc,
    RichDocumentSelection selection, {
    required String tag,
  }) {
    final normalized = tag.startsWith('#') ? tag.substring(1) : tag;
    if (selection.isCollapsed) {
      return _insertSpanAtPosition(
        doc,
        selection.extent,
        RichInlineSpan(
          text: '#$normalized',
          attributes: TextAttributes(tag: normalized),
        ),
      );
    }
    return _applyAttributeRange(
      doc,
      selection,
      (a) => a.copyWith(tag: normalized),
    );
  }

  // ===========================================================================
  // Block Structural Transformations
  // ===========================================================================

  /// Converts the block at [blockIndex] to a [HeadingBlock] of [level] (1..6).
  static RichDocument setHeadingLevel(RichDocument doc, int blockIndex, int level) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is! HeadingBlock && !block.isTextBlock) return doc;

    final spans = block.spans;
    final updatedBlock = HeadingBlock(
      id: block.id,
      level: level.clamp(1, 6),
      spans: spans,
    );

    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = updatedBlock;
    return doc.copyWith(blocks: newBlocks);
  }

  /// Converts the block at [blockIndex] to a standard [ParagraphBlock].
  static RichDocument convertToParagraph(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];

    final spans = block.isTextBlock ? block.spans : [RichInlineSpan(text: block.plainText)];
    final updatedBlock = ParagraphBlock(
      id: block.id,
      spans: spans,
    );

    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = updatedBlock;
    return doc.copyWith(blocks: newBlocks);
  }

  /// Cycles heading level: Paragraph -> H1 -> H2 -> H3 -> Paragraph.
  static RichDocument cycleHeading(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is HeadingBlock) {
      if (block.level >= 3) {
        return convertToParagraph(doc, blockIndex);
      } else {
        return setHeadingLevel(doc, blockIndex, block.level + 1);
      }
    } else {
      return setHeadingLevel(doc, blockIndex, 1);
    }
  }

  /// Toggles checklist task formatting on the block at [blockIndex].
  static RichDocument toggleChecklist(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is ChecklistItemBlock) {
      return convertToParagraph(doc, blockIndex);
    }

    final spans = block.isTextBlock ? block.spans : [RichInlineSpan(text: block.plainText)];
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = ChecklistItemBlock(
      id: block.id,
      isChecked: false,
      spans: spans,
    );
    return doc.copyWith(blocks: newBlocks);
  }

  /// Toggles the checked status of a [ChecklistItemBlock] by block ID or index.
  static RichDocument toggleChecklistItemChecked(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is! ChecklistItemBlock) return doc;

    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = block.copyWith(isChecked: !block.isChecked);
    return doc.copyWith(blocks: newBlocks);
  }

  /// Toggles bulleted list formatting on the block at [blockIndex].
  static RichDocument toggleBulletedList(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is BulletedListItemBlock) {
      return convertToParagraph(doc, blockIndex);
    }

    final spans = block.isTextBlock ? block.spans : [RichInlineSpan(text: block.plainText)];
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = BulletedListItemBlock(
      id: block.id,
      indent: 0,
      spans: spans,
    );
    return doc.copyWith(blocks: newBlocks);
  }

  /// Toggles numbered ordered list formatting on the block at [blockIndex].
  static RichDocument toggleOrderedList(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is OrderedListItemBlock) {
      return convertToParagraph(doc, blockIndex);
    }

    // Determine correct order number based on preceding block
    var order = 1;
    if (blockIndex > 0 && doc.blocks[blockIndex - 1] is OrderedListItemBlock) {
      order = (doc.blocks[blockIndex - 1] as OrderedListItemBlock).order + 1;
    }

    final spans = block.isTextBlock ? block.spans : [RichInlineSpan(text: block.plainText)];
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = OrderedListItemBlock(
      id: block.id,
      order: order,
      indent: 0,
      spans: spans,
    );
    return doc.copyWith(blocks: newBlocks);
  }

  /// Toggles quote formatting on the block at [blockIndex].
  static RichDocument toggleQuote(RichDocument doc, int blockIndex) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is QuoteBlock) {
      return convertToParagraph(doc, blockIndex);
    }

    final spans = block.isTextBlock ? block.spans : [RichInlineSpan(text: block.plainText)];
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = QuoteBlock(
      id: block.id,
      spans: spans,
    );
    return doc.copyWith(blocks: newBlocks);
  }

  /// Inserts a [HorizontalRuleBlock] below [blockIndex].
  static RichDocument insertHorizontalRule(RichDocument doc, int blockIndex) {
    final insertIdx = (blockIndex + 1).clamp(0, doc.blocks.length);
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks.insert(insertIdx, HorizontalRuleBlock.create(_uuid.v4()));
    if (insertIdx == newBlocks.length - 1) {
      newBlocks.add(ParagraphBlock.empty(_uuid.v4()));
    }
    return doc.copyWith(blocks: newBlocks);
  }

  /// Inserts a new [TableBlock] with [rows] and [cols] below [blockIndex].
  static RichDocument insertTable(
    RichDocument doc,
    int blockIndex, {
    int rows = 3,
    int cols = 3,
  }) {
    // Generate valid Markdown pipe table candidate and parse into MarkdownTable model
    final initialValue = MarkdownTableFormatter.insertTable(
      value: const TextEditingValue(text: ''),
      rows: rows,
      columns: cols,
    );
    final tables = _tableParser.findTables(initialValue.text);
    if (tables.isEmpty) return doc;

    final insertIdx = (blockIndex + 1).clamp(0, doc.blocks.length);
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks.insert(insertIdx, TableBlock(id: _uuid.v4(), table: tables.first));
    if (insertIdx == newBlocks.length - 1) {
      newBlocks.add(ParagraphBlock.empty(_uuid.v4()));
    }
    return doc.copyWith(blocks: newBlocks);
  }

  /// Replaces the [MarkdownTable] of the [TableBlock] at [blockIndex] in place,
  /// preserving the block id. Used by inline table editing to write cell/row/
  /// column edits back into the document without recreating the block.
  static RichDocument updateTable(
    RichDocument doc,
    int blockIndex,
    MarkdownTable newTable,
  ) {
    if (blockIndex < 0 || blockIndex >= doc.blocks.length) return doc;
    final block = doc.blocks[blockIndex];
    if (block is! TableBlock) return doc;
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = TableBlock(id: block.id, table: newTable);
    return doc.copyWith(blocks: newBlocks);
  }

  /// Inserts a [CodeBlock] with [language] and [code] below [blockIndex].
  static RichDocument insertCodeBlock(
    RichDocument doc,
    int blockIndex, {
    String language = '',
    String code = '',
  }) {
    final insertIdx = (blockIndex + 1).clamp(0, doc.blocks.length);
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks.insert(
      insertIdx,
      CodeBlock(id: _uuid.v4(), language: language, code: code),
    );
    if (insertIdx == newBlocks.length - 1) {
      newBlocks.add(ParagraphBlock.empty(_uuid.v4()));
    }
    return doc.copyWith(blocks: newBlocks);
  }

  /// Inserts an [ImageBlock] with [path] and [alt] below [blockIndex].
  static RichDocument insertImage(
    RichDocument doc,
    int blockIndex, {
    required String path,
    String alt = '',
  }) {
    final insertIdx = (blockIndex + 1).clamp(0, doc.blocks.length);
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks.insert(
      insertIdx,
      ImageBlock(id: _uuid.v4(), url: path, alt: alt),
    );
    if (insertIdx == newBlocks.length - 1) {
      newBlocks.add(ParagraphBlock.empty(_uuid.v4()));
    }
    return doc.copyWith(blocks: newBlocks);
  }

  // ===========================================================================
  // Enter & Backspace Key Interactions
  // ===========================================================================

  /// Executes smart Enter key behavior at [position].
  ///
  /// Returns a record with the updated [RichDocument] and resulting [RichDocumentPosition].
  static (RichDocument, RichDocumentPosition) handleEnter(
    RichDocument doc,
    RichDocumentPosition position,
  ) {
    if (doc.blocks.isEmpty) {
      final newDoc = RichDocument.empty();
      return (newDoc, const RichDocumentPosition(blockIndex: 0, blockId: '', offset: 0));
    }

    final blockIndex = position.blockIndex.clamp(0, doc.blocks.length - 1);
    final block = doc.blocks[blockIndex];

    // If on a non-text block (e.g. HorizontalRule, Table, CodeBlock), insert paragraph below
    if (!block.isTextBlock) {
      final newBlock = ParagraphBlock.empty(_uuid.v4());
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    final offset = position.offset.clamp(0, block.plainText.length);
    final isEmpty = block.plainText.trim().isEmpty;

    // 1. Checklist Item
    if (block is ChecklistItemBlock) {
      if (isEmpty) {
        // Empty checklist item -> exit checklist into a paragraph
        final updatedDoc = convertToParagraph(doc, blockIndex);
        return (
          updatedDoc,
          RichDocumentPosition(blockIndex: blockIndex, blockId: block.id, offset: 0)
        );
      }
      // Non-empty checklist item -> split or create new unchecked checklist item below
      final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
      final newBlock = ChecklistItemBlock(
        id: _uuid.v4(),
        isChecked: false,
        spans: rightSpans,
      );
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex] = block.copyWith(spans: leftSpans);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    // 2. Bulleted List Item
    if (block is BulletedListItemBlock) {
      if (isEmpty) {
        // Empty bullet -> exit list into a paragraph
        final updatedDoc = convertToParagraph(doc, blockIndex);
        return (
          updatedDoc,
          RichDocumentPosition(blockIndex: blockIndex, blockId: block.id, offset: 0)
        );
      }
      final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
      final newBlock = BulletedListItemBlock(
        id: _uuid.v4(),
        indent: block.indent,
        spans: rightSpans,
      );
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex] = block.copyWith(spans: leftSpans);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    // 3. Ordered List Item
    if (block is OrderedListItemBlock) {
      if (isEmpty) {
        // Empty ordered item -> exit list into a paragraph
        final updatedDoc = convertToParagraph(doc, blockIndex);
        return (
          updatedDoc,
          RichDocumentPosition(blockIndex: blockIndex, blockId: block.id, offset: 0)
        );
      }
      final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
      final newBlock = OrderedListItemBlock(
        id: _uuid.v4(),
        order: block.order + 1,
        indent: block.indent,
        spans: rightSpans,
      );
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex] = block.copyWith(spans: leftSpans);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    // 4. Quote
    if (block is QuoteBlock) {
      if (isEmpty) {
        // Empty quote -> exit quote into a paragraph
        final updatedDoc = convertToParagraph(doc, blockIndex);
        return (
          updatedDoc,
          RichDocumentPosition(blockIndex: blockIndex, blockId: block.id, offset: 0)
        );
      }
      final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
      final newBlock = QuoteBlock(
        id: _uuid.v4(),
        spans: rightSpans,
      );
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex] = block.copyWith(spans: leftSpans);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    // 5. Heading -> Pressing Enter in a Heading creates a Paragraph below
    if (block is HeadingBlock) {
      final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
      final newBlock = ParagraphBlock(
        id: _uuid.v4(),
        spans: rightSpans,
      );
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex] = block.copyWith(spans: leftSpans);
      newBlocks.insert(blockIndex + 1, newBlock);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
      );
    }

    // 6. Standard Paragraph -> Split into two paragraphs
    final (leftSpans, rightSpans) = _splitSpansAtOffset(block.spans, offset);
    final newBlock = ParagraphBlock(
      id: _uuid.v4(),
      spans: rightSpans,
    );
    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[blockIndex] = ParagraphBlock(id: block.id, spans: leftSpans);
    newBlocks.insert(blockIndex + 1, newBlock);
    return (
      doc.copyWith(blocks: newBlocks),
      RichDocumentPosition(blockIndex: blockIndex + 1, blockId: newBlock.id, offset: 0)
    );
  }

  /// Executes smart Backspace behavior at offset 0 of [position].
  ///
  /// Returns a record with updated [RichDocument] and resulting [RichDocumentPosition].
  static (RichDocument, RichDocumentPosition) handleBackspaceAtStart(
    RichDocument doc,
    RichDocumentPosition position,
  ) {
    if (doc.blocks.isEmpty) {
      return (doc, position);
    }

    final blockIndex = position.blockIndex.clamp(0, doc.blocks.length - 1);
    final block = doc.blocks[blockIndex];

    // If not a text block, or offset is not 0, backspace doesn't perform block-level conversion
    if (!block.isTextBlock || position.offset != 0) {
      return (doc, position);
    }

    // 1. If in a Heading, Checklist, List, or Quote at offset 0: convert to standard Paragraph
    if (block is HeadingBlock ||
        block is ChecklistItemBlock ||
        block is BulletedListItemBlock ||
        block is OrderedListItemBlock ||
        block is QuoteBlock) {
      final updatedDoc = convertToParagraph(doc, blockIndex);
      return (
        updatedDoc,
        RichDocumentPosition(blockIndex: blockIndex, blockId: block.id, offset: 0)
      );
    }

    // 2. If at index 0 of the first block, nothing to merge
    if (blockIndex == 0) {
      return (doc, position);
    }

    // 3. Merge paragraph into preceding block if preceding block is a text block
    final prevBlock = doc.blocks[blockIndex - 1];
    if (prevBlock.isTextBlock) {
      final prevLength = prevBlock.plainText.length;
      final mergedSpans = [...prevBlock.spans, ...block.spans].normalized();

      RichBlock updatedPrev;
      if (prevBlock is HeadingBlock) {
        updatedPrev = prevBlock.copyWith(spans: mergedSpans);
      } else if (prevBlock is ChecklistItemBlock) {
        updatedPrev = prevBlock.copyWith(spans: mergedSpans);
      } else if (prevBlock is BulletedListItemBlock) {
        updatedPrev = prevBlock.copyWith(spans: mergedSpans);
      } else if (prevBlock is OrderedListItemBlock) {
        updatedPrev = prevBlock.copyWith(spans: mergedSpans);
      } else if (prevBlock is QuoteBlock) {
        updatedPrev = prevBlock.copyWith(spans: mergedSpans);
      } else {
        updatedPrev = ParagraphBlock(id: prevBlock.id, spans: mergedSpans);
      }

      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[blockIndex - 1] = updatedPrev;
      newBlocks.removeAt(blockIndex);

      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(
          blockIndex: blockIndex - 1,
          blockId: prevBlock.id,
          offset: prevLength,
        )
      );
    } else {
      // Preceding block is non-text (e.g. divider, image): delete that non-text block
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks.removeAt(blockIndex - 1);
      return (
        doc.copyWith(blocks: newBlocks),
        RichDocumentPosition(
          blockIndex: blockIndex - 1,
          blockId: block.id,
          offset: 0,
        )
      );
    }
  }

  // ===========================================================================
  // Internal Helpers
  // ===========================================================================

  static RichDocument _toggleInlineAttribute(
    RichDocument doc,
    RichDocumentSelection selection, {
    required bool Function(TextAttributes) hasAttr,
    required TextAttributes Function(TextAttributes, bool) applyAttr,
  }) {
    if (doc.blocks.isEmpty) return doc;

    final start = selection.start;
    final end = selection.end;

    // Check if the attribute is already active across the selection
    var allActive = true;
    for (var bi = start.blockIndex; bi <= end.blockIndex; bi++) {
      if (bi < 0 || bi >= doc.blocks.length) continue;
      final block = doc.blocks[bi];
      if (!block.isTextBlock) continue;

      final rangeStart = (bi == start.blockIndex) ? start.offset : 0;
      final rangeEnd = (bi == end.blockIndex) ? end.offset : block.plainText.length;

      var currentOffset = 0;
      for (final span in block.spans) {
        final spanEnd = currentOffset + span.length;
        if (spanEnd > rangeStart && currentOffset < rangeEnd) {
          if (!hasAttr(span.attributes)) {
            allActive = false;
            break;
          }
        }
        currentOffset = spanEnd;
      }
      if (!allActive) break;
    }

    final targetState = !allActive;

    return _applyAttributeRange(
      doc,
      selection,
      (a) => applyAttr(a, targetState),
    );
  }

  static RichDocument _applyAttributeRange(
    RichDocument doc,
    RichDocumentSelection selection,
    TextAttributes Function(TextAttributes) transformAttr,
  ) {
    if (doc.blocks.isEmpty) return doc;

    final start = selection.start;
    final end = selection.end;
    final newBlocks = List<RichBlock>.from(doc.blocks);

    for (var bi = start.blockIndex; bi <= end.blockIndex; bi++) {
      if (bi < 0 || bi >= newBlocks.length) continue;
      final block = newBlocks[bi];
      if (!block.isTextBlock) continue;

      final rangeStart = (bi == start.blockIndex) ? start.offset : 0;
      final rangeEnd = (bi == end.blockIndex) ? end.offset : block.plainText.length;

      final updatedSpans = _transformSpansInRange(
        block.spans,
        rangeStart,
        rangeEnd,
        transformAttr,
      );

      if (block is ParagraphBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      } else if (block is HeadingBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      } else if (block is ChecklistItemBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      } else if (block is BulletedListItemBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      } else if (block is OrderedListItemBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      } else if (block is QuoteBlock) {
        newBlocks[bi] = block.copyWith(spans: updatedSpans);
      }
    }

    return doc.copyWith(blocks: newBlocks);
  }

  static List<RichInlineSpan> _transformSpansInRange(
    List<RichInlineSpan> spans,
    int rangeStart,
    int rangeEnd,
    TextAttributes Function(TextAttributes) transform,
  ) {
    final result = <RichInlineSpan>[];
    var currentOffset = 0;

    for (final span in spans) {
      final spanStart = currentOffset;
      final spanEnd = currentOffset + span.length;

      if (spanEnd <= rangeStart || spanStart >= rangeEnd) {
        // Completely outside range
        result.add(span);
      } else if (spanStart >= rangeStart && spanEnd <= rangeEnd) {
        // Completely inside range
        result.add(span.copyWith(attributes: transform(span.attributes)));
      } else {
        // Partially overlaps range: split into prefix, middle, suffix
        final overlapStart = spanStart < rangeStart ? rangeStart : spanStart;
        final overlapEnd = spanEnd > rangeEnd ? rangeEnd : spanEnd;

        // Prefix
        if (spanStart < overlapStart) {
          result.add(span.slice(0, overlapStart - spanStart));
        }

        // Middle (transformed)
        result.add(RichInlineSpan(
          text: span.text.substring(overlapStart - spanStart, overlapEnd - spanStart),
          attributes: transform(span.attributes),
        ));

        // Suffix
        if (spanEnd > overlapEnd) {
          result.add(span.slice(overlapEnd - spanStart));
        }
      }

      currentOffset = spanEnd;
    }

    return result.normalized();
  }

  static (List<RichInlineSpan>, List<RichInlineSpan>) _splitSpansAtOffset(
    List<RichInlineSpan> spans,
    int splitOffset,
  ) {
    final left = <RichInlineSpan>[];
    final right = <RichInlineSpan>[];
    var currentOffset = 0;

    for (final span in spans) {
      final spanStart = currentOffset;
      final spanEnd = currentOffset + span.length;

      if (spanEnd <= splitOffset) {
        left.add(span);
      } else if (spanStart >= splitOffset) {
        right.add(span);
      } else {
        // Split this span
        final localSplit = splitOffset - spanStart;
        left.add(span.slice(0, localSplit));
        right.add(span.slice(localSplit));
      }

      currentOffset = spanEnd;
    }

    return (left.normalized(), right.normalized());
  }

  static RichDocument _insertSpanAtPosition(
    RichDocument doc,
    RichDocumentPosition pos,
    RichInlineSpan spanToInsert,
  ) {
    if (doc.blocks.isEmpty) return doc;
    final bi = pos.blockIndex.clamp(0, doc.blocks.length - 1);
    final block = doc.blocks[bi];
    if (!block.isTextBlock) return doc;

    final offset = pos.offset.clamp(0, block.plainText.length);
    final (left, right) = _splitSpansAtOffset(block.spans, offset);
    final newSpans = [...left, spanToInsert, ...right].normalized();

    final newBlocks = List<RichBlock>.from(doc.blocks);
    if (block is ParagraphBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    } else if (block is HeadingBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    } else if (block is ChecklistItemBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    } else if (block is BulletedListItemBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    } else if (block is OrderedListItemBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    } else if (block is QuoteBlock) {
      newBlocks[bi] = block.copyWith(spans: newSpans);
    }

    return doc.copyWith(blocks: newBlocks);
  }
}
