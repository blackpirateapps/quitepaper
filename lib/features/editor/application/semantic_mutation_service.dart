import 'dart:math';
import '../domain/document_position.dart';
import '../domain/semantic_document.dart';
import '../domain/semantic_nodes.dart';
import '../domain/source_range.dart';
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
    String text, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final sourceOffset = doc.sourceOffsetAtPosition(position);

    final actualText = (text == '\n' && sourceOffset == markdown.length && !markdown.endsWith('\n'))
        ? '\n\n'
        : text;
    final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, actualText);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final block = doc.findBlockById(position.blockId);

    if (block == null) {
      return insertText(markdown, position, '\n', stripFrontmatter: stripFrontmatter);
    }

    if (block is ChecklistItemBlock) {
      if (block.plainText.trim().isEmpty) {
        // Empty checklist item -> exit checklist by clearing marker to normal paragraph
        final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, '');
        final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      // Non-empty checklist item -> insert new uncompleted checklist item on new line
      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final insertion = '\n$indent- [ ] ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
        final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final insertion = '\n$indent${block.marker} ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
        final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      final indent = ' ' * block.indent;
      final nextNumber = block.number + 1;
      final insertion = '\n$indent$nextNumber${block.delimiter} ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
        final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
        final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
            DocumentPosition(blockId: position.blockId, offset: 0);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }

      final sourceOffset = doc.sourceOffsetAtPosition(position);
      const insertion = '\n> ';
      final newMarkdown = markdown.replaceRange(sourceOffset, sourceOffset, insertion);
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    return insertText(markdown, position, '\n', stripFrontmatter: stripFrontmatter);
  }

  /// Merges block at [position] with previous block or clears list/checklist/quote prefix.
  static MutationResult mergeWithPreviousBlock(
    String markdown,
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
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
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is ListItemBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is OrderedListItemBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is QuoteBlock) {
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start) ??
          DocumentPosition(blockId: block.id, offset: 0);
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    if (block is HeadingBlock) {
      // Convert heading to paragraph (remove `# `)
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
        final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
        final newPos = newDoc.findPositionAtSourceOffset(newlineOffset) ??
            DocumentPosition(blockId: prevBlock.id, offset: prevBlock.plainText.length);
        return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
      }
    }

    return MutationResult(markdown: markdown, document: doc, position: position);
  }

  /// Merges adjacent runs that share identical styling and are not atomic tokens,
  /// and coalesces styled runs across intervening pure-whitespace runs.
  static List<SemanticInline> mergeAdjacentRuns(List<SemanticInline> runs) {
    if (runs.length <= 1) return runs;

    final pass1 = _mergeDirectAdjacentRuns(runs);

    final result = <SemanticInline>[];
    var i = 0;
    while (i < pass1.length) {
      var current = pass1[i];
      while (i + 2 < pass1.length) {
        final ws = pass1[i + 1];
        final next = pass1[i + 2];

        final isPureWhitespace = ws is PlainRun && ws.text.isNotEmpty && ws.text.trim().isEmpty;
        final hasMatchingStyle = (current is! InlineCodeRun && next is! InlineCodeRun) &&
            (current is! LinkRun && next is! LinkRun) &&
            (current is! NoteLinkRun && next is! NoteLinkRun) &&
            (current is! TagRun && next is! TagRun) &&
            (current.isBold || current.isItalic || current.isStrike || current.isHighlight) &&
            current.isBold == next.isBold &&
            current.isItalic == next.isItalic &&
            current.isStrike == next.isStrike &&
            current.isHighlight == next.isHighlight;

        if (isPureWhitespace && hasMatchingStyle) {
          final combinedText = current.text + ws.text + next.text;
          final combinedSource = SourceRange(current.sourceRange.start, next.sourceRange.end);
          final combinedContent = SourceRange(
            current.contentRange?.start ?? current.sourceRange.start,
            next.contentRange?.end ?? next.sourceRange.end,
          );
          current = _cloneRunWithText(
            current,
            combinedText,
            sourceRange: combinedSource,
            contentRange: combinedContent,
          );
          i += 2;
        } else {
          break;
        }
      }
      result.add(current);
      i++;
    }

    return _mergeDirectAdjacentRuns(result);
  }

  static List<SemanticInline> _mergeDirectAdjacentRuns(List<SemanticInline> runs) {
    if (runs.length <= 1) return runs;

    final merged = <SemanticInline>[];
    for (final run in runs) {
      if (run.text.isEmpty) continue;
      if (merged.isEmpty) {
        merged.add(run);
        continue;
      }
      final prev = merged.last;
      final canMerge = (prev is! InlineCodeRun && run is! InlineCodeRun) &&
          (prev is! LinkRun && run is! LinkRun) &&
          (prev is! NoteLinkRun && run is! NoteLinkRun) &&
          (prev is! TagRun && run is! TagRun) &&
          prev.isBold == run.isBold &&
          prev.isItalic == run.isItalic &&
          prev.isStrike == run.isStrike &&
          prev.isHighlight == run.isHighlight;

      if (canMerge) {
        final combinedText = prev.text + run.text;
        final combinedSource = SourceRange(prev.sourceRange.start, run.sourceRange.end);
        final combinedContent = SourceRange(
          prev.contentRange?.start ?? prev.sourceRange.start,
          run.contentRange?.end ?? run.sourceRange.end,
        );
        merged[merged.length - 1] = _cloneRunWithText(
          prev,
          combinedText,
          sourceRange: combinedSource,
          contentRange: combinedContent,
        );
      } else {
        merged.add(run);
      }
    }

    if (merged.isEmpty) {
      return [const PlainRun('', SourceRange(0, 0))];
    }
    return merged;
  }

  /// Splits [runs] at visual [splitOffset] within the block's visual text.
  static List<SemanticInline> splitRunsAt(List<SemanticInline> runs, int splitOffset) {
    if (runs.isEmpty) return runs;

    final result = <SemanticInline>[];
    var currentOffset = 0;

    for (final run in runs) {
      final runLen = run.text.length;
      final runStart = currentOffset;
      final runEnd = currentOffset + runLen;

      if (splitOffset > runStart && splitOffset < runEnd) {
        final splitIndex = splitOffset - runStart;
        final leftText = run.text.substring(0, splitIndex);
        final rightText = run.text.substring(splitIndex);

        final leftRun = _cloneRunWithText(run, leftText);
        final rightRun = _cloneRunWithText(run, rightText);
        result.add(leftRun);
        result.add(rightRun);
      } else {
        result.add(run);
      }
      currentOffset += runLen;
    }
    return result;
  }

  static SemanticInline _cloneRunWithText(
    SemanticInline run,
    String newText, {
    bool? isBold,
    bool? isItalic,
    bool? isStrike,
    bool? isHighlight,
    SourceRange? sourceRange,
    SourceRange? contentRange,
  }) {
    final b = isBold ?? run.isBold;
    final i = isItalic ?? run.isItalic;
    final s = isStrike ?? run.isStrike;
    final h = isHighlight ?? run.isHighlight;
    final src = sourceRange ?? run.sourceRange;
    final cnt = contentRange ?? run.contentRange ?? src;

    if (run is InlineCodeRun) {
      return InlineCodeRun(newText, src, cnt);
    } else if (run is LinkRun) {
      return LinkRun(
        text: newText,
        destination: run.destination,
        sourceRange: src,
        labelRange: run.labelRange,
        urlRange: run.urlRange,
      );
    } else if (run is NoteLinkRun) {
      return NoteLinkRun(
        noteTitle: newText,
        sourceRange: src,
        titleRange: run.titleRange,
      );
    } else if (run is TagRun) {
      return TagRun(newText, src);
    }

    if (!b && !i && !s && !h) {
      return PlainRun(newText, src);
    }
    if (b) {
      return BoldRun(
        newText,
        src,
        cnt,
        isItalic: i,
        isStrike: s,
        isHighlight: h,
      );
    }
    if (i) {
      return ItalicRun(
        newText,
        src,
        cnt,
        isBold: b,
        isStrike: s,
        isHighlight: h,
      );
    }
    if (s) {
      return StrikeRun(
        newText,
        src,
        cnt,
        isBold: b,
        isItalic: i,
        isHighlight: h,
      );
    }
    return HighlightRun(
      newText,
      src,
      cnt,
      isBold: b,
      isItalic: i,
      isStrike: s,
    );
  }

  /// Serializes a list of [runs] to canonical Markdown syntax.
  static String serializeRuns(List<SemanticInline> runs) {
    final merged = mergeAdjacentRuns(runs);
    final buffer = StringBuffer();

    for (final run in merged) {
      final text = run.text;
      if (text.isEmpty) continue;

      if (run is InlineCodeRun) {
        buffer.write('`$text`');
      } else if (run is LinkRun) {
        buffer.write('[$text](${run.destination})');
      } else if (run is NoteLinkRun) {
        buffer.write('[[${run.noteTitle}]]');
      } else if (run is TagRun) {
        buffer.write('#${run.tag}');
      } else if (!run.isBold && !run.isItalic && !run.isStrike && !run.isHighlight) {
        buffer.write(text);
      } else {
        if (text.trim().isEmpty) {
          buffer.write(text);
          continue;
        }

        final leadingSpaces = text.length - text.trimLeft().length;
        final trailingSpaces = text.length - text.trimRight().length;
        final prefix = text.substring(0, leadingSpaces);
        final core = text.substring(leadingSpaces, text.length - trailingSpaces);
        final suffix = text.substring(text.length - trailingSpaces);

        var wrapped = core;
        if (run.isBold && run.isItalic) {
          wrapped = '***$wrapped***';
        } else if (run.isBold) {
          wrapped = '**$wrapped**';
        } else if (run.isItalic) {
          wrapped = '*$wrapped*';
        }

        if (run.isStrike) {
          wrapped = '~~$wrapped~~';
        }

        if (run.isHighlight) {
          wrapped = '==$wrapped==';
        }

        buffer.write('$prefix$wrapped$suffix');
      }
    }

    return buffer.toString();
  }

  /// Serializes a block with its [runs] to canonical Markdown syntax.
  static String serializeBlockMarkdown(SemanticBlock block, List<SemanticInline> runs) {
    final serializedRuns = serializeRuns(runs);
    if (block is HeadingBlock) {
      return '${'#' * block.level} $serializedRuns';
    } else if (block is ChecklistItemBlock) {
      final indent = ' ' * block.indent;
      final state = block.checked ? 'x' : ' ';
      return '$indent- [$state] $serializedRuns';
    } else if (block is ListItemBlock) {
      final indent = ' ' * block.indent;
      return '$indent${block.marker} $serializedRuns';
    } else if (block is OrderedListItemBlock) {
      final indent = ' ' * block.indent;
      return '$indent${block.number}${block.delimiter} $serializedRuns';
    } else if (block is QuoteBlock) {
      return '> $serializedRuns';
    }
    return serializedRuns;
  }

  /// Toggles an inline format on [selection] within the semantic block model.
  static MutationResult toggleInlineFormat(
    String markdown,
    DocumentSelection selection, {
    bool toggleBold = false,
    bool toggleItalic = false,
    bool toggleStrike = false,
    bool toggleHighlight = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown);
    final block = doc.findBlockById(selection.base.blockId);

    if (block == null) {
      return MutationResult(markdown: markdown, document: doc, position: selection.base, selection: selection);
    }

    List<SemanticInline> runs;
    if (block is ParagraphBlock) {
      runs = block.runs;
    } else if (block is HeadingBlock) {
      runs = block.runs;
    } else if (block is ListItemBlock) {
      runs = block.runs;
    } else if (block is OrderedListItemBlock) {
      runs = block.runs;
    } else if (block is ChecklistItemBlock) {
      runs = block.runs;
    } else if (block is QuoteBlock) {
      runs = block.runs;
    } else {
      return MutationResult(markdown: markdown, document: doc, position: selection.base, selection: selection);
    }

    if (selection.isCollapsed) {
      return MutationResult(markdown: markdown, document: doc, position: selection.base, selection: selection);
    }

    final plain = block.plainText;
    final start = min(selection.base.offset, selection.extent.offset).clamp(0, plain.length);
    final end = max(selection.base.offset, selection.extent.offset).clamp(0, plain.length);

    if (start >= end) {
      return MutationResult(markdown: markdown, document: doc, position: selection.base, selection: selection);
    }

    // Split runs at visual boundaries
    var split = splitRunsAt(runs, start);
    split = splitRunsAt(split, end);

    // Find runs within [start, end)
    var currentOffset = 0;
    final runsInRange = <SemanticInline>[];
    for (final r in split) {
      final rStart = currentOffset;
      final rEnd = currentOffset + r.text.length;
      if (rStart >= start && rEnd <= end) {
        runsInRange.add(r);
      }
      currentOffset += r.text.length;
    }

    final nonWhitespaceRuns = runsInRange.where((r) => r.text.trim().isNotEmpty).toList();
    final effectiveRuns = nonWhitespaceRuns.isNotEmpty ? nonWhitespaceRuns : runsInRange;

    final targetBold = toggleBold ? !effectiveRuns.every((r) => r.isBold) : null;
    final targetItalic = toggleItalic ? !effectiveRuns.every((r) => r.isItalic) : null;
    final targetStrike = toggleStrike ? !effectiveRuns.every((r) => r.isStrike) : null;
    final targetHighlight = toggleHighlight ? !effectiveRuns.every((r) => r.isHighlight) : null;

    currentOffset = 0;
    final updatedRuns = <SemanticInline>[];
    for (final r in split) {
      final rStart = currentOffset;
      final rEnd = currentOffset + r.text.length;
      if (rStart >= start && rEnd <= end) {
        updatedRuns.add(_cloneRunWithText(
          r,
          r.text,
          isBold: targetBold ?? r.isBold,
          isItalic: targetItalic ?? r.isItalic,
          isStrike: targetStrike ?? r.isStrike,
          isHighlight: targetHighlight ?? r.isHighlight,
        ));
      } else {
        updatedRuns.add(r);
      }
      currentOffset += r.text.length;
    }

    final merged = mergeAdjacentRuns(updatedRuns);
    final blockMarkdown = serializeBlockMarkdown(block, merged);

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$blockMarkdown\n' : blockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown);
    final newBase = DocumentPosition(blockId: block.id, offset: start);
    final newExtent = DocumentPosition(blockId: block.id, offset: end);
    final newSelection = DocumentSelection(base: newBase, extent: newExtent);

    return MutationResult(
      markdown: newMarkdown,
      document: newDoc,
      position: newExtent,
      selection: newSelection,
    );
  }

  /// Toggles bold (**text**) formatting on [selection].
  static MutationResult toggleBold(String markdown, DocumentSelection selection) {
    if (!selection.isCollapsed) {
      return toggleInlineFormat(markdown, selection, toggleBold: true);
    }
    return _toggleInlineDelimiter(markdown, selection, '**');
  }

  /// Toggles italic (*text*) formatting on [selection].
  static MutationResult toggleItalic(String markdown, DocumentSelection selection) {
    if (!selection.isCollapsed) {
      return toggleInlineFormat(markdown, selection, toggleItalic: true);
    }
    return _toggleInlineDelimiter(markdown, selection, '*');
  }

  /// Toggles strikethrough (~~text~~) formatting on [selection].
  static MutationResult toggleStrike(String markdown, DocumentSelection selection) {
    if (!selection.isCollapsed) {
      return toggleInlineFormat(markdown, selection, toggleStrike: true);
    }
    return _toggleInlineDelimiter(markdown, selection, '~~');
  }

  /// Toggles highlight (==text==) formatting on [selection].
  static MutationResult toggleHighlight(String markdown, DocumentSelection selection) {
    if (!selection.isCollapsed) {
      return toggleInlineFormat(markdown, selection, toggleHighlight: true);
    }
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
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is ChecklistItemBlock) {
      // Remove checklist formatting -> convert to normal paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.boxRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles the checked state of a checklist item by [blockId].
  static MutationResult toggleChecklistState(
    String markdown,
    String blockId, {
    bool? targetState,
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
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
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is ListItemBlock) {
      // Remove list marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles ordered list item formatting.
  static MutationResult toggleOrderedList(
    String markdown,
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is OrderedListItemBlock) {
      // Remove ordered list marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
    final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + prefix.length + position.offset) ?? position;

    return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
  }

  /// Toggles blockquote formatting.
  static MutationResult toggleQuote(
    String markdown,
    DocumentPosition position, {
    bool stripFrontmatter = false,
  }) {
    final doc = SemanticMarkdownParser.parse(markdown, stripFrontmatter: stripFrontmatter);
    final block = doc.findBlockById(position.blockId);
    if (block == null) return MutationResult(markdown: markdown, document: doc, position: position);

    if (block is QuoteBlock) {
      // Remove quote marker -> convert to paragraph
      final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.markerRange.end, '');
      final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      final newPos = newDoc.findPositionAtSourceOffset(block.sourceRange.start + position.offset) ?? position;
      return MutationResult(markdown: newMarkdown, document: newDoc, position: newPos);
    }

    // Convert to blockquote
    final prefix = '> ';
    final blockText = block.plainText;
    final newBlockMarkdown = '$prefix$blockText';

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= markdown.length && lineEnd > 0 && markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$newBlockMarkdown\n' : newBlockMarkdown;

    final newMarkdown = markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    final newDoc = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
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
