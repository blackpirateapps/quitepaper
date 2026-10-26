import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/block_editor_surface.dart';
import 'package:quitepaper/features/editor/presentation/widgets/blocks/block_wrapper.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_checklist_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_code_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';

void main() {
  group('Block-Based Visual Editor Surface Tests', () {
    Widget buildTestHarness({
      required RichDocumentController controller,
      required FocusNode focusNode,
      bool readOnly = false,
    }) {
      return MaterialApp(
        theme: AppTheme.classicLight(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
              child: BlockEditorSurface(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders autonomous block widgets for various block types', (tester) async {
      const md = '''# Title
First paragraph text.
- [ ] Task item 1
- Bullet point
> Quoted editorial text
```dart
void main() {}
```
---''';

      final controller = RichDocumentController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      // Verify discrete BlockWrappers exist
      expect(find.byType(BlockWrapper), findsNWidgets(7));
      expect(find.byType(RichTextEditor), findsNWidgets(4)); // Heading, Paragraph, Bullet, Quote
      expect(find.byType(RichChecklistEditor), findsOneWidget);
      expect(find.byType(RichCodeBlock), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Block reordering mutates document and preserves content', (tester) async {
      const md = '''Paragraph 1
Paragraph 2
Paragraph 3''';

      final controller = RichDocumentController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      // Move Paragraph 3 to index 0
      controller.moveBlock(2, 0);
      await tester.pumpAndSettle();

      expect(controller.document.blocks[0].plainText, 'Paragraph 3');
      expect(controller.document.blocks[1].plainText, 'Paragraph 1');
      expect(controller.document.blocks[2].plainText, 'Paragraph 2');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Typing "# " at block start converts paragraph to Heading 1', (tester) async {
      final controller = RichDocumentController(initialMarkdown: 'Hello');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      // Trigger markdown auto-conversion
      final converted = controller.handleAutoMarkdownTrigger(0, '# Hello world');
      expect(converted, isTrue);
      await tester.pumpAndSettle();

      expect(controller.document.blocks[0], isA<HeadingBlock>());
      expect((controller.document.blocks[0] as HeadingBlock).level, 1);
      expect(controller.document.blocks[0].plainText, 'Hello world');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Typing "[] " at block start converts paragraph to ChecklistItemBlock', (tester) async {
      final controller = RichDocumentController(initialMarkdown: 'Buy milk');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      final converted = controller.handleAutoMarkdownTrigger(0, '[] Buy milk');
      expect(converted, isTrue);
      await tester.pumpAndSettle();

      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);
      expect(controller.document.blocks[0].plainText, 'Buy milk');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Tapping checklist checkbox in ChecklistBlockWidget toggles checked state', (tester) async {
      final controller = RichDocumentController(initialMarkdown: '- [ ] Finish writing');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);

      // Tap checkbox
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, isTrue);
      expect(controller.toMarkdown(), '- [x] Finish writing');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Indenting and un-indenting checklist and list items', (tester) async {
      final controller = RichDocumentController(initialMarkdown: '- [ ] Root task');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).indent, 0);

      controller.indentBlock(0, 1);
      await tester.pumpAndSettle();
      expect((controller.document.blocks[0] as ChecklistItemBlock).indent, 1);
      expect(controller.toMarkdown(), '  - [ ] Root task');

      controller.indentBlock(0, -1);
      await tester.pumpAndSettle();
      expect((controller.document.blocks[0] as ChecklistItemBlock).indent, 0);
      expect(controller.toMarkdown(), '- [ ] Root task');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Deleting a block reduces block count and updates document', (tester) async {
      final controller = RichDocumentController(initialMarkdown: 'Block 1\nBlock 2');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestHarness(controller: controller, focusNode: focusNode));
      await tester.pumpAndSettle();

      expect(controller.document.blocks.length, 2);

      controller.deleteBlock(1);
      await tester.pumpAndSettle();

      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks[0].plainText, 'Block 1');

      focusNode.dispose();
      controller.dispose();
    });
  });
}
