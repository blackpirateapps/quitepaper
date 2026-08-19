import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestEditor({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
    bool isDark = false,
  }) {
    return MaterialApp(
      theme: isDark
          ? ThemeData.dark().copyWith(extensions: [AppColors.dark])
          : ThemeData.light().copyWith(extensions: [AppColors.light]),
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          focusNode: focusNode,
        ),
      ),
    );
  }

  group('MarkdownEditor Widget Tests', () {
    testWidgets('renders initial Markdown text and allows typing and editing', (tester) async {
      final controller = MarkdownEditingController(text: '# Hello\nThis is **bold** text.');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
      ));

      expect(find.byType(MarkdownEditor), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, equals('# Hello\nThis is **bold** text.'));

      // Enter text
      await tester.enterText(find.byType(TextField), '# New Title\n- Item 1\n- Item 2');
      await tester.pumpAndSettle();

      expect(controller.text, equals('# New Title\n- Item 1\n- Item 2'));
    });

    testWidgets('supports cursor positioning and selection in Markdown source', (tester) async {
      final controller = MarkdownEditingController(text: 'Hello **world**');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
      ));

      // Set selection inside "**world**"
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 15);
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, equals(6));
      expect(controller.selection.extentOffset, equals(15));
      expect(controller.text.substring(controller.selection.start, controller.selection.end),
          equals('**world**'));
    });

    testWidgets('renders cleanly in both Light and Dark themes', (tester) async {
      final controller = MarkdownEditingController(text: '# Light & Dark Theme Support\n`code`');
      final focusNode = FocusNode();

      // Light theme
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        isDark: false,
      ));
      expect(find.byType(MarkdownEditor), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        isDark: true,
      ));
      expect(find.byType(MarkdownEditor), findsOneWidget);
    });

    group('FUTO Android IME Composing & Caret Advancement Regression Tests', () {
      testWidgets('incrementally typing "# " and repeated spaces after hashes advances caret and preserves text', (tester) async {
        final controller = MarkdownEditingController();
        final focusNode = FocusNode();

        await tester.pumpWidget(buildTestEditor(
          controller: controller,
          focusNode: focusNode,
        ));

        focusNode.requestFocus();
        await tester.pump();

        const sequence = ['#', '# ', '#  ', '#   ', '#    '];
        double previousCaretX = -1.0;

        for (var i = 0; i < sequence.length; i++) {
          final text = sequence[i];
          // Simulate FUTO IME composing active over typed input
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(start: 0, end: text.length),
          );
          await tester.pump();

          expect(controller.text, equals(text));

          final renderEditable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
          expect(renderEditable.text!.toPlainText(), equals(text));

          final caretRect = renderEditable.getLocalRectForCaret(TextPosition(offset: text.length));
          expect(caretRect.height, greaterThan(0));
          if (previousCaretX >= 0) {
            expect(caretRect.left, greaterThan(previousCaretX),
                reason: 'Caret must advance after typing "$text" (step $i)');
          }
          previousCaretX = caretRect.left;
        }
      });

      testWidgets('incrementally typing "# Hello " and repeated trailing spaces advances caret and preserves text', (tester) async {
        final controller = MarkdownEditingController();
        final focusNode = FocusNode();

        await tester.pumpWidget(buildTestEditor(
          controller: controller,
          focusNode: focusNode,
        ));

        focusNode.requestFocus();
        await tester.pump();

        final sequence = [
          ('#', const TextRange(start: 0, end: 1)),
          ('# ', const TextRange(start: 0, end: 2)),
          ('# H', const TextRange(start: 2, end: 3)),
          ('# He', const TextRange(start: 2, end: 4)),
          ('# Hel', const TextRange(start: 2, end: 5)),
          ('# Hell', const TextRange(start: 2, end: 6)),
          ('# Hello', const TextRange(start: 2, end: 7)),
          ('# Hello ', const TextRange(start: 2, end: 8)),
          ('# Hello  ', const TextRange(start: 2, end: 9)),
          ('# Hello   ', const TextRange(start: 2, end: 10)),
        ];

        double previousCaretX = -1.0;

        for (var i = 0; i < sequence.length; i++) {
          final (text, composing) = sequence[i];
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: composing,
          );
          await tester.pump();

          expect(controller.text, equals(text));

          final renderEditable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
          expect(renderEditable.text!.toPlainText(), equals(text));

          final caretRect = renderEditable.getLocalRectForCaret(TextPosition(offset: text.length));
          expect(caretRect.height, greaterThan(0));
          if (previousCaretX >= 0) {
            expect(caretRect.left, greaterThan(previousCaretX),
                reason: 'Caret must advance after step $i: "$text"');
          }
          previousCaretX = caretRect.left;
        }
      });

      testWidgets('incrementally typing "# Hello world" with spaces between words advances caret at every character and space', (tester) async {
        final controller = MarkdownEditingController();
        final focusNode = FocusNode();

        await tester.pumpWidget(buildTestEditor(
          controller: controller,
          focusNode: focusNode,
        ));

        focusNode.requestFocus();
        await tester.pump();

        const fullText = '# Hello world';
        double previousCaretX = -1.0;

        for (var len = 1; len <= fullText.length; len++) {
          final currentText = fullText.substring(0, len);
          final lastSpace = currentText.lastIndexOf(' ');
          final compStart = lastSpace == -1 ? 0 : lastSpace + 1;
          final composing = TextRange(start: compStart, end: len);

          controller.value = TextEditingValue(
            text: currentText,
            selection: TextSelection.collapsed(offset: len),
            composing: composing,
          );
          await tester.pump();

          expect(controller.text, equals(currentText));

          final renderEditable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
          expect(renderEditable.text!.toPlainText(), equals(currentText));

          final caretRect = renderEditable.getLocalRectForCaret(TextPosition(offset: len));
          expect(caretRect.height, greaterThan(0));
          if (previousCaretX >= 0) {
            expect(caretRect.left, greaterThan(previousCaretX),
                reason: 'Caret must advance at offset $len for "$currentText"');
          }
          previousCaretX = caretRect.left;
        }
      });

      testWidgets('all heading levels # through ###### advance caret properly on spaces with composing', (tester) async {
        final controller = MarkdownEditingController();
        final focusNode = FocusNode();

        await tester.pumpWidget(buildTestEditor(
          controller: controller,
          focusNode: focusNode,
        ));

        focusNode.requestFocus();
        await tester.pump();

        for (var level = 1; level <= 6; level++) {
          final hashes = '#' * level;
          final steps = [
            hashes,
            '$hashes ',
            '$hashes  ',
            '$hashes Heading $level',
            '$hashes Heading $level ',
            '$hashes Heading $level  ',
          ];

          double previousCaretX = -1.0;
          for (final text in steps) {
            controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange(start: 0, end: text.length),
            );
            await tester.pump();

            expect(controller.text, equals(text));

            final renderEditable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
            expect(renderEditable.text!.toPlainText(), equals(text));

            final caretRect = renderEditable.getLocalRectForCaret(TextPosition(offset: text.length));
            expect(caretRect.height, greaterThan(0));
            if (previousCaretX >= 0) {
              expect(caretRect.left, greaterThan(previousCaretX),
                  reason: 'Level $level: Caret must advance for "$text"');
            }
            previousCaretX = caretRect.left;
          }
        }
      });
    });
  });
}
