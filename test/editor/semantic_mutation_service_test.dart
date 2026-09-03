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

      // 5. Press Enter on empty checklist item -> exits checklist
      final emptyItem = resEnter.document.blocks.last as ChecklistItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('- [ ] Buy milk\n'));
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

      // Enter on empty bullet exits list
      final emptyItem = resEnter.document.blocks.last as ListItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('- First item\n'));
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

      // Enter on empty ordered item exits list
      final emptyItem = resEnter.document.blocks.last as OrderedListItemBlock;
      final posEmpty = DocumentPosition(blockId: emptyItem.id, offset: 0);
      final resExit = SemanticMutationService.splitBlock(resEnter.markdown, posEmpty);
      expect(resExit.markdown, equals('1. First step\n'));
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
  });
}
