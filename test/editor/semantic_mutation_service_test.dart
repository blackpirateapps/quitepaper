import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/application/semantic_mutation_service.dart';
import 'package:quitepaper/features/editor/domain/document_position.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';

void main() {
  group('SemanticMutationService Tests', () {
    test('insertText inserts text at position and preserves remaining source', () {
      const initial = 'Hello World';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 6);

      final res = SemanticMutationService.insertText(initial, pos, 'Beautiful ');
      expect(res.markdown, equals('Hello Beautiful World'));
      expect(res.position.offset, equals(16));
    });

    test('deleteSelection deletes range and collapsed backspace', () {
      const initial = 'Hello Beautiful World';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      // Selection delete
      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 6),
        extent: DocumentPosition(blockId: p.id, offset: 16),
      );
      final resSel = SemanticMutationService.deleteSelection(initial, sel);
      expect(resSel.markdown, equals('Hello World'));

      // Collapsed backspace delete
      final pos = DocumentPosition(blockId: p.id, offset: 5);
      final resBack = SemanticMutationService.deleteSelection(
        'Hello World',
        DocumentSelection.collapsed(pos),
        isBackspace: true,
      );
      expect(resBack.markdown, equals('Hell World'));
    });

    test('toggleBold wraps plain text and unwraps bold text', () {
      const initial = 'This is bold text.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 8),
        extent: DocumentPosition(blockId: p.id, offset: 12),
      );

      // Wrap
      final resWrap = SemanticMutationService.toggleBold(initial, sel);
      expect(resWrap.markdown, equals('This is **bold** text.'));

      // Unwrap
      final docBold = resWrap.document;
      final selBold = DocumentSelection(
        base: DocumentPosition(blockId: docBold.blocks.first.id, offset: 8),
        extent: DocumentPosition(blockId: docBold.blocks.first.id, offset: 12),
      );
      final resUnwrap = SemanticMutationService.toggleBold(resWrap.markdown, selBold);
      expect(resUnwrap.markdown, equals('This is bold text.'));
    });

    test('toggleItalic wraps and unwraps italic text', () {
      const initial = 'This is italic text.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 8),
        extent: DocumentPosition(blockId: p.id, offset: 14),
      );

      final resWrap = SemanticMutationService.toggleItalic(initial, sel);
      expect(resWrap.markdown, equals('This is *italic* text.'));

      final docItalic = resWrap.document;
      final selItalic = DocumentSelection(
        base: DocumentPosition(blockId: docItalic.blocks.first.id, offset: 8),
        extent: DocumentPosition(blockId: docItalic.blocks.first.id, offset: 14),
      );
      final resUnwrap = SemanticMutationService.toggleItalic(resWrap.markdown, selItalic);
      expect(resUnwrap.markdown, equals('This is italic text.'));
    });

    test('toggleStrike wraps and unwraps strikethrough text', () {
      const initial = 'This is struck text.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 8),
        extent: DocumentPosition(blockId: p.id, offset: 14),
      );

      final resWrap = SemanticMutationService.toggleStrike(initial, sel);
      expect(resWrap.markdown, equals('This is ~~struck~~ text.'));
    });

    test('arbitrary combinations of bold, italic, and strikethrough mutate canonically', () {
      const initial = 'Hello world';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 6),
        extent: DocumentPosition(blockId: p.id, offset: 11),
      );

      // Apply bold -> **world**
      final res1 = SemanticMutationService.toggleBold(initial, sel);
      expect(res1.markdown, equals('Hello **world**'));

      // Apply italic on top -> ***world***
      final sel1 = DocumentSelection(
        base: DocumentPosition(blockId: res1.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: res1.document.blocks.first.id, offset: 11),
      );
      final res2 = SemanticMutationService.toggleItalic(res1.markdown, sel1);
      expect(res2.markdown, equals('Hello ***world***'));

      // Apply strikethrough on top -> ~~***world***~~
      final sel2 = DocumentSelection(
        base: DocumentPosition(blockId: res2.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: res2.document.blocks.first.id, offset: 11),
      );
      final res3 = SemanticMutationService.toggleStrike(res2.markdown, sel2);
      expect(res3.markdown, equals('Hello ~~***world***~~'));

      // Toggle bold off -> ~~*world*~~
      final sel3 = DocumentSelection(
        base: DocumentPosition(blockId: res3.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: res3.document.blocks.first.id, offset: 11),
      );
      final res4 = SemanticMutationService.toggleBold(res3.markdown, sel3);
      expect(res4.markdown, equals('Hello ~~*world*~~'));

      // Toggle strike off -> *world*
      final sel4 = DocumentSelection(
        base: DocumentPosition(blockId: res4.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: res4.document.blocks.first.id, offset: 11),
      );
      final res5 = SemanticMutationService.toggleStrike(res4.markdown, sel4);
      expect(res5.markdown, equals('Hello *world*'));

      // Toggle italic off -> world
      final sel5 = DocumentSelection(
        base: DocumentPosition(blockId: res5.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: res5.document.blocks.first.id, offset: 11),
      );
      final res6 = SemanticMutationService.toggleItalic(res5.markdown, sel5);
      expect(res6.markdown, equals('Hello world'));
    });

    test('selection with trailing space serializes cleanly preserving CommonMark flanking', () {
      const initial = 'Hello world peace';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      // Select "world " (with trailing space)
      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 6),
        extent: DocumentPosition(blockId: p.id, offset: 12),
      );

      final res = SemanticMutationService.toggleBold(initial, sel);
      expect(res.markdown, equals('Hello **world** peace'));
    });

    test('toggleInlineCode wraps and unwraps inline code', () {
      const initial = 'Run flutter test now.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 4),
        extent: DocumentPosition(blockId: p.id, offset: 16),
      );

      final resWrap = SemanticMutationService.toggleInlineCode(initial, sel);
      expect(resWrap.markdown, equals('Run `flutter test` now.'));
    });

    test('toggleLink creates [title](url) from selection', () {
      const initial = 'Visit Quiet Paper site.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 6),
        extent: DocumentPosition(blockId: p.id, offset: 17),
      );

      final res = SemanticMutationService.toggleLink(
        initial,
        sel,
        url: 'https://quietpaper.app',
      );
      expect(res.markdown, equals('Visit [Quiet Paper](https://quietpaper.app) site.'));
    });

    test('toggleNoteLink creates [[Note Title]] from selection', () {
      const initial = 'Refer to Roadmap for details.';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;

      final sel = DocumentSelection(
        base: DocumentPosition(blockId: p.id, offset: 9),
        extent: DocumentPosition(blockId: p.id, offset: 16),
      );

      final res = SemanticMutationService.toggleNoteLink(
        initial,
        sel,
        noteTitle: 'Roadmap',
      );
      expect(res.markdown, equals('Refer to [[Roadmap]] for details.'));
    });

    test('setHeadingLevel cycles between paragraph, H1, H2, and H3', () {
      const initial = 'My Section';
      final doc = SemanticMarkdownParser.parse(initial);
      final p = doc.blocks.first;
      final pos = DocumentPosition(blockId: p.id, offset: 2);

      // Paragraph -> H1
      final resH1 = SemanticMutationService.setHeadingLevel(initial, pos, 1);
      expect(resH1.markdown, equals('# My Section'));

      // H1 -> H2
      final docH1 = resH1.document;
      final posH1 = DocumentPosition(blockId: docH1.blocks.first.id, offset: 2);
      final resH2 = SemanticMutationService.setHeadingLevel(resH1.markdown, posH1, 2);
      expect(resH2.markdown, equals('## My Section'));

      // H2 -> Paragraph (0)
      final docH2 = resH2.document;
      final posH2 = DocumentPosition(blockId: docH2.blocks.first.id, offset: 2);
      final resP = SemanticMutationService.setHeadingLevel(resH2.markdown, posH2, 0);
      expect(resP.markdown, equals('My Section'));
    });

    test('checklist mutations (toggle, check/uncheck, Enter continuation, exit on empty)', () {
      const initial = 'Buy milk';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 8);

      // 1. Convert to checklist
      final resCheck = SemanticMutationService.toggleChecklist(initial, pos);
      expect(resCheck.markdown, equals('- [ ] Buy milk'));

      // 2. Check the box
      final checkBlock = resCheck.document.blocks.first as ChecklistItemBlock;
      final resToggled = SemanticMutationService.toggleChecklistState(resCheck.markdown, checkBlock.id);
      expect(resToggled.markdown, equals('- [x] Buy milk'));

      // 3. Uncheck the box
      final checkedBlock = resToggled.document.blocks.first as ChecklistItemBlock;
      final resUntoggled = SemanticMutationService.toggleChecklistState(resToggled.markdown, checkedBlock.id);
      expect(resUntoggled.markdown, equals('- [ ] Buy milk'));

      // 4. Press Enter on non-empty checklist -> creates new uncompleted item
      final posEnd = DocumentPosition(blockId: resUntoggled.document.blocks.first.id, offset: 8);
      final resEnter = SemanticMutationService.splitBlock(resUntoggled.markdown, posEnd);
      expect(resEnter.markdown, equals('- [ ] Buy milk\n- [ ] '));

      // 5. Press Enter on empty checklist item -> exits checklist to new paragraph
      final emptyItem = resEnter.document.blocks.last as ChecklistItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('- [ ] Buy milk\n\n'));
      expect(resExit.document.blocks.last, isA<ParagraphBlock>());
      expect(resExit.position.blockId, equals(resExit.document.blocks.last.id));
      expect(resExit.position.offset, equals(0));
    });

    test('list item mutations (toggle bullet, Enter continuation, exit on empty)', () {
      const initial = 'First item';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 10);

      // Convert to bullet
      final resList = SemanticMutationService.toggleList(initial, pos);
      expect(resList.markdown, equals('- First item'));

      // Enter continuation
      final posListEnd = DocumentPosition(blockId: resList.document.blocks.first.id, offset: 10);
      final resEnter = SemanticMutationService.splitBlock(resList.markdown, posListEnd);
      expect(resEnter.markdown, equals('- First item\n- '));

      // Enter on empty bullet exits list and starts a new paragraph
      final emptyItem = resEnter.document.blocks.last as ListItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('- First item\n\n'));
      expect(resExit.document.blocks.last, isA<ParagraphBlock>());
      expect(resExit.position.blockId, equals(resExit.document.blocks.last.id));
      expect(resExit.position.offset, equals(0));
    });

    test('ordered list item mutations (toggle ordered, Enter continuation with increment, exit on empty)', () {
      const initial = 'First step';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 10);

      // Convert to ordered list
      final resOrd = SemanticMutationService.toggleOrderedList(initial, pos);
      expect(resOrd.markdown, equals('1. First step'));

      // Enter continuation with increment
      final posEnd = DocumentPosition(blockId: resOrd.document.blocks.first.id, offset: 10);
      final resEnter = SemanticMutationService.splitBlock(resOrd.markdown, posEnd);
      expect(resEnter.markdown, equals('1. First step\n2. '));

      // Enter on empty ordered item exits list and starts a new paragraph
      final emptyItem = resEnter.document.blocks.last as OrderedListItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('1. First step\n\n'));
      expect(resExit.document.blocks.last, isA<ParagraphBlock>());
      expect(resExit.position.blockId, equals(resExit.document.blocks.last.id));
      expect(resExit.position.offset, equals(0));
    });

    test('pressing enter on item 1 of a 5-item ordered list intelligently renumbers all subsequent items 1 to 6', () {
      const initial = '1. Item 1\n2. Item 2\n3. Item 3\n4. Item 4\n5. Item 5';
      final doc = SemanticMarkdownParser.parse(initial);

      // Press Enter at end of Item 1
      final item1 = doc.blocks[0] as OrderedListItemBlock;
      final pos = DocumentPosition(blockId: item1.id, offset: item1.plainText.length);
      final res = SemanticMutationService.splitBlock(initial, pos);

      expect(res.markdown, equals('1. Item 1\n2. \n3. Item 2\n4. Item 3\n5. Item 4\n6. Item 5'));
      expect(res.document.blocks.length, equals(6));

      // Verify all numbers in sequence 1..6
      for (var i = 0; i < 6; i++) {
        expect(res.document.blocks[i], isA<OrderedListItemBlock>());
        final b = res.document.blocks[i] as OrderedListItemBlock;
        expect(b.number, equals(i + 1));
      }

      // Cursor position should be at new item 2 with offset 0
      expect(res.position.blockId, equals(res.document.blocks[1].id));
      expect(res.position.offset, equals(0));
    });

    test('pressing enter in the middle of an ordered list renumbers only following items', () {
      const initial = '1. A\n2. B\n3. C\n4. D';
      final doc = SemanticMarkdownParser.parse(initial);

      // Press Enter at end of Item 2 ('B')
      final item2 = doc.blocks[1] as OrderedListItemBlock;
      final pos = DocumentPosition(blockId: item2.id, offset: item2.plainText.length);
      final res = SemanticMutationService.splitBlock(initial, pos);

      expect(res.markdown, equals('1. A\n2. B\n3. \n4. C\n5. D'));
      expect(res.document.blocks.length, equals(5));

      final numbers = res.document.blocks.map((b) => (b as OrderedListItemBlock).number).toList();
      expect(numbers, equals([1, 2, 3, 4, 5]));
    });

    test('ordered list renumbering respects nested sublists and surrounding blocks', () {
      const initial = '1. Parent 1\n   1. Child 1\n   2. Child 2\n2. Parent 2\n\nParagraph\n\n1. Other list 1\n2. Other list 2';
      final doc = SemanticMarkdownParser.parse(initial);

      // Press Enter on Parent 1 (indent 0)
      final parent1 = doc.blocks[0] as OrderedListItemBlock;
      final pos = DocumentPosition(blockId: parent1.id, offset: parent1.plainText.length);
      final res = SemanticMutationService.splitBlock(initial, pos);

      // Parent 2 should be renumbered to 3, but Child items and Other list items must remain untouched
      final orderedBlocks = res.document.blocks.whereType<OrderedListItemBlock>().toList();
      expect(orderedBlocks.length, equals(7));

      // Parent 1 and newly inserted item 2
      expect(orderedBlocks[0].number, equals(1));
      expect(orderedBlocks[0].indent, equals(0));
      expect(orderedBlocks[1].number, equals(2));
      expect(orderedBlocks[1].indent, equals(0));

      // Child items remain 1 and 2
      expect(orderedBlocks[2].number, equals(1));
      expect(orderedBlocks[2].indent, equals(3));
      expect(orderedBlocks[3].number, equals(2));
      expect(orderedBlocks[3].indent, equals(3));

      // Parent 2 became 3
      expect(orderedBlocks[4].number, equals(3));
      expect(orderedBlocks[4].indent, equals(0));

      // Other list after paragraph remains 1 and 2
      expect(orderedBlocks[5].number, equals(1));
      expect(orderedBlocks[6].number, equals(2));
    });

    test('quote block mutations (toggle quote, Enter continuation, exit on empty)', () {
      const initial = 'Wise quote';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 10);

      // Convert to quote
      final resQuote = SemanticMutationService.toggleQuote(initial, pos);
      expect(resQuote.markdown, equals('> Wise quote'));

      // Enter continuation
      final posEnd = DocumentPosition(blockId: resQuote.document.blocks.first.id, offset: 10);
      final resEnter = SemanticMutationService.splitBlock(resQuote.markdown, posEnd);
      expect(resEnter.markdown, equals('> Wise quote\n> '));

      // Enter on empty quote exits quote
      final emptyQuote = resEnter.document.blocks.last as QuoteBlock;
      final posEmpty = DocumentPosition(blockId: emptyQuote.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('> Wise quote\n'));
    });

    test('code block mutations (create code block, change language)', () {
      const initial = 'Intro';
      final doc = SemanticMarkdownParser.parse(initial);
      final pos = DocumentPosition(blockId: doc.blocks.first.id, offset: 5);

      final resCode = SemanticMutationService.createCodeBlock(initial, pos, language: 'dart');
      expect(resCode.markdown, contains('```dart'));

      final codeBlock = resCode.document.blocks.firstWhere((b) => b is CodeBlock) as CodeBlock;
      final resLang = SemanticMutationService.changeCodeBlockLanguage(resCode.markdown, codeBlock.id, 'python');
      expect(resLang.markdown, contains('```python'));
    });

    test('horizontal rule mutations (empty doc, empty line, end of block, backspace deletion)', () {
      // 1. Insert on empty doc
      final resEmpty = SemanticMutationService.insertHorizontalRule('', const DocumentPosition(blockId: '', offset: 0));
      expect(resEmpty.markdown, equals('---\n\n'));
      expect(resEmpty.document.blocks.first, isA<HorizontalRuleBlock>());
      expect(resEmpty.document.blocks.length, greaterThanOrEqualTo(2));
      expect(resEmpty.document.blocks[1], isA<ParagraphBlock>());
      expect(resEmpty.position.blockId, equals(resEmpty.document.blocks[1].id));
      expect(resEmpty.position.offset, equals(0));

      // 2. Insert on empty line in multi-line doc
      const multiLine = 'First line\n\nThird line';
      final docMulti = SemanticMarkdownParser.parse(multiLine);
      final emptyLineBlock = docMulti.blocks[1];
      final resLine = SemanticMutationService.insertHorizontalRule(
        multiLine,
        DocumentPosition(blockId: emptyLineBlock.id, offset: 0),
      );
      expect(resLine.markdown, equals('First line\n---\n\nThird line'));
      expect(resLine.document.blocks[1], isA<HorizontalRuleBlock>());
      expect(resLine.document.blocks[2], isA<ParagraphBlock>());
      expect(resLine.position.blockId, equals(resLine.document.blocks[2].id));
      expect(resLine.position.offset, equals(0));

      // 3. Insert at end of block
      const singleLine = 'Hello world';
      final docSingle = SemanticMarkdownParser.parse(singleLine);
      final resEnd = SemanticMutationService.insertHorizontalRule(
        singleLine,
        DocumentPosition(blockId: docSingle.blocks.first.id, offset: 11),
      );
      expect(resEnd.markdown, equals('Hello world\n---\n\n'));
      expect(resEnd.document.blocks[1], isA<HorizontalRuleBlock>());
      expect(resEnd.document.blocks[2], isA<ParagraphBlock>());
      expect(resEnd.position.blockId, equals(resEnd.document.blocks[2].id));
      expect(resEnd.position.offset, equals(0));

      // 4. Backspace at offset 0 of empty line below divider deletes divider
      final resBackEmpty = SemanticMutationService.mergeWithPreviousBlock(
        resEnd.markdown,
        DocumentPosition(blockId: resEnd.document.blocks[2].id, offset: 0),
      );
      expect(resBackEmpty.markdown, equals('Hello world'));
      expect(resBackEmpty.document.blocks.any((b) => b is HorizontalRuleBlock), isFalse);

      // 5. Backspace at offset 0 of line with text below divider deletes divider
      const textBelow = 'Hello world\n---\nNext line';
      final docTextBelow = SemanticMarkdownParser.parse(textBelow);
      final nextLineBlock = docTextBelow.blocks.last;
      final resBackText = SemanticMutationService.mergeWithPreviousBlock(
        textBelow,
        DocumentPosition(blockId: nextLineBlock.id, offset: 0),
      );
      expect(resBackText.markdown, equals('Hello world\nNext line'));
      expect(resBackText.document.blocks.any((b) => b is HorizontalRuleBlock), isFalse);
    });
  });
}
