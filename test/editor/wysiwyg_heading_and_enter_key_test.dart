import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

void main() {
  Widget buildTestableWidget({
    required SemanticEditorController controller,
    required FocusNode focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: VisualDocumentEditor(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  group('Visual Document Editor — Heading & Enter Key Fixes', () {
    testWidgets('Enter key in heading creates a new paragraph below and moves focus', (tester) async {
      const md = '# My Heading';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final headingField = find.widgetWithText(TextField, 'My Heading');
      expect(headingField, findsOneWidget);

      // Focus heading field
      await tester.tap(headingField);
      await tester.pumpAndSettle();

      // Simulate Enter key insertion via text input formatter
      await tester.enterText(headingField, 'My Heading\n');
      await tester.pumpAndSettle();

      // Controller markdown should now contain the heading and a trailing newline
      expect(controller.document.blocks.length, equals(2));
      expect(controller.document.blocks[0], isA<HeadingBlock>());
      expect(controller.document.blocks[1], isA<ParagraphBlock>());
      expect(controller.selection.base.blockId, equals(controller.document.blocks[1].id));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Enter key in paragraph splits block into a new line', (tester) async {
      const md = 'HelloWorld';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final pField = find.widgetWithText(TextField, 'HelloWorld');
      expect(pField, findsOneWidget);

      await tester.tap(pField);
      await tester.pumpAndSettle();

      // Simulate Enter after "Hello"
      await tester.enterText(pField, 'Hello\nWorld');
      await tester.pumpAndSettle();

      expect(controller.document.blocks.length, equals(2));
      expect(controller.document.blocks[0].plainText, equals('Hello'));
      expect(controller.document.blocks[1].plainText, equals('World'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Typing # and space in a paragraph converts to heading with stable block ID', (tester) async {
      const md = 'Hello';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final initialBlockId = controller.document.blocks.first.id;

      final pField = find.widgetWithText(TextField, 'Hello');
      await tester.enterText(pField, '# Hello');
      await tester.pumpAndSettle();

      // Block should now be a HeadingBlock
      expect(controller.document.blocks.first, isA<HeadingBlock>());
      // Block ID should remain stable (no _p -> _h1 change that disposes FocusNode)
      expect(controller.document.blocks.first.id, equals(initialBlockId));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Backspace on empty heading converts it to normal paragraph', (tester) async {
      const md = '# ';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Verify heading block initially
      expect(controller.document.blocks.first, isA<HeadingBlock>());

      final headingBlockId = controller.document.blocks.first.id;

      // Simulate backspace at offset 0
      controller.mergeWithPreviousBlock(headingBlockId);
      await tester.pumpAndSettle();

      // Block should now be converted to ParagraphBlock
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(controller.markdown, equals(''));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('FormattingToolbar cycles through all available heading styles H1 to H6 and back to paragraph', (tester) async {
      const md = 'Some content';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: 'Some content');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              VisualDocumentEditor(
                controller: controller,
                focusNode: focusNode,
              ),
              FormattingToolbar(
                controller: textController,
                focusNode: focusNode,
                semanticController: controller,
                onTagPressed: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final headingBtn = find.byTooltip('Heading (cycle H1-H6, long-press for options)');
      expect(headingBtn, findsOneWidget);

      // Initially Paragraph
      expect(controller.document.blocks.first, isA<ParagraphBlock>());

      // Tap 1 -> H1
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect((controller.document.blocks.first as HeadingBlock).level, equals(1));

      // Tap 2 -> H2
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect((controller.document.blocks.first as HeadingBlock).level, equals(2));

      // Tap 3 -> H3
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect((controller.document.blocks.first as HeadingBlock).level, equals(3));

      // Tap 4 -> H4
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect((controller.document.blocks.first as HeadingBlock).level, equals(4));

      // Tap 5 -> H5
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect((controller.document.blocks.first as HeadingBlock).level, equals(5));

      // Tap 6 -> H6
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect((controller.document.blocks.first as HeadingBlock).level, equals(6));

      // Tap 7 -> Converts back to Paragraph (level 0)
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<ParagraphBlock>());

      // Tap 8 -> H1 again
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect((controller.document.blocks.first as HeadingBlock).level, equals(1));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Tapping heading button in FormattingToolbar on an empty line preserves focus and collapsed selection at 0', (tester) async {
      const md = '';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: '');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              VisualDocumentEditor(
                controller: controller,
                focusNode: focusNode,
              ),
              FormattingToolbar(
                controller: textController,
                focusNode: focusNode,
                semanticController: controller,
                onTagPressed: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final headingBtn = find.byTooltip('Heading (cycle H1-H6, long-press for options)');
      expect(headingBtn, findsOneWidget);

      // Tap heading on empty line -> becomes H1
      await tester.tap(headingBtn);
      await tester.pumpAndSettle();

      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect(controller.markdown, equals('# '));
      expect(controller.selection.base.offset, equals(0));

      final headingField = find.byType(TextField);
      expect(headingField, findsOneWidget);

      final textFieldWidget = tester.widget<TextField>(headingField);
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);
      expect(textFieldWidget.controller?.selection.isCollapsed, isTrue);
      expect(textFieldWidget.controller?.selection.baseOffset, equals(0));
      expect(textFieldWidget.showCursor, isTrue);
      expect(textFieldWidget.key, isNotNull);

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Converting empty paragraph to heading preserves TextField GlobalKey and focus', (tester) async {
      const md = '';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VisualDocumentEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final initialField = find.byType(TextField);
      expect(initialField, findsOneWidget);
      final initialKey = tester.widget<TextField>(initialField).key;
      expect(initialKey, isNotNull);

      // Focus the field
      await tester.tap(initialField);
      await tester.pumpAndSettle();

      // Type # and space
      await tester.enterText(initialField, '# ');
      await tester.pumpAndSettle();

      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect(controller.markdown, equals('# '));

      final headingField = find.byType(TextField);
      expect(headingField, findsOneWidget);

      final headingTextField = tester.widget<TextField>(headingField);
      // Key should be preserved across widget tree transformations (GlobalKey)
      expect(headingTextField.key, equals(initialKey));
      expect(headingTextField.focusNode?.hasFocus, isTrue);
      expect(headingTextField.controller?.selection.baseOffset, equals(0));
      expect(headingTextField.showCursor, isTrue);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Parent focusNode forwards focus to active block in VisualDocumentEditor', (tester) async {
      const md = '# Header\nParagraph';
      final controller = SemanticEditorController(initialMarkdown: md);
      final parentFocusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VisualDocumentEditor(
            controller: controller,
            focusNode: parentFocusNode,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Request focus on parentFocusNode (as EditorScreen does when tapping blank area)
      parentFocusNode.requestFocus();
      await tester.pumpAndSettle();

      // The first block in VisualDocumentEditor should receive focus
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      final firstTextField = tester.widget<TextField>(textFields.first);
      expect(firstTextField.focusNode?.hasFocus, isTrue);

      parentFocusNode.dispose();
      controller.dispose();
    });

    testWidgets('Empty heading block has visible cursor and clean TextSpan root with heading fontSize', (tester) async {
      const md = '# ';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VisualDocumentEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final headingField = find.byType(TextField);
      expect(headingField, findsOneWidget);

      final textFieldWidget = tester.widget<TextField>(headingField);
      expect(textFieldWidget.controller?.text, isEmpty);
      expect(textFieldWidget.showCursor, isTrue);
      expect(textFieldWidget.cursorWidth, equals(2.0));

      final BuildContext context = tester.element(headingField);
      final span = textFieldWidget.controller?.buildTextSpan(
        context: context,
        style: textFieldWidget.style,
        withComposing: false,
      );

      // Verify root span has text '' directly (not nested empty children)
      expect(span, isA<TextSpan>());
      final textSpan = span as TextSpan;
      expect(textSpan.text, equals(''));
      expect(textSpan.children, isNull);

      focusNode.dispose();
      controller.dispose();
    });
  });
}
