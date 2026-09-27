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

  group('VisualDocumentEditor P3-6b performance & lifecycle', () {
    testWidgets('parent Focus regaining focus restores a block via the single consolidated path', (tester) async {
      const md = 'First paragraph\n\nSecond paragraph';
      final controller = SemanticEditorController(initialMarkdown: md);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // No block is focused yet; the parent gaining focus must delegate down to
      // a block field. Previously two competing paths (a manual focusNode
      // listener and Focus.onFocusChange) did this; now it is one path.
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final focusedFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((tf) => tf.focusNode?.hasFocus ?? false);
      expect(focusedFields, isNotEmpty,
          reason: 'a block field should receive focus from the parent');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('windowed spacer uses a measured height estimate and converges without a rebuild loop', (tester) async {
      // 120 blocks exceeds the 80-block window threshold, so off-screen blocks
      // are represented by a spacer whose height comes from the measured
      // per-block estimate. If the post-frame measurement/setState failed to
      // converge, pumpAndSettle would time out here.
      final lines = List.generate(
        120,
        (i) => 'Block $i content long enough to render on a line',
      );
      final controller = SemanticEditorController(initialMarkdown: lines.join('\n'));
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      final spacer = find.byKey(const ValueKey('viewport_bottom_spacer'));
      expect(spacer, findsOneWidget);
      // Spacer stands in for the ~79 off-window blocks, so its height must be
      // a positive multiple of the (measured) per-block estimate.
      expect(tester.getSize(spacer).height, greaterThan(0));

      focusNode.dispose();
      controller.dispose();
    });
  });
}
