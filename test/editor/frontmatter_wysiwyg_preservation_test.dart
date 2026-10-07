import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';

void main() {
  group('Rich Document Frontmatter Preservation Tests', () {
    const journalFm = '---\njournal: true\ndate: 2026-09-06\n---\n';

    test('RichDocumentController with stripFrontmatter parses body and retains prefix', () {
      final ctrl = RichDocumentController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
      );

      expect(ctrl.hasFrontmatter, isTrue);
      expect(ctrl.document.blocks.length, equals(1));
      expect(ctrl.document.blocks.first, isA<ParagraphBlock>());
      expect(ctrl.document.blocks.first.plainText, isEmpty);
      expect(ctrl.toMarkdown().trim(), equals(journalFm.trim()));
    });

    test('Updating block spans below frontmatter preserves frontmatter completely', () {
      final ctrl = RichDocumentController(
        initialMarkdown: journalFm,
        stripFrontmatter: true,
      );

      expect(ctrl.hasFrontmatter, isTrue);

      // Update block spans
      ctrl.updateBlockSpans(0, [const RichInlineSpan(text: 'Today was productive')]);
      expect(ctrl.toMarkdown().startsWith(journalFm), isTrue);
      expect(ctrl.toMarkdown(), contains('Today was productive'));
      expect(ctrl.hasFrontmatter, isTrue);

      // Clear spans
      ctrl.updateBlockSpans(0, [const RichInlineSpan(text: '')]);
      expect(ctrl.toMarkdown().trim(), equals(journalFm.trim()));
      expect(ctrl.hasFrontmatter, isTrue);

      // Retype
      ctrl.updateBlockSpans(0, [const RichInlineSpan(text: 'Rewriting note')]);
      expect(ctrl.toMarkdown().startsWith(journalFm), isTrue);
      expect(ctrl.toMarkdown(), contains('Rewriting note'));
    });

    test('Inline formatting actions preserve frontmatter in WYSIWYG mode', () {
      final ctrl = RichDocumentController(
        initialMarkdown: '${journalFm}Some journal notes\n',
        stripFrontmatter: true,
      );

      final blockId = ctrl.document.blocks.first.id;
      ctrl.updateSelection(RichDocumentSelection(
        base: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 5),
        extent: RichDocumentPosition(blockIndex: 0, blockId: blockId, offset: 12),
      ));

      ctrl.toggleBold();
      expect(ctrl.toMarkdown(), contains('Some **journal** notes'));
      expect(ctrl.toMarkdown().startsWith(journalFm), isTrue);
    });
  });
}
