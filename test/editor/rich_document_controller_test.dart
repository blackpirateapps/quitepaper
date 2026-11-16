import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';
import 'package:quitepaper/features/editor/domain/text_attributes.dart';

void main() {
  group('RichDocumentController & Mutations Unit Tests', () {
    late RichDocumentController controller;

    setUp(() {
      controller = RichDocumentController();
    });

    test('CL-10 structured paste uses the task caret and reopens losslessly', () {
      controller.setMarkdown('- [ ] **Alpha**\n- [ ] Neighbor');
      final neighbor = controller.document.blocks[1];
      controller.setSelectionFromGlobalOffset(5);
      controller.insertMarkdownSnippet('\n- [ ] Beta\n- [x] Gamma');
      expect(controller.toMarkdown(), '- [ ] **Alpha**\n- [ ] Beta\n- [x] Gamma\n- [ ] Neighbor');
      expect(controller.document.blocks.last, same(neighbor));
      expect(controller.selection.base.blockIndex, 2);
      expect(controller.selection.base.offset, 5);
      final reopened = RichDocumentController(initialMarkdown: controller.toJsonString());
      expect(reopened.toMarkdown(), controller.toMarkdown());
      reopened.dispose();
      controller.undo();
      expect(controller.toMarkdown(), '- [ ] **Alpha**\n- [ ] Neighbor');
    });

    for (final reversed in [false, true]) {
      test('CL-10 paste replaces a cross-task selection reverse=$reversed', () {
        controller.setMarkdown('- [ ] Alpha\n  - [x] Beta\n- [ ] Neighbor');
        final start = RichDocumentPosition(blockIndex: 0, blockId: controller.document.blocks[0].id, offset: 2);
        final end = RichDocumentPosition(blockIndex: 1, blockId: controller.document.blocks[1].id, offset: 2);
        controller.updateSelection(RichDocumentSelection(base: reversed ? end : start, extent: reversed ? start : end));
        controller.insertMarkdownSnippet('X\n  - [x] New');
        expect(controller.toMarkdown(), '- [ ] AlX\n  - [x] Newta\n- [ ] Neighbor');
        expect(controller.selection.base.offset, 3);
        controller.undo();
        expect(controller.toMarkdown(), '- [ ] Alpha\n  - [x] Beta\n- [ ] Neighbor');
      });
    }

    test('Math insertion keeps saved JSON valid and reopens without loss', () {
      controller.setMarkdown('Math existing body');
      final saved = controller.toJsonString();
      controller.setContent(saved);
      controller.insertMathBlock();
      expect(jsonDecode(controller.toJsonString()), isA<Map<String, dynamic>>());
      final reopened = RichDocumentController(initialMarkdown: controller.toJsonString());
      addTearDown(reopened.dispose);
      expect(reopened.document.blocks.first.plainText, 'Math existing body');
      expect(reopened.document.blocks.whereType<CodeBlock>().single.language, 'math');
      expect(reopened.toMarkdown(), contains('```math\nequation\n```'));
      controller.undo();
      expect(controller.document.blocks.whereType<CodeBlock>(), isEmpty);
      controller.redo();
      expect(controller.toMarkdown(), reopened.toMarkdown());
    });

    test('Malformed JSON-like content falls back once without recursion', () {
      final malformed = '${controller.toJsonString()}\n\\[\nequation\n\\]';
      controller.setContent(malformed);
      expect(jsonDecode(controller.toJsonString()), isA<Map<String, dynamic>>());
      controller.setMarkdown(malformed);
      expect(controller.toPlainText(), contains('equation'));
    });

    test('Initial state is single empty paragraph', () {
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(controller.document.blocks.first.plainText, '');
      expect(controller.toMarkdown(), '');
    });

    test('setMarkdown populates document', () {
      controller.setMarkdown('# Hello World\nThis is a paragraph.');
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<HeadingBlock>());
      expect(controller.document.blocks[0].plainText, 'Hello World');
      expect((controller.document.blocks[0] as HeadingBlock).level, 1);
      expect(controller.document.blocks[1], isA<ParagraphBlock>());
      expect(controller.document.blocks[1].plainText, 'This is a paragraph.');
    });

    test('Toggle checklist item checked status mutates and supports undo/redo', () {
      controller.setMarkdown('- [ ] Task 1\n- [x] Task 2');
      expect(controller.document.blocks.length, 2);

      final block1 = controller.document.blocks[0] as ChecklistItemBlock;
      expect(block1.isChecked, false);

      controller.toggleChecklistItemChecked(0);
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
      expect(controller.canUndo, true);

      controller.undo();
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);

      controller.redo();
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
    });

    test('Block type changes: paragraph to heading, quotes, and checklist', () {
      controller.setMarkdown('Plain text line');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
      ));

      // Change to Heading 2
      controller.setHeadingLevel(2);
      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect((controller.document.blocks.first as HeadingBlock).level, 2);
      expect(controller.document.blocks.first.plainText, 'Plain text line');

      // Change to Blockquote
      controller.toggleQuote();
      expect(controller.document.blocks.first, isA<QuoteBlock>());
      expect(controller.document.blocks.first.plainText, 'Plain text line');

      // Change to Checklist item
      controller.toggleChecklist();
      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, false);

      // Change back to Paragraph
      controller.convertBlockToParagraph(0);
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
    });

    test('Inline formatting toggle applies to selection range', () {
      controller.setMarkdown('Hello bold world');
      final blockId = controller.document.blocks.first.id;

      // Select "bold" (offset 6 to 10)
      controller.updateSelection(RichDocumentSelection(
        base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
        extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 10),
      ));

      // Apply bold
      controller.toggleBold();
      expect(controller.toMarkdown(), 'Hello **bold** world');

      // Undo bold
      controller.undo();
      expect(controller.toMarkdown(), 'Hello bold world');

      // Redo bold
      controller.redo();
      expect(controller.toMarkdown(), 'Hello **bold** world');
    });

    test('Inline formatting toggle on collapsed selection toggles typing attributes', () {
      controller.setMarkdown('Hello');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
      ));

      expect(controller.typingAttributes.isBold, false);
      controller.toggleBold();
      expect(controller.typingAttributes.isBold, true);

      controller.toggleBold();
      expect(controller.typingAttributes.isBold, false);
    });

    test('handleEnter splits block at offset', () {
      controller.setMarkdown('First part Second part');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 10), // after "First part"
      ));

      controller.handleEnter();
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0].plainText, 'First part');
      expect(controller.document.blocks[1].plainText, ' Second part');
      expect(controller.selection.extent.blockIndex, 1);
      expect(controller.selection.extent.offset, 0);
    });

    test('handleEnter on empty checklist item converts it to paragraph', () {
      controller.setMarkdown('- [ ] ');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
      ));

      controller.handleEnter();
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(controller.document.blocks.first.plainText, '');
    });

    test('handleEnter on empty bullet item converts it to paragraph', () {
      controller.setMarkdown('- ');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
      ));

      controller.handleEnter();
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
    });

    test('handleBackspaceAtStart on non-paragraph converts to paragraph', () {
      controller.setMarkdown('# Title');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 0),
      ));

      controller.handleBackspaceAtStart();
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(controller.document.blocks.first.plainText, 'Title');
    });

    test('handleBackspaceAtStart on second paragraph merges with previous block', () {
      controller.setMarkdown('First\nSecond');
      expect(controller.document.blocks.length, 2);
      final secondId = controller.document.blocks[1].id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 1, blockId: secondId, offset: 0),
      ));

      controller.handleBackspaceAtStart();
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks.first.plainText, 'FirstSecond');
    });

    test('Insert image adds ImageBlock after current block and paragraph below', () {
      controller.setMarkdown('Above image');
      final blockId = controller.document.blocks.first.id;
      controller.updateSelection(RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
      ));

      controller.insertImage(path: 'https://example.com/pic.png', alt: 'Sample');
      expect(controller.document.blocks.length, 3);
      expect(controller.document.blocks[1], isA<ImageBlock>());
      final img = controller.document.blocks[1] as ImageBlock;
      expect(img.url, 'https://example.com/pic.png');
      expect(img.alt, 'Sample');
      expect(controller.document.blocks[2], isA<ParagraphBlock>());
    });

    test('updateBlockSpans replaces spans in text block', () {
      controller.setMarkdown('Old text');
      expect(controller.document.blocks.first.plainText, 'Old text');

      controller.updateBlockSpans(0, [
        const RichInlineSpan(text: 'New text', attributes: TextAttributes(isBold: true)),
      ]);
      expect(controller.document.blocks.first.plainText, 'New text');
      expect(controller.toMarkdown(), '**New text**');
    });
  });
}
