import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/document_position.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

Widget buildTestApp({
  required SemanticEditorController controller,
  required FocusNode focusNode,
  ValueChanged<String>? onChanged,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: VisualDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
              ),
            ),
          ),
          FormattingToolbar(
            controller: TextEditingController(),
            semanticController: controller,
            onTagPressed: () {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('WYSIWYG Inline Formatting Engine Tests', () {
    testWidgets('Visual editor displays combined bold+italic+strike cleanly without visible markdown delimiters', (tester) async {
      const md = 'This is ~~***all three***~~ in visual mode.';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // In visual mode, delimiters must NOT be present in any TextField text
      expect(find.textContaining('***'), findsNothing);
      expect(find.textContaining('~~'), findsNothing);

      // The field should display clean plain text
      final textField = find.widgetWithText(TextField, 'This is all three in visual mode.');
      expect(textField, findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('FormattingToolbar highlights active styles when cursor enters formatted run', (tester) async {
      const md = 'Plain and **bold** and *italic* and ~~struck~~.';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Cursor at 0 (Plain text): no buttons active
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: controller.document.blocks.first.id, offset: 2),
      );
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isFalse);
      expect(controller.isItalicActive, isFalse);
      expect(controller.isStrikeActive, isFalse);

      // Cursor moves into "bold" (offset 12)
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: controller.document.blocks.first.id, offset: 12),
      );
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isTrue);
      expect(controller.isItalicActive, isFalse);
      expect(controller.isStrikeActive, isFalse);

      // Cursor moves into "italic" (offset 23)
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: controller.document.blocks.first.id, offset: 23),
      );
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isFalse);
      expect(controller.isItalicActive, isTrue);
      expect(controller.isStrikeActive, isFalse);

      // Cursor moves into "struck" (offset 35)
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: controller.document.blocks.first.id, offset: 35),
      );
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isFalse);
      expect(controller.isItalicActive, isFalse);
      expect(controller.isStrikeActive, isTrue);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Tapping toolbar buttons on a text selection formats with bold, italic, and strikethrough combinations', (tester) async {
      const md = 'Edit my word today.';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => updatedMarkdown = val,
      ));
      await tester.pumpAndSettle();

      final bButton = find.byTooltip('Bold (**text**)');
      final iButton = find.byTooltip('Italic (*text*)');
      final sButton = find.byTooltip('Strikethrough (~~text~~)');

      // Select "word" (offset 8 to 12)
      controller.selection = DocumentSelection(
        base: DocumentPosition(blockId: controller.document.blocks.first.id, offset: 8),
        extent: DocumentPosition(blockId: controller.document.blocks.first.id, offset: 12),
      );
      await tester.pumpAndSettle();

      // Tap Bold
      await tester.tap(bButton);
      await tester.pumpAndSettle();
      expect(controller.markdown, equals('Edit my **word** today.'));
      expect(controller.isBoldActive, isTrue);

      // Tap Italic (combines with Bold -> ***word***)
      await tester.tap(iButton);
      await tester.pumpAndSettle();
      expect(controller.markdown, equals('Edit my ***word*** today.'));
      expect(controller.isBoldActive, isTrue);
      expect(controller.isItalicActive, isTrue);

      // Tap Strikethrough (combines with Bold+Italic -> ~~***word***~~)
      await tester.tap(sButton);
      await tester.pumpAndSettle();
      expect(controller.markdown, equals('Edit my ~~***word***~~ today.'));
      expect(controller.isBoldActive, isTrue);
      expect(controller.isItalicActive, isTrue);
      expect(controller.isStrikeActive, isTrue);

      // In visual mode, user still sees clean text
      expect(find.widgetWithText(TextField, 'Edit my word today.'), findsOneWidget);

      // Tap Bold to toggle it off -> ~~*word*~~
      await tester.tap(bButton);
      await tester.pumpAndSettle();
      expect(controller.markdown, equals('Edit my ~~*word*~~ today.'));
      expect(updatedMarkdown, equals('Edit my ~~*word*~~ today.'));
      expect(controller.isBoldActive, isFalse);
      expect(controller.isItalicActive, isTrue);
      expect(controller.isStrikeActive, isTrue);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Toggling format at collapsed cursor enables active typing format and styles subsequent typing', (tester) async {
      const md = 'Hello';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => updatedMarkdown = val,
      ));
      await tester.pumpAndSettle();

      final bButton = find.byTooltip('Bold (**text**)');

      // Collapsed cursor at end (offset 5)
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: controller.document.blocks.first.id, offset: 5),
      );
      await tester.pumpAndSettle();

      // Tap Bold while collapsed
      await tester.tap(bButton);
      await tester.pumpAndSettle();

      // Toolbar bold button should immediately be active
      expect(controller.isBoldActive, isTrue);
      expect(controller.activeTypingFormats?.isBold, isTrue);

      // Now type ' bold' into visual block
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        'Hello bold',
        const TextSelection.collapsed(offset: 10),
      );
      await tester.pumpAndSettle();

      // Canonical markdown should wrap typed characters in **bold**, peeling leading spaces
      expect(controller.markdown, equals('Hello **bold**'));
      expect(updatedMarkdown, equals('Hello **bold**'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Typing a full sentence letter-by-letter in bold produces unified **I am good boy**', (tester) async {
      final controller = SemanticEditorController(initialMarkdown: '');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final bButton = find.byTooltip('Bold (**text**)');
      await tester.tap(bButton);
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isTrue);

      final blockId = controller.document.blocks.first.id;
      const sentence = 'I am good boy';
      for (var i = 1; i <= sentence.length; i++) {
        final currentText = sentence.substring(0, i);
        controller.handleVisualBlockTextChange(
          blockId,
          currentText,
          TextSelection.collapsed(offset: i),
        );
      }
      await tester.pumpAndSettle();

      // Must produce single unified **I am good boy**, NOT **I** **am** **good** **boy**
      expect(controller.markdown, equals('**I am good boy**'));
      expect(find.widgetWithText(TextField, 'I am good boy'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Typing a full sentence in bold+italic produces unified ***heyyy thanks.the typing exp is actually great.***', (tester) async {
      final controller = SemanticEditorController(initialMarkdown: '');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Turn on Bold and Italic
      final bButton = find.byTooltip('Bold (**text**)');
      final iButton = find.byTooltip('Italic (*text*)');
      await tester.tap(bButton);
      await tester.pumpAndSettle();
      await tester.tap(iButton);
      await tester.pumpAndSettle();
      expect(controller.isBoldActive, isTrue);
      expect(controller.isItalicActive, isTrue);

      final blockId = controller.document.blocks.first.id;
      const sentence = 'heyyy thanks.the typing exp is actually great.';
      for (var i = 1; i <= sentence.length; i++) {
        final currentText = sentence.substring(0, i);
        controller.handleVisualBlockTextChange(
          blockId,
          currentText,
          TextSelection.collapsed(offset: i),
        );
      }
      await tester.pumpAndSettle();

      // Must produce single unified ***...***, NOT ***word*** ***word***
      expect(controller.markdown, equals('***heyyy thanks.the typing exp is actually great.***'));
      expect(find.widgetWithText(TextField, 'heyyy thanks.the typing exp is actually great.'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Selecting a full multi-word sentence on plain text formats as unified **I am good boy**', (tester) async {
      const initial = 'Hello I am good boy today';
      final controller = SemanticEditorController(initialMarkdown: initial);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final bButton = find.byTooltip('Bold (**text**)');

      // Select "I am good boy" (offset 6 to 19)
      controller.selection = DocumentSelection(
        base: DocumentPosition(blockId: controller.document.blocks.first.id, offset: 6),
        extent: DocumentPosition(blockId: controller.document.blocks.first.id, offset: 19),
      );
      await tester.pumpAndSettle();

      await tester.tap(bButton);
      await tester.pumpAndSettle();

      expect(controller.markdown, equals('Hello **I am good boy** today'));
      expect(find.widgetWithText(TextField, 'Hello I am good boy today'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Fragmented Markdown normalizes into unified sentence syntax upon edit', (tester) async {
      const fragmented = '**name** **the** **date.** and you will be great.';
      final controller = SemanticEditorController(initialMarkdown: fragmented);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Visual editor displays clean text
      expect(find.widgetWithText(TextField, 'name the date. and you will be great.'), findsOneWidget);

      // AST runs are unified into a single bold run
      final block = controller.document.blocks.first as ParagraphBlock;
      expect(block.runs.first.text, equals('name the date.'));
      expect(block.runs.first.isBold, isTrue);

      // Position cursor at end of plain text (offset 36) before typing '!'
      controller.selection = DocumentSelection.collapsed(
        DocumentPosition(blockId: block.id, offset: 36),
      );
      await tester.pumpAndSettle();

      // Any edit in the block normalizes canonical Markdown
      controller.handleVisualBlockTextChange(
        block.id,
        'name the date. and you will be great!',
        const TextSelection.collapsed(offset: 37),
      );
      await tester.pumpAndSettle();

      expect(controller.markdown, equals('**name the date.** and you will be great!'));

      focusNode.dispose();
      controller.dispose();
    });
  });
}
