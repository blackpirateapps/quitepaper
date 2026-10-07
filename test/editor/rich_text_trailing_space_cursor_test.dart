import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';

void main() {
  group('Rich Text Editor — Trailing Space Cursor Advance Before Newlines', () {
    late RichDocumentController controller;

    setUp(() {
      controller = RichDocumentController();
    });

    testWidgets('Preserves trailing spaces as non-breaking spaces on lines preceding newlines in 5-line document', (tester) async {
      // 5-line document
      controller.setMarkdown('Line 1\nLine 2\nLine 3\nLine 4\nLine 5');
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
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final richTextCtrl = textField.controller!;

      // User moves cursor to the end of Line 3 and types two spaces
      final currentText = richTextCtrl.text;
      final line3Index = currentText.indexOf('Line 3');
      final line3End = line3Index + 'Line 3'.length;

      // Simulate typing two spaces at the end of Line 3
      richTextCtrl.value = TextEditingValue(
        text: currentText.replaceRange(line3End, line3End, '  '),
        selection: TextSelection.collapsed(offset: line3End + 2),
      );
      await tester.pumpAndSettle();

      // Underlying text model MUST retain standard ASCII spaces (' ')
      expect(richTextCtrl.text.contains('Line 3  \n'), isTrue);
      expect(controller.toMarkdown().contains('Line 3  \n'), isTrue);

      // Presentation TextSpan MUST convert trailing spaces before \n to \u00A0
      final span = richTextCtrl.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );

      final children = span.children!;
      // Find the span for Line 3
      final line3Span = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Line 3'));
      expect(line3Span.text, 'Line 3\u00A0\u00A0');

      // The subsequent delimiter span must be \n
      final line3SpanIndex = children.indexOf(line3Span);
      expect(line3SpanIndex + 1 < children.length, isTrue);
      final nextSpan = children[line3SpanIndex + 1] as TextSpan;
      expect(nextSpan.text, '\n');

      focusNode.dispose();
    });

    testWidgets('Monotonic caret advancement: TextPainter with preserved non-breaking spaces advances caret on every space', (tester) async {
      const lineTextWithPreservedSpaces = 'Line 3\u00A0\u00A0\nLine 4';

      final preservedPainter = TextPainter(
        text: const TextSpan(
          text: lineTextWithPreservedSpaces,
          style: TextStyle(fontSize: 16.0, fontFamily: 'Roboto'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // For preserved spaces with \u00A0, caret offsets at indices 6, 7, 8 advance monotonically
      final offsetAtCharPreserved = preservedPainter.getOffsetForCaret(const TextPosition(offset: 6), Rect.zero).dx;
      final offsetAtSpace1Preserved = preservedPainter.getOffsetForCaret(const TextPosition(offset: 7), Rect.zero).dx;
      final offsetAtSpace2Preserved = preservedPainter.getOffsetForCaret(const TextPosition(offset: 8), Rect.zero).dx;

      expect(offsetAtSpace1Preserved, greaterThan(offsetAtCharPreserved));
      expect(offsetAtSpace2Preserved, greaterThan(offsetAtSpace1Preserved));
    });

    testWidgets('Preserves trailing spaces across heading, checklist, list, and quote blocks before newlines', (tester) async {
      controller.setMarkdown('# Heading  \n- [ ] Task  \n* Bullet  \n> Quote  \nLast Line');
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
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final richTextCtrl = textField.controller!;
      final span = richTextCtrl.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );

      final children = span.children!;
      // 1. Heading block
      final headingSpan = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Heading'));
      expect(headingSpan.text, 'Heading\u00A0\u00A0');

      // 2. Checklist block
      final taskSpan = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Task'));
      expect(taskSpan.text, 'Task\u00A0\u00A0');

      // 3. Bullet block
      final bulletSpan = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Bullet'));
      expect(bulletSpan.text, 'Bullet\u00A0\u00A0');

      // 4. Quote block
      final quoteSpan = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Quote'));
      expect(quoteSpan.text, 'Quote\u00A0\u00A0');

      // 5. Last Line (not followed by \n) retains standard spaces
      final lastLineSpan = children.whereType<TextSpan>().firstWhere((s) => s.text != null && s.text!.contains('Last Line'));
      expect(lastLineSpan.text, 'Last Line');

      focusNode.dispose();
    });

    testWidgets('Preserves trailing spaces on blank lines containing only spaces before a newline', (tester) async {
      controller.setMarkdown('Line 1\n   \nLine 3');
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
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final richTextCtrl = textField.controller!;
      final span = richTextCtrl.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );

      final children = span.children!;
      // The blank line between Line 1 and Line 3 should have '\u00A0\u00A0\u00A0'
      final blankLineSpan = children.whereType<TextSpan>().firstWhere((s) => s.text == '\u00A0\u00A0\u00A0');
      expect(blankLineSpan, isNotNull);

      focusNode.dispose();
    });
  });
}
