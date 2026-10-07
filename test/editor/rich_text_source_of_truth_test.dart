import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/core/search/search_index_projection.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';
import 'package:quitepaper/features/editor/domain/text_attributes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('RichText Source of Truth & Polymorphic Storage Tests', () {
    late RichDocument sampleDoc;
    late String sampleDocJson;

    setUp(() {
      sampleDoc = RichDocument(
        blocks: [
          HeadingBlock(
            id: 'h1',
            level: 1,
            spans: const [RichInlineSpan(text: 'Architecture Overview')],
          ),
          ParagraphBlock(
            id: 'p1',
            spans: const [
              RichInlineSpan(text: 'This is a '),
              RichInlineSpan(
                text: 'visual note',
                attributes: TextAttributes(isBold: true),
              ),
              RichInlineSpan(text: ' with '),
              RichInlineSpan(
                text: 'inline code',
                attributes: TextAttributes(isCode: true),
              ),
              RichInlineSpan(text: '.'),
            ],
          ),
          ChecklistItemBlock(
            id: 'c1',
            isChecked: false,
            spans: const [RichInlineSpan(text: 'Review pull request')],
          ),
          CodeBlock(
            id: 'cb1',
            language: 'dart',
            code: 'void main() => print("Hello");',
          ),
        ],
      );
      sampleDocJson = jsonEncode(sampleDoc.toJson());
    });

    test('1. RichDocument.toJson includes schemaId and RichDocument.isJson detects it', () {
      final jsonMap = sampleDoc.toJson();
      expect(jsonMap['\$schema'], RichDocument.schemaId);
      expect(RichDocument.isJson(sampleDocJson), isTrue);

      const markdownText = '# Architecture Overview\n\nThis is a note.';
      expect(RichDocument.isJson(markdownText), isFalse);
    });

    test('2. Note model identifies rich text and extracts plainText and markdownContent', () {
      final note = Note(
        id: 'note-1',
        title: '',
        content: sampleDocJson,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.isRichText, isTrue);
      expect(note.hasCustomTitle, isFalse);
      expect(note.displayTitle, 'Architecture Overview');
      expect(note.plainText, contains('This is a visual note with inline code.'));
      expect(note.plainText, isNot(contains('"blocks"')));
      expect(note.plainText, isNot(contains('"spans"')));

      // On-demand markdown conversion
      final md = note.markdownContent;
      expect(md, contains('# Architecture Overview'));
      expect(md, contains('**visual note**'));
      expect(md, contains('`inline code`'));
      expect(md, contains('- [ ] Review pull request'));
      expect(md, contains('```dart\nvoid main() => print("Hello");\n```'));

      // Word count and char count based on plainText
      expect(note.wordCount, greaterThan(0));
      expect(note.wordCount, lessThan(30)); // Not inflated by JSON keys
    });

    test('3. SearchIndexProjection projects pure user plainText without JSON keywords', () {
      final bodyText = SearchIndexProjection.projectBody(sampleDocJson);
      expect(bodyText, contains('Architecture Overview'));
      expect(bodyText, contains('visual note'));
      expect(bodyText, contains('inline code'));
      expect(bodyText, isNot(contains('blocks')));
      expect(bodyText, isNot(contains('spans')));
      expect(bodyText, isNot(contains('schema')));
      expect(bodyText, isNot(contains('attributes')));
    });

    test('4. NoteMetadataExtractor derives clean preview snippet from RichDocument JSON', () {
      final snippet = NoteMetadataExtractor.derivePreviewSnippet(
        sampleDocJson,
        title: 'Architecture Overview',
      );
      expect(snippet, isNotEmpty);
      expect(snippet, contains('This is a visual note'));
      expect(snippet, isNot(contains('{"')));
      expect(snippet, isNot(contains('blocks')));
    });

    test('5. RichDocumentController initializes directly from JSON without regex reparsing', () {
      final controller = RichDocumentController(initialMarkdown: sampleDocJson);
      expect(controller.document.blocks.length, 4);
      expect(controller.document.blocks[0], isA<HeadingBlock>());
      expect((controller.document.blocks[0] as HeadingBlock).level, 1);
      expect(controller.document.blocks[1], isA<ParagraphBlock>());
      expect(controller.document.blocks[2], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[3], isA<CodeBlock>());

      expect(controller.toJsonString(), contains(RichDocument.schemaId));
      expect(controller.toPlainText(), contains('Review pull request'));
    });

    test('6. RichDocumentController.isDocumentTooLargeForWysiwyg inspects plainText length for JSON', () {
      expect(RichDocumentController.isDocumentTooLargeForWysiwyg(sampleDocJson), isFalse);

      final hugeDoc = RichDocument(
        blocks: List.generate(
          1000,
          (i) => ParagraphBlock.fromText('This is line $i of a very large document repeating content.'),
        ),
      );
      final hugeJson = jsonEncode(hugeDoc.toJson());
      expect(RichDocumentController.isDocumentTooLargeForWysiwyg(hugeJson), isTrue);
    });

    testWidgets('7. MarkdownEditor flushes JSON in Visual mode and converts to Markdown on mode switch', (tester) async {
      String? lastFlushed;
      final controller = MarkdownEditingController(text: sampleDocJson);
      final focusNode = FocusNode();

      Widget buildTest(EditorEditingStyle style) {
        return MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
          home: Scaffold(
            body: ProviderScope(
              child: MarkdownEditor(
                controller: controller,
                focusNode: focusNode,
                editingStyle: style,
                onChanged: (newVal) {
                  lastFlushed = newVal;
                },
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTest(EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();

      // Controller holds JSON format in Visual mode
      expect(RichDocument.isJson(controller.text), isTrue);

      // Now switch editing style to Markdown: triggers conversion on mode switch!
      await tester.pumpWidget(buildTest(EditorEditingStyle.markdown));
      await tester.pumpAndSettle();

      // Flushed content must now be clean Markdown
      expect(lastFlushed, isNotNull);
      expect(RichDocument.isJson(lastFlushed!), isFalse);
      expect(lastFlushed!, contains('# Architecture Overview'));
      expect(lastFlushed!, contains('**visual note**'));
      expect(lastFlushed!, contains('- [ ] Review pull request'));

      // Switch back to Visual mode: parses Markdown and flushes JSON AST
      await tester.pumpWidget(buildTest(EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();

      expect(RichDocument.isJson(lastFlushed!), isTrue);
    });

    testWidgets('8. QuietMarkdownPreview seamlessly converts and displays RichDocument JSON', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
          home: Scaffold(
            body: ProviderScope(
              child: QuietMarkdownPreview(
                markdownData: sampleDocJson,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Renders text from the JSON document without showing JSON brackets
      expect(find.textContaining('Architecture Overview'), findsOneWidget);
      expect(find.textContaining('visual note'), findsOneWidget);
      expect(find.textContaining('{"'), findsNothing);
      expect(find.textContaining('"blocks"'), findsNothing);
    });
  });
}
