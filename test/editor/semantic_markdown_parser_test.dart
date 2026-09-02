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
  });
}
