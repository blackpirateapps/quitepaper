import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/document_position.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

Widget buildTestApp({
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

void main() {
  group('WYSIWYG Frontmatter Preservation Tests', () {
    const journalFm = '---\njournal: true\ndate: 2026-09-06\n---\n';

    test('SemanticMarkdownParser with stripFrontmatter does not map empty body block to frontmatter range', () {
      final doc = SemanticMarkdownParser.parse(journalFm, stripFrontmatter: true);

      expect(doc.hasFrontmatter, isTrue);
      expect(doc.frontmatterRange, isNotNull);
      expect(doc.frontmatterRange!.start, equals(0));
      expect(doc.frontmatterRange!.end, equals(journalFm.length));

      expect(doc.blocks.length, equals(1));
      final firstBlock = doc.blocks.first as ParagraphBlock;
      expect(firstBlock.plainText, isEmpty);

      // CRITICAL: Block range must NOT be 0..39 (which was the bug that wiped frontmatter)
      // It must begin at or after the frontmatter end
      expect(firstBlock.sourceRange.start, equals(journalFm.length));
      expect(firstBlock.sourceRange.end, equals(journalFm.length));
      expect(firstBlock.contentRange?.start, equals(journalFm.length));
      expect(firstBlock.contentRange?.end, equals(journalFm.length));
    });

    test('Typing a single character below frontmatter preserves frontmatter completely', () {
      final controller = SemanticEditorController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
      );

      expect(controller.document.hasFrontmatter, isTrue);
      expect(controller.document.blocks.first.plainText, isEmpty);

      // Simulate typing 'H' in the empty body block
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        'H',
        const TextSelection.collapsed(offset: 1),
      );

      // Frontmatter must remain 100% intact
      expect(controller.markdown.startsWith(journalFm), isTrue);
      expect(controller.markdown, equals('${journalFm}H'));
      expect(controller.document.hasFrontmatter, isTrue);
      expect(controller.document.blocks.first.plainText, equals('H'));
    });

    test('Typing multiple characters and backspacing to empty preserves frontmatter', () {
      final controller = SemanticEditorController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
      );

      // Type words
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        'Today was productive',
        const TextSelection.collapsed(offset: 20),
      );

      expect(controller.markdown, equals('${journalFm}Today was productive'));
      expect(controller.document.blocks.first.plainText, equals('Today was productive'));

      // Backspace down to empty string
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        '',
        const TextSelection.collapsed(offset: 0),
      );

      // Frontmatter must still be intact!
      expect(controller.markdown.startsWith('---\njournal: true'), isTrue);
      expect(controller.document.hasFrontmatter, isTrue);
      expect(controller.document.blocks.first.plainText, isEmpty);

      // Type again after emptying
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        'Rewriting note',
        const TextSelection.collapsed(offset: 14),
      );

      expect(controller.markdown, equals('${journalFm}Rewriting note'));
      expect(controller.document.blocks.first.plainText, equals('Rewriting note'));
    });

    test('Multiline and heading edits in WYSIWYG preserve frontmatter', () {
      final controller = SemanticEditorController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
      );

      // Type heading Markdown prefix directly in WYSIWYG
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        '# Journal Heading',
        const TextSelection.collapsed(offset: 17),
      );

      expect(controller.markdown, equals('$journalFm# Journal Heading'));
      expect(controller.document.hasFrontmatter, isTrue);
      expect(controller.document.blocks.first, isA<HeadingBlock>());
      expect(controller.document.blocks.first.plainText, equals('Journal Heading'));

      // Pressing enter / inserting newline
      controller.handleVisualBlockTextChange(
        controller.document.blocks.first.id,
        'Journal Heading\nNew paragraph below',
        const TextSelection.collapsed(offset: 35),
      );

      expect(controller.markdown.startsWith(journalFm), isTrue);
      expect(controller.document.hasFrontmatter, isTrue);
    });

    test('Inline formatting actions preserve frontmatter in WYSIWYG mode', () {
      final controller = SemanticEditorController(
        initialMarkdown: '${journalFm}Some journal notes',
        stripFrontmatter: true,
      );

      // Select 'journal'
      final blockId = controller.document.blocks.first.id;
      controller.selection = DocumentSelection(
        base: DocumentPosition(blockId: blockId, offset: 5),
        extent: DocumentPosition(blockId: blockId, offset: 12),
      );

      // Toggle bold
      controller.toggleBold();

      expect(controller.markdown, equals('$journalFm' 'Some **journal** notes'));
      expect(controller.document.hasFrontmatter, isTrue);
      expect(controller.document.blocks.first.plainText, equals('Some journal notes'));

      // Toggle italic
      controller.toggleItalic();
      expect(controller.markdown, equals('$journalFm' 'Some ***journal*** notes'));
      expect(controller.document.hasFrontmatter, isTrue);
    });

    testWidgets('VisualDocumentEditor widget test: typing in empty body below frontmatter preserves YAML', (tester) async {
      String? changedMarkdown;
      final controller = SemanticEditorController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
        onMarkdownChanged: (md) => changedMarkdown = md,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestApp(
        controller: controller,
        focusNode: focusNode,
        onChanged: (md) => changedMarkdown = md,
      ));
      await tester.pumpAndSettle();

      // Ensure frontmatter delimiters are NOT rendered as editable visual blocks
      expect(find.textContaining('journal: true'), findsNothing);

      // There should be one TextField for the empty body paragraph
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // User types into the TextField
      await tester.enterText(textFieldFinder, 'Sunday evening thoughts');
      await tester.pumpAndSettle();

      // Verify controller markdown retains the frontmatter
      expect(controller.markdown.startsWith(journalFm), isTrue);
      expect(controller.markdown, equals('${journalFm}Sunday evening thoughts'));
      expect(changedMarkdown, equals('${journalFm}Sunday evening thoughts'));
      expect(controller.document.hasFrontmatter, isTrue);
    });
  });
}
