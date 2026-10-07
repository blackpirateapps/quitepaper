import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';

void main() {
  group('Rich Text Editor — Formattings One by One Unit & Widget Tests', () {
    late RichDocumentController controller;
    const parser = RichDocumentParser();
    const serializer = RichDocumentSerializer();

    setUp(() {
      controller = RichDocumentController();
    });

    // =========================================================================
    // 1. BOLD
    // =========================================================================
    group('1. Bold Formatting', () {
      test('Toggling bold on selection applies bold attribute', () {
        controller.setMarkdown('Hello world');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 11),
        ));

        controller.toggleBold();
        expect(controller.toMarkdown(), 'Hello **world**');

        // Toggle off
        controller.toggleBold();
        expect(controller.toMarkdown(), 'Hello world');
      });

      test('Toggling bold on collapsed caret toggles typingAttributes', () {
        controller.setMarkdown('Hello');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
        ));

        expect(controller.isBoldActive, false);
        controller.toggleBold();
        expect(controller.isBoldActive, true);
        controller.toggleBold();
        expect(controller.isBoldActive, false);
      });

      test('Round-trip bold parses and serializes accurately', () {
        const md = '**Bold text** and __alternate bold__';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 1);
        final spans = doc.blocks.first.spans;
        expect(spans[0].text, 'Bold text');
        expect(spans[0].attributes.isBold, true);
        expect(serializer.serialize(doc), '**Bold text** and **alternate bold**');
      });
    });

    // =========================================================================
    // 2. ITALIC
    // =========================================================================
    group('2. Italic Formatting', () {
      test('Toggling italic on selection applies italic attribute', () {
        controller.setMarkdown('Hello world');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 11),
        ));

        controller.toggleItalic();
        expect(controller.toMarkdown(), 'Hello *world*');

        controller.toggleItalic();
        expect(controller.toMarkdown(), 'Hello world');
      });

      test('Toggling italic on collapsed caret toggles typingAttributes', () {
        controller.setMarkdown('Hello');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
        ));

        expect(controller.isItalicActive, false);
        controller.toggleItalic();
        expect(controller.isItalicActive, true);
        controller.toggleItalic();
        expect(controller.isItalicActive, false);
      });

      test('Round-trip italic parses and serializes accurately', () {
        const md = '*Italic text* and _alternate italic_';
        final doc = parser.parse(md);
        expect(doc.blocks.first.spans[0].attributes.isItalic, true);
        expect(serializer.serialize(doc), '*Italic text* and *alternate italic*');
      });
    });

    // =========================================================================
    // 3. STRIKETHROUGH
    // =========================================================================
    group('3. Strikethrough Formatting', () {
      test('Toggling strikethrough on selection applies strike attribute', () {
        controller.setMarkdown('Cross this out');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 10),
        ));

        controller.toggleStrike();
        expect(controller.toMarkdown(), '~~Cross this~~ out');

        controller.toggleStrike();
        expect(controller.toMarkdown(), 'Cross this out');
      });

      test('Toggling strike on collapsed caret toggles typingAttributes', () {
        controller.setMarkdown('Text');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 4),
        ));

        expect(controller.isStrikeActive, false);
        controller.toggleStrike();
        expect(controller.isStrikeActive, true);
        controller.toggleStrike();
        expect(controller.isStrikeActive, false);
      });

      test('Round-trip strikethrough parses and serializes accurately', () {
        const md = '~~Deleted content~~';
        final doc = parser.parse(md);
        expect(doc.blocks.first.spans[0].attributes.isStrike, true);
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 4. HIGHLIGHT
    // =========================================================================
    group('4. Highlight Formatting', () {
      test('Toggling highlight on selection applies highlight attribute', () {
        controller.setMarkdown('Important note here');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 9),
        ));

        controller.toggleHighlight();
        expect(controller.toMarkdown(), '==Important== note here');

        controller.toggleHighlight();
        expect(controller.toMarkdown(), 'Important note here');
      });

      test('Toggling highlight on collapsed caret toggles typingAttributes', () {
        controller.setMarkdown('Text');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 4),
        ));

        expect(controller.isHighlightActive, false);
        controller.toggleHighlight();
        expect(controller.isHighlightActive, true);
        controller.toggleHighlight();
        expect(controller.isHighlightActive, false);
      });

      test('Round-trip highlight parses and serializes accurately', () {
        const md = '==Highlighted note==';
        final doc = parser.parse(md);
        expect(doc.blocks.first.spans[0].attributes.isHighlight, true);
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 5. INLINE CODE
    // =========================================================================
    group('5. Inline Code Formatting', () {
      test('Toggling code on selection applies monospace code attribute', () {
        controller.setMarkdown('Call the function now');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 9),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 17),
        ));

        controller.toggleCode();
        expect(controller.toMarkdown(), 'Call the `function` now');

        controller.toggleCode();
        expect(controller.toMarkdown(), 'Call the function now');
      });

      test('Inline code is atomic and preserves special characters', () {
        const md = 'Use `const x = **not_bold**;` in dart';
        final doc = parser.parse(md);
        final codeSpan = doc.blocks.first.spans.firstWhere((s) => s.attributes.isCode);
        expect(codeSpan.text, 'const x = **not_bold**;');
        expect(codeSpan.attributes.isBold, false);
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 6. EXTERNAL LINKS
    // =========================================================================
    group('6. External Hyperlinks', () {
      test('Applying link on non-empty selection converts text to link', () {
        controller.setMarkdown('Visit Google today');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 12),
        ));

        controller.applyLink(url: 'https://google.com');
        expect(controller.toMarkdown(), 'Visit [Google](https://google.com) today');

        // Removing link
        controller.removeLink();
        expect(controller.toMarkdown(), 'Visit Google today');
      });

      test('Applying link on collapsed caret inserts link span at cursor', () {
        controller.setMarkdown('Visit  today');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
        ));

        controller.applyLink(url: 'https://flutter.dev', title: 'Flutter');
        expect(controller.toMarkdown(), 'Visit [Flutter](https://flutter.dev) today');
      });

      test('Applying link on collapsed caret with empty title falls back to URL', () {
        controller.setMarkdown('Check ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
        ));

        controller.applyLink(url: 'https://example.com');
        expect(controller.toMarkdown(), 'Check [https://example.com](https://example.com)');
      });

      test('Round-trip external links with and without tooltip title', () {
        const md = '[Title](https://test.org "Tooltip") and [Simple](https://simple.com)';
        final doc = parser.parse(md);
        expect(doc.blocks.first.spans[0].attributes.linkUrl, 'https://test.org');
        expect(doc.blocks.first.spans[0].attributes.linkTitle, 'Tooltip');
        expect(doc.blocks.first.spans[2].attributes.linkUrl, 'https://simple.com');
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 7. WIKI NOTE LINKS
    // =========================================================================
    group('7. Wiki Note Links', () {
      test('Applying note link on selection converts text to [[Note Link]]', () {
        controller.setMarkdown('See Architecture for details');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 4),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 16),
        ));

        controller.applyNoteLink(target: 'Architecture');
        expect(controller.toMarkdown(), 'See [[Architecture]] for details');
      });

      test('Applying note link on collapsed caret inserts [[target]] span', () {
        controller.setMarkdown('Reference: ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 11),
        ));

        controller.applyNoteLink(target: 'Roadmap');
        expect(controller.toMarkdown(), 'Reference: [[Roadmap]]');
      });

      test('Round-trip note link parses and serializes accurately', () {
        const md = 'Check [[Meeting Notes]] next week';
        final doc = parser.parse(md);
        expect(doc.blocks.first.spans[1].attributes.noteLinkTarget, 'Meeting Notes');
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 8. HASHTAGS
    // =========================================================================
    group('8. Hashtags', () {
      test('Applying tag on selection formats as hashtag', () {
        controller.setMarkdown('This is urgent task');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 8),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 14),
        ));

        controller.applyTag(tag: 'urgent');
        expect(controller.toMarkdown(), 'This is #urgent task');
      });

      test('Applying tag on collapsed caret inserts hashtag span', () {
        controller.setMarkdown('Tagged with ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 12),
        ));

        controller.applyTag(tag: 'flutter');
        expect(controller.toMarkdown(), 'Tagged with #flutter');
      });

      test('Round-trip hashtags parses and serializes accurately', () {
        const md = 'Status is #done and #in-review';
        final doc = parser.parse(md);
        final tagSpans = doc.blocks.first.spans.where((s) => s.attributes.hasTag).toList();
        expect(tagSpans.length, 2);
        expect(tagSpans[0].attributes.tag, 'done');
        expect(tagSpans[1].attributes.tag, 'in-review');
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 9. COMPOSABLE INLINES
    // =========================================================================
    group('9. Composable Inline Formattings', () {
      test('Bold and Italic combined serialize to ***text***', () {
        controller.setMarkdown('Emphasis');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 8),
        ));

        controller.toggleBold();
        controller.toggleItalic();
        expect(controller.toMarkdown(), '***Emphasis***');
      });

      test('Bold, Strikethrough, and Highlight composability round-trips cleanly', () {
        const md = '**~~==All three styles==~~**';
        final doc = parser.parse(md);
        final span = doc.blocks.first.spans.first;
        expect(span.attributes.isBold, true);
        expect(span.attributes.isStrike, true);
        expect(span.attributes.isHighlight, true);
        expect(span.text, 'All three styles');
        expect(serializer.serialize(doc), md);
      });

      test('Hyperlink with bold label round-trips accurately', () {
        const md = '**[Bold Link](https://dart.dev)**';
        final doc = parser.parse(md);
        final span = doc.blocks.first.spans.first;
        expect(span.attributes.isBold, true);
        expect(span.attributes.linkUrl, 'https://dart.dev');
        expect(span.text, 'Bold Link');
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 10. HEADINGS
    // =========================================================================
    group('10. Headings (H1 to H6)', () {
      test('Setting heading level from 1 to 6 updates block type and level', () {
        controller.setMarkdown('My Title');
        for (var lvl = 1; lvl <= 6; lvl++) {
          controller.setHeadingLevel(lvl);
          expect(controller.document.blocks.first, isA<HeadingBlock>());
          expect((controller.document.blocks.first as HeadingBlock).level, lvl);
          expect(controller.toMarkdown(), '${'#' * lvl} My Title');
        }
      });

      test('Heading cycling cycles P -> H1 -> H2 -> H3 -> P', () {
        controller.setMarkdown('Cycling text');
        expect(controller.document.blocks.first, isA<ParagraphBlock>());

        controller.cycleHeadingLevel();
        expect(controller.activeHeadingLevel, 1);

        controller.cycleHeadingLevel();
        expect(controller.activeHeadingLevel, 2);

        controller.cycleHeadingLevel();
        expect(controller.activeHeadingLevel, 3);

        controller.cycleHeadingLevel();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });

      test('Enter key inside heading creates paragraph below', () {
        controller.setMarkdown('# Heading One');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 11),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 2);
        expect(controller.document.blocks[0], isA<HeadingBlock>());
        expect(controller.document.blocks[1], isA<ParagraphBlock>());
        expect(controller.document.blocks[1].plainText, '');
      });

      test('Backspace at start of heading converts it to paragraph', () {
        controller.setMarkdown('## Section Title');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
        ));

        controller.handleBackspaceAtStart();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
        expect(controller.document.blocks.first.plainText, 'Section Title');
        expect(controller.toMarkdown(), 'Section Title');
      });
    });

    // =========================================================================
    // 11. CHECKLISTS
    // =========================================================================
    group('11. Checklists', () {
      test('Toggle checklist converts paragraph to checklist item and back', () {
        controller.setMarkdown('Buy groceries');
        controller.toggleChecklist();
        expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
        expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, false);
        expect(controller.toMarkdown(), '- [ ] Buy groceries');

        controller.toggleChecklist();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
        expect(controller.toMarkdown(), 'Buy groceries');
      });

      test('Toggling checklist item checked status', () {
        controller.setMarkdown('- [ ] Task');
        controller.toggleChecklistItemChecked(0);
        expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, true);
        expect(controller.toMarkdown(), '- [x] Task');

        controller.toggleChecklistItemChecked(0);
        expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, false);
        expect(controller.toMarkdown(), '- [ ] Task');
      });

      test('Enter on completed checklist item creates new UNCHECKED item', () {
        controller.setMarkdown('- [x] Finished task');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 13),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 2);
        expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
        expect((controller.document.blocks[1] as ChecklistItemBlock).isChecked, false);
        expect(controller.document.blocks[1].plainText, '');
      });

      test('Enter on empty checklist item exits checklist into paragraph', () {
        controller.setMarkdown('- [ ] ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 1);
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });

      test('Backspace at start of checklist item converts to paragraph', () {
        controller.setMarkdown('- [ ] Item');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
        ));

        controller.handleBackspaceAtStart();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
        expect(controller.document.blocks.first.plainText, 'Item');
      });
    });

    // =========================================================================
    // 12. BULLETED LISTS
    // =========================================================================
    group('12. Bulleted Lists', () {
      test('Toggle bulleted list converts paragraph to bullet item and back', () {
        controller.setMarkdown('First point');
        controller.toggleBulletedList();
        expect(controller.document.blocks.first, isA<BulletedListItemBlock>());
        expect(controller.toMarkdown(), '- First point');

        controller.toggleBulletedList();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
        expect(controller.toMarkdown(), 'First point');
      });

      test('Enter on bulleted list item creates continuation bullet', () {
        controller.setMarkdown('- Point 1');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 7),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 2);
        expect(controller.document.blocks[1], isA<BulletedListItemBlock>());
        expect(controller.document.blocks[1].plainText, '');
      });

      test('Enter on empty bulleted item exits list to paragraph', () {
        controller.setMarkdown('- ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 1);
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });

      test('Indented bulleted list parses and serializes indentation cleanly', () {
        const md = '- Root\n  - Nested level 1\n    - Nested level 2';
        final doc = parser.parse(md);
        expect((doc.blocks[0] as BulletedListItemBlock).indent, 0);
        expect((doc.blocks[1] as BulletedListItemBlock).indent, 1);
        expect((doc.blocks[2] as BulletedListItemBlock).indent, 2);
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 13. ORDERED LISTS
    // =========================================================================
    group('13. Ordered Lists', () {
      test('Toggle ordered list converts paragraph to numbered item', () {
        controller.setMarkdown('Step one');
        controller.toggleOrderedList();
        expect(controller.document.blocks.first, isA<OrderedListItemBlock>());
        expect((controller.document.blocks.first as OrderedListItemBlock).order, 1);
        expect(controller.toMarkdown(), '1. Step one');

        controller.toggleOrderedList();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });

      test('Enter on ordered item creates next incremented item (1. -> 2.)', () {
        controller.setMarkdown('1. First step');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 10),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 2);
        expect((controller.document.blocks[1] as OrderedListItemBlock).order, 2);
      });

      test('Enter on empty ordered item exits list into paragraph', () {
        controller.setMarkdown('1. ');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 1);
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });
    });

    // =========================================================================
    // 14. BLOCKQUOTES
    // =========================================================================
    group('14. Blockquotes', () {
      test('Toggle quote converts paragraph to QuoteBlock and back', () {
        controller.setMarkdown('A profound statement');
        controller.toggleQuote();
        expect(controller.document.blocks.first, isA<QuoteBlock>());
        expect(controller.toMarkdown(), '> A profound statement');

        controller.toggleQuote();
        expect(controller.document.blocks.first, isA<ParagraphBlock>());
      });

      test('Enter on quote creates continuation quote, empty quote exits', () {
        controller.setMarkdown('> Quote line 1');
        final blockId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 12),
        ));

        controller.handleEnter();
        expect(controller.document.blocks.length, 2);
        expect(controller.document.blocks[1], isA<QuoteBlock>());

        // Now Enter on empty quote line exits
        controller.handleEnter();
        expect(controller.document.blocks[1], isA<ParagraphBlock>());
      });
    });

    // =========================================================================
    // 15. CODE BLOCKS
    // =========================================================================
    group('15. Fenced Code Blocks', () {
      test('Insert code block creates CodeBlock and editable paragraph below', () {
        controller.setMarkdown('Above code');
        controller.insertCodeBlock(language: 'dart', code: 'void main() {}');
        expect(controller.document.blocks.length, 3);
        expect(controller.document.blocks[1], isA<CodeBlock>());
        final cb = controller.document.blocks[1] as CodeBlock;
        expect(cb.language, 'dart');
        expect(cb.code, 'void main() {}');
        expect(controller.document.blocks[2], isA<ParagraphBlock>());
      });

      test('Code blocks round-trip verbatim with multiline content', () {
        const md = '```json\n{\n  "status": "ok"\n}\n```';
        final doc = parser.parse(md);
        expect(doc.blocks.length, 1);
        expect(doc.blocks.first, isA<CodeBlock>());
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 16. HORIZONTAL RULES
    // =========================================================================
    group('16. Horizontal Rules', () {
      test('Insert horizontal rule creates Divider and paragraph below', () {
        controller.setMarkdown('Top section');
        controller.insertHorizontalRule();
        expect(controller.document.blocks.length, 3);
        expect(controller.document.blocks[1], isA<HorizontalRuleBlock>());
        expect(controller.document.blocks[2], isA<ParagraphBlock>());
        expect(controller.toMarkdown(), 'Top section\n---\n');
      });

      test('Round-trip horizontal rules (---, ***, ___)', () {
        const md = 'Top\n---\nMiddle\n***\nBottom';
        final doc = parser.parse(md);
        expect(doc.blocks[1], isA<HorizontalRuleBlock>());
        expect(doc.blocks[3], isA<HorizontalRuleBlock>());
        expect(serializer.serialize(doc), 'Top\n---\nMiddle\n---\nBottom');
      });
    });

    // =========================================================================
    // 17. TABLES
    // =========================================================================
    group('17. Markdown Tables', () {
      test('Insert table creates TableBlock with specified rows and columns', () {
        controller.setMarkdown('Before table');
        controller.insertTable(rows: 2, cols: 2);
        expect(controller.document.blocks.length, 3);
        expect(controller.document.blocks[1], isA<TableBlock>());
        final tb = controller.document.blocks[1] as TableBlock;
        expect(tb.table.columnCount, 2);
        expect(tb.table.rowCount, 3); // 1 header + 2 body rows
      });

      test('Markdown table round-trips with column alignment', () {
        const md = '| Item | Price |\n| :--- | ---: |\n| Apple | \$1.00 |';
        final doc = parser.parse(md);
        expect(doc.blocks.first, isA<TableBlock>());
        final serialized = serializer.serialize(doc);
        expect(serialized, contains('| Item | Price |'));
        expect(serialized, contains('| :--- | ---: |'));
        expect(serialized, contains('| Apple | \$1.00 |'));
      });
    });

    // =========================================================================
    // 18. IMAGES
    // =========================================================================
    group('18. Images', () {
      test('Insert image creates ImageBlock and paragraph below', () {
        controller.setMarkdown('Caption above');
        controller.insertImage(path: 'https://example.com/photo.jpg', alt: 'A sunset');
        expect(controller.document.blocks.length, 3);
        expect(controller.document.blocks[1], isA<ImageBlock>());
        final img = controller.document.blocks[1] as ImageBlock;
        expect(img.url, 'https://example.com/photo.jpg');
        expect(img.alt, 'A sunset');
      });

      test('Image round-trips with optional title', () {
        const md = '![Logo](https://site.com/logo.png "Company Logo")';
        final doc = parser.parse(md);
        expect(doc.blocks.first, isA<ImageBlock>());
        final img = doc.blocks.first as ImageBlock;
        expect(img.title, 'Company Logo');
        expect(serializer.serialize(doc), md);
      });
    });

    // =========================================================================
    // 19. WIDGET RENDERING & TYPING SPAN PRESERVATION (CRITICAL BUG DETECTION)
    // =========================================================================
    group('19. RichTextEditor Widget & Typing Span Preservation', () {
      testWidgets('Renders TextSpans with correct styling for all inlines', (tester) async {
        controller.setMarkdown('Normal **Bold** *Italic* ~~Strike~~ ==Highlight== `Code` [Link](https://x.com) #tag');
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: RichTextEditor(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        final richTextCtrl = textField.controller!;
        final span = richTextCtrl.buildTextSpan(
          context: tester.element(find.byType(TextField)),
          withComposing: false,
        );

        // Verify root span contains styled children
        expect(span.children, isNotEmpty);
        final children = span.children!;

        // 1. Bold child
        final boldSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Bold');
        expect(boldSpan.style?.fontWeight, FontWeight.bold);

        // 2. Italic child
        final italicSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Italic');
        expect(italicSpan.style?.fontStyle, FontStyle.italic);

        // 3. Strikethrough child
        final strikeSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Strike');
        expect(strikeSpan.style?.decoration, TextDecoration.lineThrough);

        // 4. Highlight child
        final highlightSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Highlight');
        expect(highlightSpan.style?.backgroundColor, isNotNull);

        // 5. Code child
        final codeSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Code');
        expect(codeSpan.style?.fontFamily, isNotNull);

        // 6. Link child
        final linkSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == 'Link');
        expect(linkSpan.style?.decoration, TextDecoration.underline);

        // 7. Tag child
        final tagSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == '#tag');
        expect(tagSpan.style?.fontWeight, FontWeight.w600);

        focusNode.dispose();
      });

      testWidgets('Interactive checkbox tapping toggles task state', (tester) async {
        controller.setMarkdown('- [ ] First task\n- [x] Second task');
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: RichTextEditor(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);

        // Find checkbox icon widget and tap it
        final checkboxFinder = find.byType(GestureDetector);
        expect(checkboxFinder, findsWidgets);

        await tester.tap(checkboxFinder.first);
        await tester.pumpAndSettle();

        expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
        expect(controller.toMarkdown(), '- [x] First task\n- [x] Second task');

        focusNode.dispose();
      });

      testWidgets('Typing inside a line containing formatted spans PRESERVES existing formatting', (tester) async {
        controller.setMarkdown('Prefix **bold** suffix');
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: RichTextEditor(
                controller: controller,
                focusNode: focusNode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // Type at the end of the line
        await tester.enterText(textFieldFinder, 'Prefix bold suffix extra');
        await tester.pumpAndSettle();

        // The bold span must NOT be erased or collapsed to plain text!
        expect(controller.toMarkdown(), 'Prefix **bold** suffix extra');

        focusNode.dispose();
      });
    });
  });
}
