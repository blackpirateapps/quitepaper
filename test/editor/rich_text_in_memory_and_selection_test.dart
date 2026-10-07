import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';
import 'package:quitepaper/features/editor/domain/text_attributes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';

void main() {
  group('In-Memory Rich Text Architecture & Bugfixes Tests', () {
    // =========================================================================
    // 1. JSON AST Serialization / Deserialization
    // =========================================================================
    group('1. RichDocument & Blocks JSON Round-trip', () {
      test('TextAttributes toJson and fromJson round-trip accurately', () {
        const attr = TextAttributes(
          isBold: true,
          isItalic: true,
          isStrike: true,
          isHighlight: true,
          isCode: true,
          linkUrl: 'https://quitepaper.app',
          linkTitle: 'Quiet Paper',
          noteLinkTarget: 'Welcome Note',
          tag: 'productivity',
        );

        final json = attr.toJson();
        final deserialized = TextAttributes.fromJson(json);

        expect(deserialized, attr);
        expect(deserialized.isBold, true);
        expect(deserialized.linkUrl, 'https://quitepaper.app');
        expect(deserialized.noteLinkTarget, 'Welcome Note');
        expect(deserialized.tag, 'productivity');
      });

      test('RichInlineSpan toJson and fromJson round-trip accurately', () {
        const span = RichInlineSpan(
          text: 'Formatted span',
          attributes: TextAttributes(isBold: true, isItalic: true),
        );

        final json = span.toJson();
        final deserialized = RichInlineSpan.fromJson(json);

        expect(deserialized.text, 'Formatted span');
        expect(deserialized.attributes.isBold, true);
        expect(deserialized.attributes.isItalic, true);
        expect(deserialized, span);
      });

      test('Polymorphic RichBlock toJson and fromJson round-trip for all 10 block types', () {
        final tables = const MarkdownTableParser().findTables('| Col1 | Col2 |\n|---|---|\n| Cell1 | Cell2 |');
        final testTable = tables.first;

        final blocks = <RichBlock>[
          // 1. Paragraph
          const ParagraphBlock(
            id: 'p-1',
            spans: [
              RichInlineSpan(text: 'Hello ', attributes: TextAttributes(isBold: true)),
              RichInlineSpan(text: 'world', attributes: TextAttributes(isItalic: true)),
            ],
          ),
          // 2. Heading
          const HeadingBlock(
            id: 'h-1',
            level: 2,
            spans: [RichInlineSpan(text: 'Subheading Title')],
          ),
          // 3. Checklist Item
          const ChecklistItemBlock(
            id: 'c-1',
            isChecked: true,
            spans: [RichInlineSpan(text: 'Completed task')],
          ),
          // 4. Bulleted List Item
          const BulletedListItemBlock(
            id: 'b-1',
            indent: 1,
            spans: [RichInlineSpan(text: 'Indented bullet')],
          ),
          // 5. Ordered List Item
          const OrderedListItemBlock(
            id: 'o-1',
            order: 3,
            indent: 0,
            spans: [RichInlineSpan(text: 'Third item')],
          ),
          // 6. Quote
          const QuoteBlock(
            id: 'q-1',
            spans: [RichInlineSpan(text: 'Wisdom quote')],
          ),
          // 7. Code Block
          const CodeBlock(
            id: 'cb-1',
            language: 'dart',
            code: 'void main() => print("test");',
          ),
          // 8. Horizontal Rule
          const HorizontalRuleBlock(id: 'hr-1'),
          // 9. Image Block
          const ImageBlock(
            id: 'img-1',
            url: 'https://quitepaper.app/icon.png',
            alt: 'Logo',
            title: 'Quiet Paper Logo',
          ),
          // 10. Table Block
          TableBlock(
            id: 'tbl-1',
            table: testTable,
          ),
        ];

        final doc = RichDocument(blocks: blocks);
        final json = doc.toJson();
        final deserialized = RichDocument.fromJson(json);

        expect(deserialized.blocks.length, 10);
        expect(deserialized.blocks[0], isA<ParagraphBlock>());
        expect((deserialized.blocks[0] as ParagraphBlock).spans[0].attributes.isBold, true);
        expect(deserialized.blocks[1], isA<HeadingBlock>());
        expect((deserialized.blocks[1] as HeadingBlock).level, 2);
        expect(deserialized.blocks[2], isA<ChecklistItemBlock>());
        expect((deserialized.blocks[2] as ChecklistItemBlock).isChecked, true);
        expect(deserialized.blocks[3], isA<BulletedListItemBlock>());
        expect((deserialized.blocks[3] as BulletedListItemBlock).indent, 1);
        expect(deserialized.blocks[4], isA<OrderedListItemBlock>());
        expect((deserialized.blocks[4] as OrderedListItemBlock).order, 3);
        expect(deserialized.blocks[5], isA<QuoteBlock>());
        expect(deserialized.blocks[6], isA<CodeBlock>());
        expect((deserialized.blocks[6] as CodeBlock).language, 'dart');
        expect(deserialized.blocks[7], isA<HorizontalRuleBlock>());
        expect(deserialized.blocks[8], isA<ImageBlock>());
        expect((deserialized.blocks[8] as ImageBlock).title, 'Quiet Paper Logo');
        expect(deserialized.blocks[9], isA<TableBlock>());
      });
    });

    // =========================================================================
    // 2. Enter Key Formatting Preservation
    // =========================================================================
    group('2. Enter Key Formatting Preservation', () {
      test('Enter on HeadingBlock preserves heading level on line 1 and creates paragraph on line 2', () {
        final controller = RichDocumentController(initialMarkdown: '# Main Heading');
        expect(controller.document.blocks.first, isA<HeadingBlock>());
        expect((controller.document.blocks.first as HeadingBlock).level, 1);

        // Caret at end of heading
        final headingId = controller.document.blocks.first.id;
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: headingId, offset: 12),
        ));

        controller.handleEnter();

        expect(controller.document.blocks.length, 2);
        // Line 1 must remain HeadingBlock level 1
        expect(controller.document.blocks[0], isA<HeadingBlock>());
        expect((controller.document.blocks[0] as HeadingBlock).level, 1);
        expect(controller.document.blocks[0].plainText, 'Main Heading');

        // Line 2 must be an empty ParagraphBlock
        expect(controller.document.blocks[1], isA<ParagraphBlock>());
        expect(controller.document.blocks[1].plainText, '');

        // Selection should be at line 2 offset 0
        expect(controller.selection.extent.blockIndex, 1);
        expect(controller.selection.extent.offset, 0);

        // Typing attributes should be clean
        expect(controller.typingAttributes.isBold, false);
      });

      test('Enter on Paragraph with bold text preserves bold spans on line 1', () {
        final controller = RichDocumentController(initialMarkdown: '**Bold Title**');
        final firstBlock = controller.document.blocks.first as ParagraphBlock;
        expect(firstBlock.spans.first.attributes.isBold, true);

        // Caret at end of bold title
        controller.updateSelection(RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: firstBlock.id, offset: 10),
        ));

        controller.handleEnter();

        expect(controller.document.blocks.length, 2);
        // Line 1 preserves bold span
        final line1 = controller.document.blocks[0] as ParagraphBlock;
        expect(line1.plainText, 'Bold Title');
        expect(line1.spans.first.attributes.isBold, true);

        // Line 2 is new clean paragraph
        final line2 = controller.document.blocks[1] as ParagraphBlock;
        expect(line2.plainText, '');
        expect(controller.typingAttributes.isBold, false);
      });

      testWidgets('RichTextEditor widget handles Enter key without losing formatting on desktop/IME', (tester) async {
        final controller = RichDocumentController(initialMarkdown: '## Project Roadmap');
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

        focusNode.requestFocus();
        await tester.pump();

        // Place caret at end
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // Simulate pressing Enter
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(controller.document.blocks.length, 2);
        expect(controller.document.blocks[0], isA<HeadingBlock>());
        expect((controller.document.blocks[0] as HeadingBlock).level, 2);
        expect(controller.document.blocks[0].plainText, 'Project Roadmap');
        expect(controller.document.blocks[1], isA<ParagraphBlock>());

        focusNode.dispose();
      });
    });

    // =========================================================================
    // 3. Selection Formatting
    // =========================================================================
    group('3. Selection Formatting', () {
      test('Selecting text and toggling bold/italic applies formatting across selection range', () {
        final controller = RichDocumentController(initialMarkdown: 'Quiet Paper App');
        final blockId = controller.document.blocks.first.id;

        // Select "Paper" (offsets 6 to 11)
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 6),
          extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 11),
        ));

        expect(controller.selection.isCollapsed, false);
        expect(controller.isBoldActive, false);

        // Toggle Bold
        controller.toggleBold();

        expect(controller.isBoldActive, true);
        final block = controller.document.blocks.first as ParagraphBlock;
        expect(block.spans.length, 3);
        expect(block.spans[0].text, 'Quiet ');
        expect(block.spans[0].attributes.isBold, false);
        expect(block.spans[1].text, 'Paper');
        expect(block.spans[1].attributes.isBold, true);
        expect(block.spans[2].text, ' App');
        expect(block.spans[2].attributes.isBold, false);

        // Toggle Italic on the same selection
        controller.toggleItalic();
        expect(controller.isItalicActive, true);
        final updatedBlock = controller.document.blocks.first as ParagraphBlock;
        expect(updatedBlock.spans[1].attributes.isBold, true);
        expect(updatedBlock.spans[1].attributes.isItalic, true);

        // Toggle Strikethrough
        controller.toggleStrike();
        expect(controller.isStrikeActive, true);
        final strikeBlock = controller.document.blocks.first as ParagraphBlock;
        expect(strikeBlock.spans[1].attributes.isStrike, true);

        // Toggle Highlight
        controller.toggleHighlight();
        expect(controller.isHighlightActive, true);
        final highlightBlock = controller.document.blocks.first as ParagraphBlock;
        expect(highlightBlock.spans[1].attributes.isHighlight, true);

        // Toggle Inline Code
        controller.toggleCode();
        expect(controller.isCodeActive, true);
        final codeBlock = controller.document.blocks.first as ParagraphBlock;
        expect(codeBlock.spans[1].attributes.isCode, true);
      });

      test('Multi-block selection applies block formatting across all selected blocks', () {
        final controller = RichDocumentController(
          initialMarkdown: 'First paragraph\nSecond paragraph\nThird paragraph',
        );
        expect(controller.document.blocks.length, 3);

        // Select from block 0 to block 1
        controller.updateSelection(RichDocumentSelection(
          base: RichDocumentPosition(
            blockIndex: 0,
            blockId: controller.document.blocks[0].id,
            offset: 2,
          ),
          extent: RichDocumentPosition(
            blockIndex: 1,
            blockId: controller.document.blocks[1].id,
            offset: 5,
          ),
        ));

        // Set Heading Level 2 across selection
        controller.setHeadingLevel(2);

        expect(controller.document.blocks[0], isA<HeadingBlock>());
        expect((controller.document.blocks[0] as HeadingBlock).level, 2);
        expect(controller.document.blocks[1], isA<HeadingBlock>());
        expect((controller.document.blocks[1] as HeadingBlock).level, 2);
        // Third block untouched
        expect(controller.document.blocks[2], isA<ParagraphBlock>());

        // Toggle Checklist across selection
        controller.toggleChecklist();
        expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
        expect(controller.document.blocks[1], isA<ChecklistItemBlock>());
        expect(controller.document.blocks[2], isA<ParagraphBlock>());
      });

      testWidgets('Selecting text in RichTextEditor updates controller selection without collapsing', (tester) async {
        final controller = RichDocumentController(initialMarkdown: 'Visual Rich Text Editor');
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

        // Find TextField and set non-collapsed selection
        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        editableText.controller.selection = const TextSelection(baseOffset: 7, extentOffset: 16);
        await tester.pump();

        // Verify controller selection is NOT collapsed
        expect(controller.selection.isCollapsed, false);
        expect(controller.selection.start.offset, 7);
        expect(controller.selection.end.offset, 16);

        // Format selection as bold
        controller.toggleBold();
        await tester.pump();

        final block = controller.document.blocks.first as ParagraphBlock;
        expect(block.spans.any((s) => s.text == 'Rich Text' && s.attributes.isBold), true);

        focusNode.dispose();
      });
    });

    // =========================================================================
    // 4. In-Memory Typing Architecture
    // =========================================================================
    group('4. In-Memory Typing Architecture', () {
      test('Typing in memory marks document dirty without calling toMarkdown() per keystroke', () {
        var markdownExportCount = 0;
        final controller = RichDocumentController(
          initialMarkdown: 'Initial note',
          onDocumentChanged: (_) {
            // Observer notified of AST change
          },
        );

        expect(controller.isDirty, false);

        // Simulate typing into block spans
        controller.updateBlockSpans(0, [
          const RichInlineSpan(text: 'Initial note updated'),
        ]);

        expect(controller.isDirty, true);
        expect(markdownExportCount, 0); // No premature markdown serialization!

        // Markdown is only generated on demand (e.g. save debouncer or manual flush)
        final markdown = controller.toMarkdown();
        markdownExportCount++;
        expect(markdown, 'Initial note updated');
        expect(markdownExportCount, 1);

        controller.markClean();
        expect(controller.isDirty, false);
      });

      test('Direct AST setDocument updates in-memory model without regex reparsing', () {
        final controller = RichDocumentController(initialMarkdown: 'Old text');
        final newDoc = RichDocument(blocks: [
          const HeadingBlock(
            id: 'h-custom',
            level: 3,
            spans: [RichInlineSpan(text: 'Direct AST Update')],
          ),
        ]);

        controller.setDocument(newDoc);

        expect(controller.document.blocks.first, isA<HeadingBlock>());
        expect(controller.document.blocks.first.id, 'h-custom');
        expect(controller.document.blocks.first.plainText, 'Direct AST Update');
      });
    });
  });
}
