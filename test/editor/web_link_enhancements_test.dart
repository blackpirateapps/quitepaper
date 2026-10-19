import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_mutations.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';

void main() {
  const parser = RichDocumentParser();
  const serializer = RichDocumentSerializer();

  RichDocumentPosition caretAt(RichDocumentController c, int offset) {
    return RichDocumentPosition(
      blockIndex: 0,
      blockId: c.document.blocks.first.id,
      offset: offset,
    );
  }

  group('Web link enhancements — RichDocumentMutations', () {
    test('collapsed applyLink carries the title as the display label (Feature 2)', () {
      final doc = parser.parse('Hello ');
      final sel = RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: doc.blocks.first.id, offset: 6),
      );

      final newDoc = RichDocumentMutations.applyLink(
        doc,
        sel,
        url: 'https://example.com',
        title: 'Example Site',
      );

      final linkSpan = newDoc.blocks.first.spans.firstWhere((s) => s.attributes.hasLink);
      expect(linkSpan.text, 'Example Site');
      expect(linkSpan.attributes.linkUrl, 'https://example.com');
      // The title is the display text, not a markdown tooltip.
      expect(serializer.serialize(newDoc), 'Hello [Example Site](https://example.com)');
    });

    test('replaceLinkDisplayText patches only an unchanged bare-URL run (Feature 1)', () {
      final doc = parser.parse('See [https://a.com](https://a.com) now');

      final patched = RichDocumentMutations.replaceLinkDisplayText(
        doc,
        url: 'https://a.com',
        newText: 'A Great Article',
      );
      expect(serializer.serialize(patched), 'See [A Great Article](https://a.com) now');
    });

    test('replaceLinkDisplayText is a no-op once the display text was edited when force is false', () {
      final doc = parser.parse('See [My Site](https://a.com) now');

      final patched = RichDocumentMutations.replaceLinkDisplayText(
        doc,
        url: 'https://a.com',
        newText: 'A Great Article',
        force: false,
      );
      // Display text no longer equals the URL, so the late title is ignored.
      expect(serializer.serialize(patched), 'See [My Site](https://a.com) now');
    });

    test('replaceLinkDisplayText with force: true updates display text even if previously edited', () {
      final doc = parser.parse('See [My Site](https://a.com) now');

      final patched = RichDocumentMutations.replaceLinkDisplayText(
        doc,
        url: 'https://a.com',
        newText: 'A Great Article',
        force: true,
      );
      expect(serializer.serialize(patched), 'See [A Great Article](https://a.com) now');
    });

    test('linkRunAt coalesces split formatting inside a link into one run', () {
      final doc = parser.parse('Go [**Goo**gle](https://google.com) home');
      final pos = RichDocumentPosition(
        blockIndex: 0,
        blockId: doc.blocks.first.id,
        offset: 5,
      );
      final run = RichDocumentMutations.linkRunAt(doc, pos);
      expect(run, isNotNull);
      expect(run!.url, 'https://google.com');
      expect(run.text, 'Google');
    });

    test('editLinkRun with empty url reverts to plain text keeping characters (Feature 5)', () {
      final doc = parser.parse('Go [Google](https://google.com) home');
      final pos = RichDocumentPosition(
        blockIndex: 0,
        blockId: doc.blocks.first.id,
        offset: 5,
      );
      final reverted = RichDocumentMutations.editLinkRun(doc, pos, url: '');
      expect(serializer.serialize(reverted), 'Go Google home');
    });
  });

  group('Web link enhancements — RichDocumentController', () {
    late RichDocumentController controller;

    setUp(() {
      controller = RichDocumentController();
    });

    test('linkAtCaret reports href and display text of the run under the caret', () {
      controller.setMarkdown('Go [Google](https://google.com) home');
      controller.updateSelection(RichDocumentSelection.collapsed(caretAt(controller, 5)));

      expect(controller.isLinkActive, isTrue);
      final link = controller.linkAtCaret;
      expect(link, isNotNull);
      expect(link!.url, 'https://google.com');
      expect(link.title, 'Google');
    });

    test('linkAtCaret is null outside any link', () {
      controller.setMarkdown('Go [Google](https://google.com) home');
      controller.updateSelection(RichDocumentSelection.collapsed(caretAt(controller, 1)));
      expect(controller.linkAtCaret, isNull);
    });

    test('editLinkAtCaret rewrites url + display in place (Feature 2)', () {
      controller.setMarkdown('Go [Google](https://google.com) home');
      controller.updateSelection(RichDocumentSelection.collapsed(caretAt(controller, 5)));

      controller.editLinkAtCaret(url: 'https://bing.com', title: 'Bing');
      expect(controller.toMarkdown(), 'Go [Bing](https://bing.com) home');
    });

    test('editLinkAtCaret with empty url removes the link but keeps text (Feature 5)', () {
      controller.setMarkdown('Go [Google](https://google.com) home');
      controller.updateSelection(RichDocumentSelection.collapsed(caretAt(controller, 5)));

      controller.editLinkAtCaret(url: '');
      expect(controller.toMarkdown(), 'Go Google home');
    });

    test('replaceLinkDisplayText upgrades a bare-URL link in place (Feature 1)', () {
      controller.setMarkdown('See [https://a.com](https://a.com) now');
      controller.replaceLinkDisplayText('https://a.com', 'A Great Article');
      expect(controller.toMarkdown(), 'See [A Great Article](https://a.com) now');
    });
  });
}
