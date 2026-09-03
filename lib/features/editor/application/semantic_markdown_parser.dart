import '../domain/frontmatter_document.dart';
import '../domain/semantic_document.dart';
import '../domain/semantic_nodes.dart';
import '../domain/source_range.dart';
import 'frontmatter_editor_helper.dart';
import 'markdown_table_parser.dart';

/// Deterministic, high-performance semantic Markdown parser.
/// Converts canonical Markdown strings into ephemeral [SemanticDocument] trees
/// with exact [SourceRange] annotations for all blocks and inline runs.
class SemanticMarkdownParser {
  const SemanticMarkdownParser();

  static const _tableParser = MarkdownTableParser();

  /// Parses [markdown] into a structured [SemanticDocument].
  ///
  /// If [stripFrontmatter] is true, the YAML frontmatter block (if any) is extracted
  /// as metadata and omitted from the body blocks.
  static SemanticDocument parse(String markdown, {bool stripFrontmatter = false}) {
    if (markdown.isEmpty) {
      const emptyRange = SourceRange(0, 0);
      return const SemanticDocument(
        blocks: [
          ParagraphBlock(
            id: 'block_0',
            runs: [PlainRun('', emptyRange)],
            sourceRange: emptyRange,
          ),
        ],
        canonicalMarkdown: '',
      );
    }

    FrontmatterDocument? frontmatter;
    SourceRange? frontmatterRange;
    var bodyStartIndex = 0;

    // 1. Check for YAML Frontmatter at start of document
    if (markdown.startsWith('---\n') || markdown.startsWith('---\r\n')) {
      final doc = FrontmatterEditorHelper.parse(markdown);
      if (doc.hasFrontmatter) {
        frontmatter = doc;
        final fmEnd = doc.frontmatterRange.end;
        frontmatterRange = SourceRange(0, fmEnd);
        if (stripFrontmatter) {
          bodyStartIndex = fmEnd;
          // Skip leading newline after frontmatter
          if (bodyStartIndex < markdown.length && markdown[bodyStartIndex] == '\n') {
            bodyStartIndex++;
          }
        }
      }
    }

    final blocks = <SemanticBlock>[];
    var currentOffset = bodyStartIndex;
    var blockCounter = 0;

    final docLength = markdown.length;

    while (currentOffset < docLength) {
      // Find end of current line
      var lineEnd = markdown.indexOf('\n', currentOffset);
      var nextOffset = lineEnd == -1 ? docLength : lineEnd + 1;
      if (lineEnd == -1) lineEnd = docLength;

      // Handle CR in CRLF
      var lineContentEnd = lineEnd;
      if (lineContentEnd > currentOffset && markdown[lineContentEnd - 1] == '\r') {
        lineContentEnd--;
      }

      final lineText = markdown.substring(currentOffset, lineContentEnd);
      final lineSourceRange = SourceRange(currentOffset, nextOffset);

      // Check for Tables
      final table = _tableParser.findTableAtOffset(markdown, currentOffset);
      if (table != null && table.sourceStart == currentOffset) {
        blocks.add(
          TableBlock(
            id: 'block_${blockCounter++}',
            table: table,
            sourceRange: SourceRange(table.sourceStart, table.sourceEnd),
          ),
        );
        currentOffset = table.sourceEnd;
        continue;
      }

      // Check for Fenced Code Block (``` or ~~~)
      final trimmedLine = lineText.trim();
      if (trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~')) {
        final fence = trimmedLine.substring(0, 3);
        final lang = trimmedLine.substring(3).trim();
        final openingFenceRange = SourceRange(currentOffset, nextOffset);

        // Find matching closing fence
        var codeSearchOffset = nextOffset;
        int? closingFenceStart;
        int? closingFenceEnd;
        var codeEnd = docLength;

        while (codeSearchOffset < docLength) {
          var nextLineEnd = markdown.indexOf('\n', codeSearchOffset);
          var lineAfter = nextLineEnd == -1 ? docLength : nextLineEnd + 1;
          if (nextLineEnd == -1) nextLineEnd = docLength;

          var checkEnd = nextLineEnd;
          if (checkEnd > codeSearchOffset && markdown[checkEnd - 1] == '\r') {
            checkEnd--;
          }
          final checkLine = markdown.substring(codeSearchOffset, checkEnd).trim();

          if (checkLine.startsWith(fence)) {
            closingFenceStart = codeSearchOffset;
            closingFenceEnd = lineAfter;
            codeEnd = codeSearchOffset;
            break;
          }
          codeSearchOffset = lineAfter;
        }

        final codeRange = SourceRange(nextOffset, codeEnd);
        final codeText = codeRange.slice(markdown);
        final totalRange = SourceRange(currentOffset, closingFenceEnd ?? docLength);

        blocks.add(
          CodeBlock(
            id: 'block_${blockCounter++}',
            language: lang.isEmpty ? null : lang,
            code: codeText,
            sourceRange: totalRange,
            openingFenceRange: openingFenceRange,
            codeRange: codeRange,
            closingFenceRange: closingFenceStart != null
                ? SourceRange(closingFenceStart, closingFenceEnd!)
                : null,
          ),
        );

        currentOffset = totalRange.end;
        continue;
      }

      // Check for Horizontal Rule (---, ***, ___)
      if (RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$').hasMatch(lineText)) {
        blocks.add(
          HorizontalRuleBlock(
            id: 'block_${blockCounter++}',
            marker: trimmedLine,
            sourceRange: lineSourceRange,
          ),
        );
        currentOffset = nextOffset;
        continue;
      }

      // Check for Heading (# to ######)
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(lineText);
      if (headingMatch != null) {
        final hashes = headingMatch.group(1)!;
        final content = headingMatch.group(2)!;
        final level = hashes.length;
        final markerLen = hashes.length + 1; // hashes + space
        final markerRange = SourceRange(currentOffset, currentOffset + markerLen);
        final contentRange = SourceRange(currentOffset + markerLen, currentOffset + lineText.length);

        final runs = _parseInlineRuns(content, contentRange);

        blocks.add(
          HeadingBlock(
            id: 'block_${blockCounter++}',
            level: level,
            runs: runs,
            sourceRange: lineSourceRange,
            markerRange: markerRange,
            contentRange: contentRange,
          ),
        );
        currentOffset = nextOffset;
        continue;
      }

      // Check for Checklist Item (- [ ] or - [x])
      final checklistMatch = RegExp(r'^(\s*)([-*+])\s+\[([ xX])\]\s*(.*)$').firstMatch(lineText);
      if (checklistMatch != null) {
        final indentStr = checklistMatch.group(1) ?? '';
        final markerChar = checklistMatch.group(2) ?? '-';
        final stateChar = checklistMatch.group(3) ?? ' ';
        final itemContent = checklistMatch.group(4) ?? '';
        final isChecked = stateChar == 'x' || stateChar == 'X';

        final boxPrefixLen = indentStr.length + markerChar.length + 1 + 3; // indent + marker + ' [' + state + ']'
        var contentStartOffset = currentOffset + boxPrefixLen;
        if (contentStartOffset < currentOffset + lineText.length && markdown[contentStartOffset] == ' ') {
          contentStartOffset++;
        }

        final boxRange = SourceRange(currentOffset + indentStr.length, contentStartOffset);
        final contentRange = SourceRange(contentStartOffset, currentOffset + lineText.length);
        final runs = _parseInlineRuns(itemContent, contentRange);

        final itemBlock = ChecklistItemBlock(
          id: 'block_${blockCounter++}',
          checked: isChecked,
          runs: runs,
          indent: indentStr.length,
          sourceRange: lineSourceRange,
          boxRange: boxRange,
          contentRange: contentRange,
        );

        blocks.add(itemBlock);
        currentOffset = nextOffset;
        continue;
      }

      // Check for Unordered List Item (- , * , + )
      final listMatch = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(lineText);
      if (listMatch != null) {
        final indentStr = listMatch.group(1) ?? '';
        final markerChar = listMatch.group(2) ?? '-';
        final itemContent = listMatch.group(3) ?? '';

        final markerLen = indentStr.length + markerChar.length + 1;
        final markerRange = SourceRange(currentOffset, currentOffset + markerLen);
        final contentRange = SourceRange(currentOffset + markerLen, currentOffset + lineText.length);
        final runs = _parseInlineRuns(itemContent, contentRange);

        final itemBlock = ListItemBlock(
          id: 'block_${blockCounter++}',
          runs: runs,
          indent: indentStr.length,
          marker: markerChar,
          sourceRange: lineSourceRange,
          markerRange: markerRange,
          contentRange: contentRange,
        );

        blocks.add(itemBlock);
        currentOffset = nextOffset;
        continue;
      }

      // Check for Ordered List Item (1. , 2. , 1) , etc.)
      final orderedMatch = RegExp(r'^(\s*)(\d+)([\.\)])\s+(.*)$').firstMatch(lineText);
      if (orderedMatch != null) {
        final indentStr = orderedMatch.group(1) ?? '';
        final numStr = orderedMatch.group(2) ?? '1';
        final delimiter = orderedMatch.group(3) ?? '.';
        final itemContent = orderedMatch.group(4) ?? '';
        final number = int.tryParse(numStr) ?? 1;

        final markerLen = indentStr.length + numStr.length + delimiter.length + 1;
        final markerRange = SourceRange(currentOffset, currentOffset + markerLen);
        final contentRange = SourceRange(currentOffset + markerLen, currentOffset + lineText.length);
        final runs = _parseInlineRuns(itemContent, contentRange);

        final itemBlock = OrderedListItemBlock(
          id: 'block_${blockCounter++}',
          number: number,
          delimiter: delimiter,
          runs: runs,
          indent: indentStr.length,
          sourceRange: lineSourceRange,
          markerRange: markerRange,
          contentRange: contentRange,
        );

        blocks.add(itemBlock);
        currentOffset = nextOffset;
        continue;
      }

      // Check for Blockquote (> quote)
      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(lineText);
      if (quoteMatch != null) {
        final quoteContent = quoteMatch.group(1) ?? '';
        final markerLen = lineText.startsWith('> ') ? 2 : 1;
        final markerRange = SourceRange(currentOffset, currentOffset + markerLen);
        final contentRange = SourceRange(currentOffset + markerLen, currentOffset + lineText.length);
        final runs = _parseInlineRuns(quoteContent, contentRange);

        blocks.add(
          QuoteBlock(
            id: 'block_${blockCounter++}',
            runs: runs,
            sourceRange: lineSourceRange,
            markerRange: markerRange,
            contentRange: contentRange,
          ),
        );
        currentOffset = nextOffset;
        continue;
      }

      // Check for Standalone Image (![alt](url))
      final imageMatch = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(lineText.trim());
      if (imageMatch != null) {
        final alt = imageMatch.group(1) ?? '';
        final url = imageMatch.group(2) ?? '';
        blocks.add(
          ImageBlock(
            id: 'block_${blockCounter++}',
            altText: alt,
            url: url,
            sourceRange: lineSourceRange,
          ),
        );
        currentOffset = nextOffset;
        continue;
      }

      // Default: Paragraph Block
      final contentRange = SourceRange(currentOffset, currentOffset + lineText.length);
      final runs = _parseInlineRuns(lineText, contentRange);

      blocks.add(
        ParagraphBlock(
          id: 'block_${blockCounter++}',
          runs: runs,
          sourceRange: lineSourceRange,
          contentRange: contentRange,
        ),
      );

      currentOffset = nextOffset;
    }

    if (blocks.isEmpty) {
      blocks.add(
        ParagraphBlock(
          id: 'block_0',
          runs: [PlainRun('', SourceRange(0, markdown.length))],
          sourceRange: SourceRange(0, markdown.length),
        ),
      );
    }

    return SemanticDocument(
      blocks: blocks,
      canonicalMarkdown: markdown,
      frontmatter: frontmatter,
      frontmatterRange: frontmatterRange,
    );
  }

