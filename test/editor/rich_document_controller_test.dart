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
