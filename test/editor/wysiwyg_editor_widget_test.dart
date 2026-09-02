import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestEditor({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
    EditorEditingStyle editingStyle = EditorEditingStyle.wysiwyg,
    bool stripFrontmatter = false,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          focusNode: focusNode,
          editingStyle: editingStyle,
          stripFrontmatter: stripFrontmatter,
          onChanged: onChanged,
        ),
      ),
    );
  }

  group('MarkdownEditor WYSIWYG Widget Tests', () {
    testWidgets('renders visual text with delimiters hidden in WYSIWYG mode', (tester) async {
      final controller = MarkdownEditingController(text: '# My Heading\nThis is **bold** text.');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.wysiwyg,
      ));

      expect(find.byType(MarkdownEditor), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // In WYSIWYG, the TextField displays projected visual text
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('My Heading\nThis is bold text.'));
      // The underlying canonical source remains complete Markdown
      expect(controller.text, equals('# My Heading\nThis is **bold** text.'));
    });

    testWidgets('typing in WYSIWYG mode updates canonical Markdown controller', (tester) async {
      final controller = MarkdownEditingController(text: '# Title\nBody text.');
      final focusNode = FocusNode();
      String? updatedText;

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.wysiwyg,
        onChanged: (val) => updatedText = val,
      ));

      // Enter new text in WYSIWYG field
      await tester.enterText(find.byType(TextField), 'New Title\nUpdated body.');
      await tester.pumpAndSettle();

      expect(controller.text, equals('New Title\nUpdated body.'));
      expect(updatedText, equals('New Title\nUpdated body.'));
    });

    testWidgets('renders raw markdown syntax in Markdown mode', (tester) async {
      final controller = MarkdownEditingController(text: '# Raw Heading\n**bold**');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.markdown,
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('# Raw Heading\n**bold**'));
      expect(controller.text, equals('# Raw Heading\n**bold**'));
    });

    testWidgets('switching editingStyle dynamically updates presentation', (tester) async {
      final controller = MarkdownEditingController(text: '## Section\n*italic*');
      final focusNode = FocusNode();

      // 1. Initial WYSIWYG mode
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.wysiwyg,
      ));

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('Section\nitalic'));

      // 2. Switch to Markdown mode
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.markdown,
      ));

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('## Section\n*italic*'));
    });

    testWidgets('stripFrontmatter hides frontmatter from visual canvas in WYSIWYG mode', (tester) async {
      const fullDoc = '---\ntitle: Doc Title\nauthor: Jane\n---\n# Main Heading\nParagraph.';
      final controller = MarkdownEditingController(text: fullDoc);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        editingStyle: EditorEditingStyle.wysiwyg,
        stripFrontmatter: true,
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('Main Heading\nParagraph.'));
      expect(controller.text, equals(fullDoc));
    });
  });
}