  /// Parses inline formatting runs (**bold**, *italic*, ~~strike~~, `code`, [link](url), [[Note]], #tag, ==highlight==)
  /// within [content] positioned at [baseRange] in the document source.
  static List<SemanticInline> _parseInlineRuns(String content, SourceRange baseRange) {
    if (content.isEmpty) {
      return [PlainRun('', baseRange)];
    }

    // Regex matching all supported inline delimiters
    final inlineRegex = RegExp(
      r'(\*\*|__)(.*?)\1|' // 1: Bold (**text** or __text__)
      r'(\*|_)(.*?)\3|' // 3: Italic (*text* or _text_)
      r'~~(.*?)~~|' // 5: Strikethrough (~~text~~)
      r'==(.*?)==|' // 6: Highlight (==text==)
      r'`([^`]+)`|' // 7: Inline Code (`code`)
      r'\[\[([^\]]+)\]\]|' // 8: Wiki Note Link ([[Note Title]])
      r'\[([^\]]+)\]\(([^)]+)\)|' // 9, 10: Markdown Link ([title](url))
      r'(#[\w\-_/]+)', // 11: Tag (#tag)
    );

    final runs = <SemanticInline>[];
    var lastIndex = 0;

    for (final match in inlineRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        final plainSlice = content.substring(lastIndex, match.start);
        final sliceRange = SourceRange(
          baseRange.start + lastIndex,
          baseRange.start + match.start,
        );
        runs.add(PlainRun(plainSlice, sliceRange));
      }

      final fullMatch = match.group(0)!;
      final matchStart = baseRange.start + match.start;
      final matchEnd = baseRange.start + match.end;
      final matchRange = SourceRange(matchStart, matchEnd);

      if (match.group(1) != null) {
        // Bold (**text** or __text__)
        final innerText = match.group(2) ?? '';
        final delimLen = match.group(1)!.length;
        final contentRange = SourceRange(matchStart + delimLen, matchEnd - delimLen);
        runs.add(BoldRun(innerText, matchRange, contentRange));
      } else if (match.group(3) != null) {
        // Italic (*text* or _text_)
        final innerText = match.group(4) ?? '';
        final delimLen = match.group(3)!.length;
        final contentRange = SourceRange(matchStart + delimLen, matchEnd - delimLen);
        runs.add(ItalicRun(innerText, matchRange, contentRange));
      } else if (match.group(5) != null) {
        // Strikethrough (~~text~~)
        final innerText = match.group(5)!;
        final contentRange = SourceRange(matchStart + 2, matchEnd - 2);
        runs.add(StrikeRun(innerText, matchRange, contentRange));
      } else if (match.group(6) != null) {
        // Highlight (==text==)
        final innerText = match.group(6)!;
        final contentRange = SourceRange(matchStart + 2, matchEnd - 2);
        runs.add(HighlightRun(innerText, matchRange, contentRange));
      } else if (match.group(7) != null) {
        // Inline Code (`code`)
        final innerText = match.group(7)!;
        final contentRange = SourceRange(matchStart + 1, matchEnd - 1);
        runs.add(InlineCodeRun(innerText, matchRange, contentRange));
      } else if (match.group(8) != null) {
        // Wiki Note Link ([[Note Title]])
        final noteTitle = match.group(8)!;
        final titleRange = SourceRange(matchStart + 2, matchEnd - 2);
        runs.add(NoteLinkRun(noteTitle: noteTitle, sourceRange: matchRange, titleRange: titleRange));
      } else if (match.group(9) != null && match.group(10) != null) {
        // Link ([label](url))
        final label = match.group(9)!;
        final destination = match.group(10)!;
        final labelStart = matchStart + 1;
        final labelEnd = labelStart + label.length;
        final urlStart = labelEnd + 2; // ']('
        final urlEnd = urlStart + destination.length;

        runs.add(
          LinkRun(
            text: label,
            destination: destination,
            sourceRange: matchRange,
            labelRange: SourceRange(labelStart, labelEnd),
            urlRange: SourceRange(urlStart, urlEnd),
          ),
        );
      } else if (match.group(11) != null) {
        // Tag (#tag)
        final rawTag = match.group(11)!;
        final tagName = rawTag.startsWith('#') ? rawTag.substring(1) : rawTag;
        runs.add(TagRun(tagName, matchRange));
      } else {
        runs.add(PlainRun(fullMatch, matchRange));
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      final plainSlice = content.substring(lastIndex);
      final sliceRange = SourceRange(
        baseRange.start + lastIndex,
        baseRange.start + content.length,
      );
      runs.add(PlainRun(plainSlice, sliceRange));
    }

    return runs;
  }
}
