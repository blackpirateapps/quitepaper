import 'dart:math';
import '../domain/document_position.dart';
import '../domain/semantic_document.dart';
import '../domain/semantic_nodes.dart';
import 'semantic_markdown_parser.dart';

/// Encapsulates the result of a surgical semantic mutation on canonical Markdown.
class MutationResult {
  const MutationResult({
    required this.markdown,
    required this.document,
    required this.position,
    this.selection,
  });

  /// The updated canonical Markdown string.
  final String markdown;

  /// The freshly parsed [SemanticDocument].
  final SemanticDocument document;

  /// The resulting logical cursor position after mutation.
  final DocumentPosition position;

  /// Optional resulting selection after mutation.
  final DocumentSelection? selection;
}

/// Centralized service executing surgical mutations on canonical Markdown
/// while preserving exact document invariants and non-mutated content.
class SemanticMutationService {
  const SemanticMutationService();

  /// Inserts [text] at [position].
  static MutationResult insertText(
    String markdown,
    DocumentPosition position,
    String text,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final sourceOffset = doc.sourceOffsetAtPosition(position);

    final actualText = (text == '\n' && sourceOffset == markdown.length && !markdown.endsWith('\n'))
        ? '\n\n'
        : text;
    final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, actualText);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newOffset = sourceOffset + actualText.length;
    final newPosition = newDoc.findPositionAtSourceOffset(newOffset) ??
        DocumentPosition(blockId: position.blockId, offset: position.offset + actualText.length);

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPosition,
      selection: DocumentSelection.collapsed(newPosition),
    );
  }

  /// Deletes a selection or single character at [selection].
  static MutationResult deleteSelection(
    String markdown,
    DocumentSelection selection, {
    bool isBackspace = true,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);

    if (!selection.isCollapsed) {
      final range = doc.sourceRangeAtSelection(selection);
      final newMarkdown = markdown.replaceRange(range.start, range.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(range.start) ??
          DocumentPosition(blockId: selection.start.blockId, offset: selection.start.offset);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    // Collapsed selection: backspace or delete single character
    final pos = selection.base;
    if (isBackspace && pos.offset == 0) {
      // Merge with previous block or clear block prefix
      return mergeWithPreviousBlock(markdown, pos);
    }

    final sourceOffset = doc.sourceOffsetAtPosition(pos);
    if (isBackspace) {
      if (sourceOffset <= 0) {
        return MutationResult(markdown: markdown, document: doc, position: pos);
      }
      final newMarkdown = markdown.replaceRange(sourceOffset - 1, sourceOffset, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset - 1) ??
          DocumentPosition(blockId: pos.blockId, offset: max(0, pos.offset - 1));

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    } else {
      if (sourceOffset >= markdown.length) {
        return MutationResult(markdown: markdown, document: doc, position: pos);
      }
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset + 1, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset) ?? pos;

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }
  }

  /// Handles Enter key press: splits block or creates next list/checklist item.
  static MutationResult splitBlock(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);

    if (block == null) {
      return insertText(markdown, position, '\n');
    }

    if (block is ChecklistItemBlock) {
      if (block.plainText.trim().isEmpty) {
        // Empty checklist item -> exit checklist by clearing marker to normal paragraph
        final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      // Non-empty checklist item -> insert new uncompleted checklist item on new line
      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final insertion = '\n$indent- [ ] ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset + insertion.length) ??
          DocumentPosition(blockId: position.blockId, offset: 0);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    if (block is ListItemBlock) {
      if (block.plainText.trim().isEmpty) {
        // Empty list item -> exit list
        final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final insertion = '\n$indent${block.marker} ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset + insertion.length) ??
          DocumentPosition(blockId: position.blockId, offset: 0);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    if (block is OrderedListItemBlock) {
      if (block.plainText.trim().isEmpty) {
        // Empty ordered list item -> exit list
        final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final nextNum = block.number + 1;
      final insertion = '\n$indent$nextNum${block.delimiter} ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset + insertion.length) ??
          DocumentPosition(blockId: position.blockId, offset: 0);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    if (block is QuoteBlock) {
      if (block.plainText.trim().isEmpty) {
        // Empty quote -> exit quote
        final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      const insertion = '\n> ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset + insertion.length) ??
          DocumentPosition(blockId: position.blockId, offset: 0);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    if (block is HeadingBlock) {
      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final isAtEnd = position.offset >= block.plainText.length;
      final insertion = (isAtEnd && sourceOffset == markdown.length && !markdown.endsWith('\n'))
          ? '\n\n'
          : '\n';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(sourceOffset + insertion.length) ??
          DocumentPosition(blockId: position.blockId, offset: 0);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    // Paragraph / other block splitting
    return insertText(markdown, position, '\n');
  }

  /// Merges block at [position] with previous block or clears list/checklist/quote prefix.
  static MutationResult mergeWithPreviousBlock(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) {
      return MutationResult(
        markdown: markdown,
        document: doc,
        position: position,
      );
    }

    // 1. If in a checklist, list, or quote at offset 0, convert to normal paragraph
    if (block is ChecklistItemBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.boxRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is ListItemBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is OrderedListItemBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is QuoteBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is HeadingBlock) {
      // Convert heading to paragraph (remove `# `)
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // 2. Merge with preceding block across newline
    final blockIndex = doc.findBlockIndexById(block.id);
    if (blockIndex > 0) {
      final prevBlock = doc.blocks[blockIndex - 1];
      final prevBlockEnd = prevBlock.sourceRange.end;
      // Delete the newline delimiter separating the two blocks
      final newlineOffset = prevBlockEnd > 0 && markdown[prevBlockEnd - 1] == '\n'
          ? prevBlockEnd - 1
          : block.sourceRange.start - 1;

      if (newlineOffset >= 0 && newlineOffset < markdown.length) {
        final newMarkdown = markdown.replaceRange(newlineOffset, newlineOffset + 1, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown);
        final newPos = newDoc.findPositionAtSourceOffset(newlineOffset) ??
            DocumentPosition(blockId: prevBlock.id, offset: prevBlock.plainText.length);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }
    }

    return MutationResult(markdown: markdown, document: doc, position: position);
  }

  /// Toggles bold (**text**) formatting on [selection].
  static MutationResult toggleBold(String markdown, DocumentSelection selection) {
    return _toggleInlineDelimiter(markdown, selection, '**');
  }

  /// Toggles italic (*text*) formatting on [selection].
  static MutationResult toggleItalic(String markdown, DocumentSelection selection) {
    return _toggleInlineDelimiter(markdown, selection, '*');
  }

  /// Toggles strikethrough (~~text~~) formatting on [selection].
  static MutationResult toggleStrike(String markdown, DocumentSelection selection) {
    return _toggleInlineDelimiter(markdown, selection, '~~');
  }

  /// Toggles highlight (==text==) formatting on [selection].
  static MutationResult toggleHighlight(String markdown, DocumentSelection selection) {
    return _toggleInlineDelimiter(markdown, selection, '==');
  }

  /// Toggles inline code (`code`) formatting on [selection].
  static MutationResult toggleInlineCode(String markdown, DocumentSelection selection) {
    return _toggleInlineDelimiter(markdown, selection, '`');
  }

  /// Internal helper to toggle an inline formatting delimiter around [selection].
  static MutationResult _toggleInlineDelimiter(
    String markdown,
    DocumentSelection selection,
    String delimiter,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final range = doc.sourceRangeAtSelection(selection);

    if (selection.isCollapsed) {
      // Collapsed: insert pair of delimiters and place cursor inside
      final offset = range.start;
      final insertion = '$delimiter$delimiter';
      final newMarkdown = markdown.replaceRange(offset, offset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final targetOffset = offset + delimiter.length;
      final newPos = newDoc.findPositionAtSourceOffset(targetOffset) ??
          DocumentPosition(blockId: selection.base.blockId, offset: selection.base.offset);

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newPos,
        selection: DocumentSelection.collapsed(newPos),
      );
    }

    final selectedText = range.slice(markdown);
    final dLen = delimiter.length;

    // Check if selection is already wrapped with this delimiter
    if (selectedText.startsWith(delimiter) &&
        selectedText.endsWith(delimiter) &&
        selectedText.length >= dLen * 2) {
      // Unwrap
      final unwrapped = selectedText.substring(dLen, selectedText.length - dLen);
      final newMarkdown = markdown.replaceRange(range.start, range.end, unwrapped);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newStartPos = newDoc.findPositionAtSourceOffset(range.start) ?? selection.start;
      final newEndPos = newDoc.findPositionAtSourceOffset(range.start + unwrapped.length) ?? selection.end;

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newEndPos,
        selection: DocumentSelection(base: newStartPos, extent: newEndPos),
      );
    }

    // Check if range is surrounded immediately by delimiter in source
    if (range.start >= dLen &&
        range.end + dLen <= markdown.length &&
        markdown.substring(range.start - dLen, range.start) == delimiter &&
        markdown.substring(range.end, range.end + dLen) == delimiter) {
      // Unwrap outer delimiters
      final newMarkdown = markdown.replaceRange(range.end, range.end + dLen, '').replaceRange(range.start - dLen, range.start, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newStartPos = newDoc.findPositionAtSourceOffset(range.start - dLen) ?? selection.start;
      final newEndPos = newDoc.findPositionAtSourceOffset(range.end - dLen) ?? selection.end;

      return MutationResult(
        markdown: newMarkdown,
        document: newDoc,
        position: newEndPos,
        selection: DocumentSelection(base: newStartPos, extent: newEndPos),
      );
    }

    // Wrap with delimiter
    final wrapped = '$delimiter$selectedText$delimiter';
    final newMarkdown = markdown.replaceRange(range.start, range.end, wrapped);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newStartPos = newDoc.findPositionAtSourceOffset(range.start + dLen) ?? selection.start;
    final newEndPos = newDoc.findPositionAtSourceOffset(range.start + dLen + selectedText.length) ?? selection.end;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newEndPos,
      selection: DocumentSelection(base: newStartPos, extent: newEndPos),
    );
  }

  /// Sets heading level (1 to 6) or converts heading to paragraph (0).
  static MutationResult setHeadingLevel(
    String markdown,
    DocumentPosition position,
    int targetLevel,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) {
      return MutationResult(markdown: markdown, document: doc, position: position);
    }

    final blockText = block.plainText;
    final prefix = targetLevel > 0 ? '${'#' * targetLevel} ' : '';
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ??
        DocumentPosition(blockId: position.blockId, offset: position.offset);

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Sets heading level (1 to 6) or converts heading to paragraph (0) by block ID.
  static MutationResult setHeadingLevelByBlockId(
    String markdown,
    String blockId,
    int targetLevel,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(blockId);
    if (block == null) {
      final pos = doc.blocks.isNotEmpty
          ? DocumentPosition(blockId: doc.blocks.first.id, offset: 0)
          : const DocumentPosition(blockId: 'block_0_p', offset: 0);
      return MutationResult(markdown: markdown, document: doc, position: pos);
    }
    return setHeadingLevel(markdown, DocumentPosition(blockId: blockId, offset: 0), targetLevel);
  }

  /// Toggles checklist item formatting for the block at [position].
  static MutationResult toggleChecklist(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is ChecklistItemBlock) {
      // Remove checklist formatting -> convert to normal paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.boxRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + position.offset) ?? position;
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // Convert block to checklist item
    final prefix = '- [ ] ';
    final blockText = block.plainText;
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles the checked state of a checklist item by [blockId].
  static MutationResult toggleChecklistState(
    String markdown,
    String blockId, {
    bool? targetState,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(blockId);
    if (block == null || block is! ChecklistItemBlock) {
      return MutationResult(markdown: markdown, document: doc, position: const DocumentPosition(blockId: '', offset: 0));
    }

    final newState = targetState ?? !block.checked;
    final stateChar = newState ? 'x' : ' ';

    // Replace the state character inside [ ]
    final boxStart = block.boxRange.start;
    final bracketIndex = markdown.indexOf('[', boxStart);
    if (bracketIndex == -1 || bracketIndex >= block.boxRange.end) {
      return MutationResult(markdown: markdown, document: doc, position: const DocumentPosition(blockId: '', offset: 0));
    }

    final newMarkdown = markdown.replaceRange(bracketIndex + 1, bracketIndex + 2, stateChar);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.contentRange.start) ??
        DocumentPosition(blockId: blockId, offset: 0);

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Toggles unordered bullet list item formatting.
  static MutationResult toggleList(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is ListItemBlock) {
      // Remove list marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + position.offset) ?? position;
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // Convert to bullet list item
    final prefix = '- ';
    final blockText = block.plainText;
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles ordered list item formatting.
  static MutationResult toggleOrderedList(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is OrderedListItemBlock) {
      // Remove ordered list marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + position.offset) ?? position;
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // Convert to ordered list item
    final prefix = '1. ';
    final blockText = block.plainText;
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles blockquote formatting.
  static MutationResult toggleQuote(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is QuoteBlock) {
      // Remove quote marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + position.offset) ?? position;
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // Convert to quote
    final prefix = '> ';
    final blockText = block.plainText;
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Creates a link [title](url) from [selection].
  static MutationResult toggleLink(
    String markdown,
    DocumentSelection selection, {
    required String url,
    String? title,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final range = doc.sourceRangeAtSelection(selection);
    final selectedText = range.slice(markdown);
    final effectiveTitle = (title != null && title.isNotEmpty)
        ? title
        : (selectedText.isNotEmpty ? selectedText : url);

    final linkMarkdown = '[$effectiveTitle]($url)';
    final newMarkdown = markdown.replaceRange(range.start, range.end, linkMarkdown);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final targetOffset = range.start + linkMarkdown.length;
    final newPos = newDoc.findPositionAtSourceOffset(targetOffset) ?? selection.start;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Creates a wiki note link [[noteTitle]] from [selection].
  static MutationResult toggleNoteLink(
    String markdown,
    DocumentSelection selection, {
    required String noteTitle,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final range = doc.sourceRangeAtSelection(selection);
    final linkMarkdown = '[[$noteTitle]]';

    final newMarkdown = markdown.replaceRange(range.start, range.end, linkMarkdown);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final targetOffset = range.start + linkMarkdown.length;
    final newPos = newDoc.findPositionAtSourceOffset(targetOffset) ?? selection.start;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Inserts a code block.
  static MutationResult createCodeBlock(
    String markdown,
    DocumentPosition position, {
    String? language,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final offset = doc.sourceOffsetAtPosition(position);

    final langStr = language ?? '';
    final codeBlockMarkdown = '\n```$langStr\n\n```\n';
    final newMarkdown = markdown.replaceRange(offset, offset, codeBlockMarkdown);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final cursorOffset = offset + 4 + langStr.length + 1; // after ```lang\n
    final newPos = newDoc.findPositionAtSourceOffset(cursorOffset) ?? position;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Updates the programming language of a code block.
  static MutationResult changeCodeBlockLanguage(
    String markdown,
    String blockId,
    String? language,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(blockId);
    if (block == null || block is! CodeBlock) {
      return MutationResult(markdown: markdown, document: doc, position: const DocumentPosition(blockId: '', offset: 0));
    }

    final newFence = '```${language ?? ''}\n';
    final newMarkdown = markdown.replaceRange(
      block.openingFenceRange.start,
      block.openingFenceRange.end,
      newFence,
    );
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(block.openingFenceRange.start + newFence.length) ??
        DocumentPosition(blockId: blockId, offset: 0);

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Inserts an image (![alt](url)).
  static MutationResult insertImage(
    String markdown,
    DocumentPosition position, {
    required String alt,
    required String url,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final offset = doc.sourceOffsetAtPosition(position);
    final imgMarkdown = '\n![$alt]($url)\n';

    final newMarkdown = markdown.replaceRange(offset, offset, imgMarkdown);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(offset + imgMarkdown.length) ?? position;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Inserts a horizontal rule divider (---).
  static MutationResult insertHorizontalRule(
    String markdown,
    DocumentPosition position,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final offset = doc.sourceOffsetAtPosition(position);
    const hrMarkdown = '\n---\n';

    final newMarkdown = markdown.replaceRange(offset, offset, hrMarkdown);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(offset + hrMarkdown.length) ?? position;

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newPos,
      selection: DocumentSelection.collapsed(newPos),
    );
  }

  /// Deletes a block by its identifier.
  static MutationResult deleteBlock(
    String markdown,
    String blockId,
  ) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(blockId);
    if (block == null) {
      return MutationResult(markdown: markdown, document: doc, position: const DocumentPosition(blockId: '', offset: 0));
    }

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newPos = newDoc.findPositionAtSourceOffset(max(0, block.sourceRange.start - 1)) ??
        const DocumentPosition(blockId: 'block_0_p', offset: 0);

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }
}
