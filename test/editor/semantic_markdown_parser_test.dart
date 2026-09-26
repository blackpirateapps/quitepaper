import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';

void main() {
  group('SemanticMarkdownParser Tests', () {
    test('parses empty string cleanly into a single empty paragraph block', () {
      final doc = SemanticMarkdownParser.parse('');
      expect(doc.blocks.length, equals(1));
      expect(doc.blocks.first, isA<ParagraphBlock>());
      expect(doc.blocks.first.plainText, isEmpty);
      expect(doc.canonicalMarkdown, isEmpty);
    });

    test('parses headings with levels 1 to 6 without hash marks in text', () {
      const md = '# Heading 1\n## Heading 2\n### Heading 3\n#### Heading 4\n##### Heading 5\n###### Heading 6';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(6));
      for (var i = 0; i < 6; i++) {
        final block = doc.blocks[i];
        expect(block, isA<HeadingBlock>());
        final heading = block as HeadingBlock;
        expect(heading.level, equals(i + 1));
        expect(heading.plainText, equals('Heading ${i + 1}'));
        expect(heading.markerRange.length, equals(i + 2)); // e.g. '# ' is 2 chars
      }
    });

    test('parses inline formatting (bold, italic, strike, code, link, note-link, tag, highlight)', () {
      const md = 'Hello **bold** and *italic* and ~~struck~~ and `code` and ==highlighted== and [Link](https://quietpaper.app) and [[My Note]] and #flutter!';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(1));
      final p = doc.blocks.first as ParagraphBlock;
      expect(p.plainText, equals('Hello bold and italic and struck and code and highlighted and Link and My Note and #flutter!'));

      expect(p.runs.any((r) => r is BoldRun && r.text == 'bold'), isTrue);
      expect(p.runs.any((r) => r is ItalicRun && r.text == 'italic'), isTrue);
      expect(p.runs.any((r) => r is StrikeRun && r.text == 'struck'), isTrue);
      expect(p.runs.any((r) => r is InlineCodeRun && r.text == 'code'), isTrue);
      expect(p.runs.any((r) => r is HighlightRun && r.text == 'highlighted'), isTrue);
      expect(p.runs.any((r) => r is LinkRun && r.text == 'Link' && r.destination == 'https://quietpaper.app'), isTrue);
      expect(p.runs.any((r) => r is NoteLinkRun && r.noteTitle == 'My Note'), isTrue);
      expect(p.runs.any((r) => r is TagRun && r.tag == 'flutter'), isTrue);
    });

    test('parses arbitrary combinations of bold, italic, and strikethrough cleanly without delimiters', () {
      const md = '***bold italic*** and ~~***all three***~~ and ~~**bold strike**~~ and ~~*italic strike*~~ and **_alt bold italic_** and **bold with *nested italic* inside**';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(1));
      final p = doc.blocks.first as ParagraphBlock;

      // Plain visual text must have ZERO '*', '_', '~' syntax delimiters
      expect(p.plainText, contains('bold italic'));
      expect(p.plainText, contains('all three'));
      expect(p.plainText, contains('bold strike'));
      expect(p.plainText, contains('italic strike'));
      expect(p.plainText, contains('alt bold italic'));
      expect(p.plainText, contains('bold with nested italic inside'));
      expect(p.plainText.contains('*'), isFalse);
      expect(p.plainText.contains('~'), isFalse);
      expect(p.plainText.contains('_'), isFalse);

      // Verify run format combinations
      final bi = p.runs.firstWhere((r) => r.text == 'bold italic');
      expect(bi.isBold, isTrue);
      expect(bi.isItalic, isTrue);
      expect(bi.isStrike, isFalse);

      final allThree = p.runs.firstWhere((r) => r.text == 'all three');
      expect(allThree.isBold, isTrue);
      expect(allThree.isItalic, isTrue);
      expect(allThree.isStrike, isTrue);

      final bs = p.runs.firstWhere((r) => r.text == 'bold strike');
      expect(bs.isBold, isTrue);
      expect(bs.isItalic, isFalse);
      expect(bs.isStrike, isTrue);

      final isRun = p.runs.firstWhere((r) => r.text == 'italic strike');
      expect(isRun.isBold, isFalse);
      expect(isRun.isItalic, isTrue);
      expect(isRun.isStrike, isTrue);

      final altBi = p.runs.firstWhere((r) => r.text == 'alt bold italic');
      expect(altBi.isBold, isTrue);
      expect(altBi.isItalic, isTrue);

      final nestedItalic = p.runs.firstWhere((r) => r.text == 'nested italic');
      expect(nestedItalic.isBold, isTrue);
      expect(nestedItalic.isItalic, isTrue);
    });

    test('parses unordered list items with markers -, *, +', () {
      const md = '- Item 1\n* Item 2\n+ Item 3';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(3));
      for (var i = 0; i < 3; i++) {
        final item = doc.blocks[i] as ListItemBlock;
        expect(item.plainText, equals('Item ${i + 1}'));
      }
    });

    test('parses ordered list items with numbering and delimiters', () {
      const md = '1. First\n2. Second\n3) Third';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(3));
      final o1 = doc.blocks[0] as OrderedListItemBlock;
      expect(o1.number, equals(1));
      expect(o1.delimiter, equals('.'));
      expect(o1.plainText, equals('First'));

      final o2 = doc.blocks[1] as OrderedListItemBlock;
      expect(o2.number, equals(2));
      expect(o2.plainText, equals('Second'));

      final o3 = doc.blocks[2] as OrderedListItemBlock;
      expect(o3.number, equals(3));
      expect(o3.delimiter, equals(')'));
      expect(o3.plainText, equals('Third'));
    });

    test('parses checklist items with checked and unchecked states', () {
      const md = '- [ ] Todo item\n- [x] Completed item\n* [X] Also completed';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(3));
      final c1 = doc.blocks[0] as ChecklistItemBlock;
      expect(c1.checked, isFalse);
      expect(c1.plainText, equals('Todo item'));

      final c2 = doc.blocks[1] as ChecklistItemBlock;
      expect(c2.checked, isTrue);
      expect(c2.plainText, equals('Completed item'));

      final c3 = doc.blocks[2] as ChecklistItemBlock;
      expect(c3.checked, isTrue);
      expect(c3.plainText, equals('Also completed'));
    });

    test('parses blockquotes cleanly', () {
      const md = '> First quote line\n> Second quote line';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(2));
      expect(doc.blocks[0], isA<QuoteBlock>());
      expect(doc.blocks[0].plainText, equals('First quote line'));
      expect(doc.blocks[1].plainText, equals('Second quote line'));
    });

    test('parses horizontal rule dividers (---, ***, ___)', () {
      const md = 'Para 1\n---\nPara 2\n***\nPara 3\n___';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(6));
      expect(doc.blocks[1], isA<HorizontalRuleBlock>());
      expect(doc.blocks[3], isA<HorizontalRuleBlock>());
      expect(doc.blocks[5], isA<HorizontalRuleBlock>());
    });

    test('parses fenced code blocks with language and code verbatim', () {
      const md = '```dart\nfinal x = 42;\nprint(x);\n```';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(1));
      final codeBlock = doc.blocks.first as CodeBlock;
      expect(codeBlock.language, equals('dart'));
      expect(codeBlock.code, equals('final x = 42;\nprint(x);\n'));
    });

    test('parses GFM pipe tables into TableBlock', () {
      const md = '| A | B |\n|---|---|\n| 1 | 2 |';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.length, equals(1));
      final tableBlock = doc.blocks.first as TableBlock;
      expect(tableBlock.table.rowCount, equals(2)); // header + 1 row
      expect(tableBlock.table.columnCount, equals(2));
    });

    test('parses YAML frontmatter metadata and strips when requested', () {
      const md = '---\ntitle: Doc Title\nauthor: Dr. Watson\n---\n# Real Body';
      final docWithFm = SemanticMarkdownParser.parse(md, stripFrontmatter: false);
      expect(docWithFm.hasFrontmatter, isTrue);
      expect(docWithFm.frontmatter?.title, equals('Doc Title'));
      expect(docWithFm.frontmatter?.author, equals('Dr. Watson'));

      final docStripped = SemanticMarkdownParser.parse(md, stripFrontmatter: true);
      expect(docStripped.hasFrontmatter, isTrue);
      expect(docStripped.blocks.length, equals(1));
      expect(docStripped.blocks.first, isA<HeadingBlock>());
      expect(docStripped.blocks.first.plainText, equals('Real Body'));
    });

    test('handles malformed / incomplete syntax gracefully without throwing', () {
      const md = '**incomplete bold\n*single asterisk\n`unclosed code\n- [ malformed check\n[unclosed link(http://';
      final doc = SemanticMarkdownParser.parse(md);

      expect(doc.blocks.isNotEmpty, isTrue);
      expect(doc.canonicalMarkdown, equals(md));
    });

    test('incrementalParse correctly updates an edited block and shifts downstream source ranges', () {
      const originalMd = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5';
      final originalDoc = SemanticMarkdownParser.parse(originalMd);
      expect(originalDoc.blocks.length, equals(5));

      final targetBlockId = originalDoc.blocks[2].id; // Line 3
      const editedMd = 'Line 1\nLine 2\nLine 3 with expanded text\nLine 4\nLine 5';

      final incrementalDoc = SemanticMarkdownParser.incrementalParse(
        newMarkdown: editedMd,
        oldDocument: originalDoc,
        editBlockId: targetBlockId,
      );

      final fullDoc = SemanticMarkdownParser.parse(editedMd);

      expect(incrementalDoc.blocks.length, equals(fullDoc.blocks.length));
      for (var i = 0; i < incrementalDoc.blocks.length; i++) {
        expect(incrementalDoc.blocks[i].plainText, equals(fullDoc.blocks[i].plainText));
        expect(incrementalDoc.blocks[i].sourceRange.start, equals(fullDoc.blocks[i].sourceRange.start));
        expect(incrementalDoc.blocks[i].sourceRange.end, equals(fullDoc.blocks[i].sourceRange.end));
      }

      // Verify that the edited block retained its original stable ID
      expect(incrementalDoc.blocks[2].id, equals(targetBlockId));
    });

    test('shiftSourceRange shifts all block and inline source ranges by delta', () {
      const md = '# Heading with **bold**\nParagraph with `code` and [link](url)\n- [x] Done task';
      final doc = SemanticMarkdownParser.parse(md);

      const delta = 100;
      final shiftedBlocks = doc.blocks.map((b) => b.shiftSourceRange(delta)).toList();

      for (var i = 0; i < doc.blocks.length; i++) {
        expect(shiftedBlocks[i].sourceRange.start, equals(doc.blocks[i].sourceRange.start + delta));
        expect(shiftedBlocks[i].sourceRange.end, equals(doc.blocks[i].sourceRange.end + delta));
      }
    });
  });

  group('SemanticMarkdownParser P2 fidelity', () {
    // P2-1: extra whitespace after a block marker must not mis-map content
    // ranges. The content range must cover exactly the visible text and the
    // caret round-trip through the first content char must be exact.
    void expectMarkerRoundTrip(String md, String expectedContent) {
      final doc = SemanticMarkdownParser.parse(md);
      final block = doc.blocks.first;
      expect(block.plainText, equals(expectedContent), reason: 'plainText for "$md"');

      // The first visible character maps back to the byte immediately after the
      // marker+whitespace, and that source offset maps forward to visible 0.
      final pos = doc.findPositionAtSourceOffset(md.indexOf(expectedContent));
      expect(pos, isNotNull, reason: 'position for "$md"');
      expect(pos!.offset, equals(0), reason: 'first char offset for "$md"');
      final back = doc.sourceOffsetAtPosition(pos);
      expect(back, equals(md.indexOf(expectedContent)), reason: 'round-trip for "$md"');
    }

    test('P2-1 heading with multiple spaces after # maps content correctly', () {
      expectMarkerRoundTrip('#   Heading', 'Heading');
      final doc = SemanticMarkdownParser.parse('#   Heading');
      final h = doc.blocks.first as HeadingBlock;
      expect(h.contentRange.slice('#   Heading'), equals('Heading'));
      expect(h.markerRange.length, equals(4)); // '#' + 3 spaces
    });

    test('P2-1 unordered / ordered / checklist / quote with extra spaces', () {
      expectMarkerRoundTrip('-   item', 'item');
      expectMarkerRoundTrip('1.   item', 'item');
      expectMarkerRoundTrip('- [ ]   task', 'task');
      expectMarkerRoundTrip('>    quote', '   quote');

      final checkDoc = SemanticMarkdownParser.parse('- [ ]   task');
      final c = checkDoc.blocks.first as ChecklistItemBlock;
      expect(c.contentRange.slice('- [ ]   task'), equals('task'));
      expect(c.checked, isFalse);
    });

    test('P2-3 flanking rejects intra-word underscores and spaced emphasis', () {
      final snake = SemanticMarkdownParser.parse('snake_case_var');
      expect(snake.blocks.first.plainText, equals('snake_case_var'));
      expect(snake.blocks.first.plainText.contains('_'), isTrue);
      final p = snake.blocks.first as ParagraphBlock;
      expect(p.runs.every((r) => r is PlainRun), isTrue,
          reason: 'no emphasis runs for snake_case');

      final spaced = SemanticMarkdownParser.parse('a * b * c');
      expect(spaced.blocks.first.plainText, equals('a * b * c'));

      // Genuine emphasis must still parse.
      final real = SemanticMarkdownParser.parse('*real*');
      expect(real.blocks.first.plainText, equals('real'));
      expect((real.blocks.first as ParagraphBlock).runs.any((r) => r.isItalic), isTrue);
    });

    test('P2-3/P2-9 empty inline emphasis does not produce a degenerate run', () {
      // Inline `****` / `____` (surrounded by text so they are not block-level
      // horizontal rules) must stay literal rather than emitting an empty run.
      final stars = SemanticMarkdownParser.parse('a****b');
      expect(stars.blocks.first.plainText, equals('a****b'));
      final unders = SemanticMarkdownParser.parse('a____b');
      expect(unders.blocks.first.plainText, equals('a____b'));

      // A whole line of 4+ asterisks is still a horizontal rule (block level).
      final hr = SemanticMarkdownParser.parse('****');
      expect(hr.blocks.first, isA<HorizontalRuleBlock>());
    });

    test('P2-4 inline image is not parsed as a link and leaves no stray !', () {
      final doc = SemanticMarkdownParser.parse('see ![a](x.png) here');
      final p = doc.blocks.first as ParagraphBlock;
      expect(p.runs.any((r) => r is LinkRun), isFalse);
      expect(p.plainText, equals('see ![a](x.png) here'));
    });

    test('P2-5 space-separated thematic breaks parse as horizontal rules', () {
      for (final hr in const ['* * *', '- - -', '_ _ _']) {
        final doc = SemanticMarkdownParser.parse(hr);
        expect(doc.blocks.length, equals(1), reason: 'blocks for "$hr"');
        expect(doc.blocks.first, isA<HorizontalRuleBlock>(), reason: '"$hr" is HR');
      }
      // Two markers is still a list, not a rule.
      final list = SemanticMarkdownParser.parse('- x');
      expect(list.blocks.first, isA<ListItemBlock>());
    });

    test('P2-7 link URL keeps balanced parentheses', () {
      final doc = SemanticMarkdownParser.parse('[wiki](https://e.org/a_(b))');
      final p = doc.blocks.first as ParagraphBlock;
      final link = p.runs.whereType<LinkRun>().single;
      expect(link.destination, equals('https://e.org/a_(b)'));
      expect(link.text, equals('wiki'));
    });
  });
}
