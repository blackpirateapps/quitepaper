import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_editor_surface.dart';

void main() {
  group('Rich Document Large Document & Performance Optimization Tests', () {
    test('RichDocumentController threshold identifies oversized documents', () {
      expect(RichDocumentController.maxWysiwygCharacters, equals(200000));

      final normalText = 'This is a normal note with some text.\n' * 100;
      expect(RichDocumentController.isDocumentTooLargeForWysiwyg(normalText), isFalse);

      final hugeText = 'A' * 200001;
      expect(RichDocumentController.isDocumentTooLargeForWysiwyg(hugeText), isTrue);

      final ctrl = RichDocumentController(initialMarkdown: normalText);
      expect(ctrl.exceedsWysiwygThreshold, isFalse);
    });

    test('RichDocumentParser efficiently parses large documents with 1,000 blocks', () {
      final lines = List.generate(1000, (i) => 'Paragraph $i contains standard notes content with some words to parse.');
      final fullMarkdown = lines.join('\n');

      final watch = Stopwatch()..start();
      final doc = const RichDocumentParser().parse(fullMarkdown);
      watch.stop();

      expect(doc.blocks.length, equals(1000));
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('MarkdownEditor auto-falls back to Markdown mode for notes exceeding WYSIWYG threshold', (tester) async {
      final hugeMarkdown = 'A' * 200005;
      final controller = MarkdownEditingController(text: hugeMarkdown);
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppColors.light],
          ),
          home: Scaffold(
            body: MarkdownEditor(
              controller: controller,
              focusNode: focusNode,
              editingStyle: EditorEditingStyle.wysiwyg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RichEditorSurface must NOT be mounted because document exceeds threshold
      expect(find.byType(RichEditorSurface), findsNothing);
      // TextField (Markdown source editor) must be mounted instead
      expect(find.byType(TextField), findsWidgets);
      // SnackBar fallback notification must be triggered
      expect(find.text('Document too large for visual editing — using Markdown mode'), findsOneWidget);

      controller.dispose();
      focusNode.dispose();
    });
  });
}
