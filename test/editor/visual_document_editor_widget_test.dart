import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

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

  group('VisualDocumentEditor Widget Tests', () {
    testWidgets('renders heading, paragraph, list, checklist, quote, and code blocks cleanly', (tester) async {
      const md = '# Main Heading\n\nParagraph text here.\n\n- [ ] Todo item\n- [x] Done item\n\n- Bullet item\n\n1. Numbered item\n\n> Blockquote text\n\n```dart\nfinal x = 42;\n```';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Verify heading is rendered without # in text
      expect(find.widgetWithText(TextField, 'Main Heading'), findsOneWidget);
      expect(find.text('# Main Heading'), findsNothing);

      // Verify paragraph
      expect(find.widgetWithText(TextField, 'Paragraph text here.'), findsOneWidget);

      // Verify checklist items
      expect(find.widgetWithText(TextField, 'Todo item'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Done item'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      // Verify bullet item without - in text
      expect(find.widgetWithText(TextField, 'Bullet item'), findsOneWidget);
      expect(find.text('•'), findsOneWidget);

      // Verify numbered item without 1. in text
      expect(find.widgetWithText(TextField, 'Numbered item'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);

      // Verify quote without > in text
      expect(find.widgetWithText(TextField, 'Blockquote text'), findsOneWidget);

      // Verify code block
      expect(find.text('dart'), findsOneWidget); // Language pill
      expect(find.widgetWithText(TextField, 'final x = 42;\n'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('tapping checkbox toggles check/uncheck in canonical Markdown immediately', (tester) async {
      const md = '- [ ] First task\n- [x] Second task';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => updatedMarkdown = val,
      ));
      await tester.pumpAndSettle();

      // Tap the unchecked square icon of the first task
      final squareIcon = find.byIcon(PhosphorIconsRegular.square);
      expect(squareIcon, findsOneWidget);
      await tester.tap(squareIcon);
      await tester.pumpAndSettle();

      // First task should now be checked in canonical Markdown
      expect(controller.markdown, contains('- [x] First task'));
      expect(updatedMarkdown, contains('- [x] First task'));

      // Tap the checked icon of the second task to uncheck it
      final checkedIcon = find.byIcon(PhosphorIconsFill.checkSquare);
      expect(checkedIcon, findsNWidgets(2)); // Both are now checked
      await tester.tap(checkedIcon.at(1));
      await tester.pumpAndSettle();

      expect(controller.markdown, contains('- [ ] Second task'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('typing inside a block updates canonical Markdown without modifying structure', (tester) async {
      const md = '# Title\nBody text';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => updatedMarkdown = val,
      ));
      await tester.pumpAndSettle();

      final bodyField = find.widgetWithText(TextField, 'Body text');
      expect(bodyField, findsOneWidget);

      await tester.enterText(bodyField, 'Body text modified');
      await tester.pumpAndSettle();

      expect(controller.markdown, equals('# Title\nBody text modified'));
      expect(updatedMarkdown, equals('# Title\nBody text modified'));

      focusNode.dispose();
      controller.dispose();
    });
  });
}
