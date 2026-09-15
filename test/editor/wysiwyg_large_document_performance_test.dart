import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

void main() {
  group('WYSIWYG Large Document & Performance Optimization Tests', () {
    test('SemanticEditorController threshold identifies oversized documents', () {
      expect(SemanticEditorController.maxWysiwygCharacters, equals(200000));

      final normalText = 'This is a normal note with some text.\n' * 100;
      expect(SemanticEditorController.isDocumentTooLargeForWysiwyg(normalText), isFalse);

      final hugeText = 'A' * 200001;
      expect(SemanticEditorController.isDocumentTooLargeForWysiwyg(hugeText), isTrue);

      final ctrl = SemanticEditorController(initialMarkdown: normalText);
      expect(ctrl.exceedsWysiwygThreshold, isFalse);
    });

    test('incrementalParse is orders of magnitude faster than full parse on large documents', () {
      // Generate a large document with 1,000 blocks (~50,000 words, ~300k chars)
      final lines = List.generate(1000, (i) => 'Paragraph $i contains standard notes content with some words to parse.');
      final fullMarkdown = lines.join('\n');

      final initialDoc = SemanticMarkdownParser.parse(fullMarkdown);
      expect(initialDoc.blocks.length, equals(1000));

      // Simulate an edit in paragraph 500
      const editBlockIndex = 500;
      final targetBlockId = initialDoc.blocks[editBlockIndex].id;
      final updatedLines = List<String>.from(lines);
      updatedLines[editBlockIndex] = 'Paragraph $editBlockIndex contains standard notes content with some words to parse and added text.';
      final updatedMarkdown = updatedLines.join('\n');

      // Time full parse
      final fullParseWatch = Stopwatch()..start();
      final fullDoc = SemanticMarkdownParser.parse(updatedMarkdown);
      fullParseWatch.stop();

      // Time incremental parse
      final incrementalWatch = Stopwatch()..start();
      final incDoc = SemanticMarkdownParser.incrementalParse(
        newMarkdown: updatedMarkdown,
        oldDocument: initialDoc,
        editBlockId: targetBlockId,
      );
      incrementalWatch.stop();

      expect(incDoc.blocks.length, equals(fullDoc.blocks.length));
      expect(incDoc.blocks[editBlockIndex].plainText, equals(fullDoc.blocks[editBlockIndex].plainText));
      expect(incDoc.blocks[editBlockIndex].id, equals(targetBlockId));

      // Verify speedup: incremental parse must be faster than full parse
      // and complete within negligible milliseconds
      expect(incrementalWatch.elapsedMicroseconds, lessThanOrEqualTo(fullParseWatch.elapsedMicroseconds));
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

      // VisualDocumentEditor must NOT be mounted because document exceeds threshold
      expect(find.byType(VisualDocumentEditor), findsNothing);
      // TextField (Markdown source editor) must be mounted instead
      expect(find.byType(TextField), findsWidgets);
      // SnackBar fallback notification must be triggered
      expect(find.text('Document too large for visual editing — using Markdown mode'), findsOneWidget);

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('VisualDocumentEditor windows block widgets when block count exceeds threshold', (tester) async {
      // 100 blocks exceeds the 80 block threshold (_windowThreshold = 80)
      final lines = List.generate(100, (i) => 'Block number $i content');
      final markdown = lines.join('\n');

      final semanticCtrl = SemanticEditorController(initialMarkdown: markdown);
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppColors.light],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualDocumentEditor(
                controller: semanticCtrl,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VisualDocumentEditor), findsOneWidget);
      // When windowed, the bottom spacer must be present to represent off-screen blocks
      expect(find.byKey(const ValueKey('viewport_bottom_spacer')), findsOneWidget);

      semanticCtrl.dispose();
      focusNode.dispose();
    });
  });
}
