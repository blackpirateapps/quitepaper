import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/document_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

void main() {
  group('WYSIWYG Edit Mode Selection Bug Tests', () {
    testWidgets('Bug 1: Selecting a word in an unfocused block preserves word selection and does not collapse to 0', (tester) async {
      const md = '# Heading Title\n\nSecond paragraph with multiple words to select.\n\nThird paragraph here.';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDocumentEditor(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Focus the heading initially
      final headingTf = find.widgetWithText(TextField, 'Heading Title');
      await tester.tap(headingTf);
      await tester.pumpAndSettle();

      expect(controller.selection.base.blockId, equals(controller.document.blocks[0].id));

      // Now select the word "multiple" in the second paragraph
      final secondTfFinder = find.widgetWithText(TextField, 'Second paragraph with multiple words to select.');
      expect(secondTfFinder, findsOneWidget);

      final secondTf = tester.widget<TextField>(secondTfFinder);
      final secondCtrl = secondTf.controller!;
      final secondFn = secondTf.focusNode!;

      // Simulate a user selecting "multiple" in the second block:
      // Focus changes to second block, and selection is set to (22, 30) ("multiple")
      secondFn.requestFocus();
      secondCtrl.selection = const TextSelection(baseOffset: 22, extentOffset: 30);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(secondCtrl.selection.isCollapsed, isFalse,
          reason: 'Selection on second block must NOT be collapsed');
      expect(secondCtrl.selection.baseOffset, equals(22));
      expect(secondCtrl.selection.extentOffset, equals(30));

      expect(controller.selection.isCollapsed, isFalse,
          reason: 'Semantic selection must NOT be collapsed');
      expect(controller.selection.base.blockId, equals(controller.document.blocks[2].id));
      expect(controller.selection.base.offset, equals(22));
      expect(controller.selection.extent.offset, equals(30));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Bug 2: Drag selection in an unfocused block is not stomped by post-frame callback', (tester) async {
      const md = 'Paragraph One Content\n\nParagraph Two Content';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDocumentEditor(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap first block to focus it
      final firstTfFinder = find.widgetWithText(TextField, 'Paragraph One Content');
      await tester.tap(firstTfFinder);
      await tester.pumpAndSettle();

      // Now focus second block and drag-select "Two" (offset 10 to 13)
      final secondTfFinder = find.widgetWithText(TextField, 'Paragraph Two Content');
      final secondTf = tester.widget<TextField>(secondTfFinder);
      final secondCtrl = secondTf.controller!;
      final secondFn = secondTf.focusNode!;

      secondFn.requestFocus();
      secondCtrl.selection = const TextSelection(baseOffset: 10, extentOffset: 13);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(secondCtrl.selection, equals(const TextSelection(baseOffset: 10, extentOffset: 13)));
      expect(controller.selection.base.offset, equals(10));
      expect(controller.selection.extent.offset, equals(13));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Bug 3: Formatting toolbar bold applies to the currently selected text across block focus switch', (tester) async {
      const md = 'First block\n\nSecond block text';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDocumentEditor(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Focus first block
      final firstTfFinder = find.widgetWithText(TextField, 'First block');
      await tester.tap(firstTfFinder);
      await tester.pumpAndSettle();

      // Select "block" in second block (offset 7 to 12)
      final secondTfFinder = find.widgetWithText(TextField, 'Second block text');
      final secondTf = tester.widget<TextField>(secondTfFinder);
      final secondCtrl = secondTf.controller!;
      final secondFn = secondTf.focusNode!;

      secondFn.requestFocus();
      secondCtrl.selection = const TextSelection(baseOffset: 7, extentOffset: 12);
      await tester.pump();
      await tester.pumpAndSettle();

      // Toggle bold on controller
      controller.toggleBold();
      await tester.pumpAndSettle();

      expect(controller.markdown, equals('First block\n\nSecond **block** text'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Bug 4: Ctrl+A shortcut selects all text in focused block and updates semantic controller', (tester) async {
      const md = 'Short block\n\nAnother block to select completely';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDocumentEditor(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Focus second block
      final secondTfFinder = find.widgetWithText(TextField, 'Another block to select completely');
      await tester.tap(secondTfFinder);
      await tester.pumpAndSettle();

      // Send Ctrl+A
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final secondTf = tester.widget<TextField>(secondTfFinder);
      final secondCtrl = secondTf.controller!;

      // Verify block text is selected
      expect(secondCtrl.selection.baseOffset, equals(0));
      expect(secondCtrl.selection.extentOffset, equals('Another block to select completely'.length));

      // Verify controller selection is updated
      expect(controller.selection.base.offset, equals(0));
      expect(controller.selection.extent.offset, equals('Another block to select completely'.length));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Bug 5: Multi-block DocumentSelection projects selection onto affected block controllers', (tester) async {
      const md = 'First paragraph\n\nSecond paragraph';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisualDocumentEditor(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Focus editor
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final firstBlock = controller.document.blocks[0];
      final secondBlock = controller.document.blocks[2];

      // Set multi-block selection across first and second paragraphs
      controller.selection = DocumentSelection(
        base: DocumentPosition(blockId: firstBlock.id, offset: 6),
        extent: DocumentPosition(blockId: secondBlock.id, offset: 6),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final firstTfFinder = find.widgetWithText(TextField, 'First paragraph');
      final secondTfFinder = find.widgetWithText(TextField, 'Second paragraph');

      final firstCtrl = tester.widget<TextField>(firstTfFinder).controller!;
      final secondCtrl = tester.widget<TextField>(secondTfFinder).controller!;

      expect(firstCtrl.selection.baseOffset, equals(6));
      expect(firstCtrl.selection.extentOffset, equals('First paragraph'.length));

      expect(secondCtrl.selection.baseOffset, equals(0));
      expect(secondCtrl.selection.extentOffset, equals(6));

      focusNode.dispose();
      controller.dispose();
    });
  });
}
