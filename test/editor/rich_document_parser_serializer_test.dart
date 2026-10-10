import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';

void main() {
  const parser = RichDocumentParser();
  const serializer = RichDocumentSerializer();

  group('RichDocumentParser & Serializer Round-Trip Fidelity', () {
    test('Empty document round-trips cleanly', () {
      final doc = parser.parse('');
      expect(doc.isEmpty, isTrue);
      expect(serializer.serialize(doc), '');
    });

    test('Headings H1 to H6 parse and serialize accurately', () {
      const md = '# Heading 1\n## Heading 2\n### Heading 3\n#### Heading 4\n##### Heading 5\n###### Heading 6';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 6);
      for (var i = 1; i <= 6; i++) {
        final block = doc.blocks[i - 1] as HeadingBlock;
        expect(block.level, i);
        expect(block.plainText, 'Heading $i');
      }
      expect(serializer.serialize(doc), md);
    });

    test('Paragraphs and inline formatting round-trip cleanly', () {
      const md = 'This is **bold** and *italic* and ***both*** and ~~strike~~ and ==highlight== and `inline code`.';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final p = doc.blocks.first as ParagraphBlock;
      expect(p.plainText, 'This is bold and italic and both and strike and highlight and inline code.');
      expect(serializer.serialize(doc), md);
    });

    test('External links, note links, and tags parse and serialize', () {
      const md = 'Visit [Quiet Paper](https://quitepaper.app) or open [[Meeting Notes]] with #work.';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final p = doc.blocks.first as ParagraphBlock;
      expect(p.plainText, 'Visit Quiet Paper or open Meeting Notes with #work.');
      expect(serializer.serialize(doc), md);
    });

    test('Checklists (unchecked and checked) parse and serialize', () {
      const md = '- [ ] Buy tea\n- [x] Write code';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 2);
      final item1 = doc.blocks[0] as ChecklistItemBlock;
      final item2 = doc.blocks[1] as ChecklistItemBlock;
      expect(item1.isChecked, isFalse);
      expect(item1.plainText, 'Buy tea');
      expect(item2.isChecked, isTrue);
      expect(item2.plainText, 'Write code');
      expect(serializer.serialize(doc), md);
    });

    test('Bulleted and ordered lists parse and serialize', () {
      const md = '- First bullet\n  - Nested bullet\n1. First ordered\n2. Second ordered';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 4);
      expect((doc.blocks[0] as BulletedListItemBlock).indent, 0);
      expect((doc.blocks[1] as BulletedListItemBlock).indent, 1);
      expect((doc.blocks[2] as OrderedListItemBlock).order, 1);
      expect((doc.blocks[3] as OrderedListItemBlock).order, 2);
      expect(serializer.serialize(doc), md);
    });

    test('Blockquotes parse and serialize', () {
      const md = '> A calm editorial writing surface.';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final q = doc.blocks.first as QuoteBlock;
      expect(q.plainText, 'A calm editorial writing surface.');
      expect(serializer.serialize(doc), md);
    });

    test('Code blocks parse and serialize verbatim', () {
      const md = '```dart\nvoid main() {\n  print("Hello");\n}\n```';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final code = doc.blocks.first as CodeBlock;
      expect(code.language, 'dart');
      expect(code.code, 'void main() {\n  print("Hello");\n}');
      expect(serializer.serialize(doc), md);
    });

    test('Horizontal rules parse and serialize', () {
      const md = 'Paragraph above\n---\nParagraph below';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 3);
      expect(doc.blocks[1] is HorizontalRuleBlock, isTrue);
      expect(serializer.serialize(doc), md);
    });

    test('Images parse and serialize', () {
      const md = '![Quiet Paper Cover](https://example.com/cover.png)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final img = doc.blocks.first as ImageBlock;
      expect(img.alt, 'Quiet Paper Cover');
      expect(img.url, 'https://example.com/cover.png');
      expect(serializer.serialize(doc), md);
    });

    test('Standalone document link promotes to a document AttachmentBlock', () {
      const md = '[Report](qp://document/11111111-1111-4111-8111-111111111111)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final att = doc.blocks.first as AttachmentBlock;
      expect(att.kind, AttachmentBlockKind.document);
      expect(att.name, 'Report');
      expect(att.uri, 'qp://document/11111111-1111-4111-8111-111111111111');
      // Serializes back to exact link form (no leading `!`).
      expect(serializer.serialize(doc), md);
    });

    test('Standalone asset link promotes to a file AttachmentBlock', () {
      const md = '[notes.zip](qp://asset/22222222-2222-4222-8222-222222222222)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final att = doc.blocks.first as AttachmentBlock;
      expect(att.kind, AttachmentBlockKind.file);
      expect(att.name, 'notes.zip');
      expect(att.uri, 'qp://asset/22222222-2222-4222-8222-222222222222');
      expect(serializer.serialize(doc), md);
    });

    test('Image-form asset link stays an ImageBlock, not an AttachmentBlock', () {
      const md = '![pic](qp://asset/33333333-3333-4333-8333-333333333333)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first, isA<ImageBlock>());
      final img = doc.blocks.first as ImageBlock;
      expect(img.url, 'qp://asset/33333333-3333-4333-8333-333333333333');
      expect(serializer.serialize(doc), md);
    });

    test('Inline qp:// link inside a paragraph stays an inline link', () {
      const md = 'See [Report](qp://document/11111111-1111-4111-8111-111111111111) later.';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first, isA<ParagraphBlock>());
      expect(serializer.serialize(doc), md);
    });

    test('Non-qp standalone link stays an inline link paragraph', () {
      const md = '[Quiet Paper](https://quitepaper.app)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first, isA<ParagraphBlock>());
      expect(serializer.serialize(doc), md);
    });

    test('Mixed document/file/image references round-trip byte-identically', () {
      const md =
          '[Report](qp://document/11111111-1111-4111-8111-111111111111)\n\n'
          'text\n\n'
          '[notes.zip](qp://asset/22222222-2222-4222-8222-222222222222)\n\n'
          '![pic](qp://asset/33333333-3333-4333-8333-333333333333)';
      final doc = parser.parse(md);
      expect(doc.blocks.whereType<AttachmentBlock>().length, 2);
      expect(doc.blocks.whereType<ImageBlock>().length, 1);
      expect(serializer.serialize(doc), md);
    });

    test('AttachmentBlock survives JSON round-trip for both kinds', () {
      const docAtt = AttachmentBlock(
        id: 'a1',
        uri: 'qp://document/11111111-1111-4111-8111-111111111111',
        name: 'Report',
        kind: AttachmentBlockKind.document,
      );
      const fileAtt = AttachmentBlock(
        id: 'a2',
        uri: 'qp://asset/22222222-2222-4222-8222-222222222222',
        name: 'notes.zip',
        kind: AttachmentBlockKind.file,
      );
      expect(RichBlock.fromJson(docAtt.toJson()), docAtt);
      expect(RichBlock.fromJson(fileAtt.toJson()), fileAtt);
    });

    test('Markdown Tables parse and serialize', () {
      const md = '| Column A | Column B |\n| --- | --- |\n| Cell 1 | Cell 2 |';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      final tableBlock = doc.blocks.first as TableBlock;
      expect(tableBlock.table.columnCount, 2);
      expect(tableBlock.table.rowCount, 2);
      expect(serializer.serialize(doc), md);
    });
  });
}
