import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';

void main() {
  const parser = RichDocumentParser();
  const serializer = RichDocumentSerializer();

  // Fixed UTC timestamp so ISO-8601 round-trips are exact.
  final fetchedAt = DateTime.parse('2024-03-10T08:15:30.000Z');

  LinkPreviewBlock buildBlock({
    String id = 'preview-id',
    String url = 'https://example.com/article',
    String title = 'A Great Article',
    String? description,
    String? siteName,
    String? thumbnailAssetId,
  }) {
    return LinkPreviewBlock(
      id: id,
      url: url,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: fetchedAt,
    );
  }

  group('encodeLinkPreviewComment', () {
    test('emits all keys when every field is present', () {
      final block = buildBlock(
        description: 'A great article',
        siteName: 'Example',
        thumbnailAssetId: 'qp://asset/abc123',
      );
      final comment = encodeLinkPreviewComment(block);
      expect(
        comment,
        '<!-- qp-link-preview: {"desc":"A great article","site":"Example",'
        '"img":"qp://asset/abc123","ts":"2024-03-10T08:15:30.000Z"} -->',
      );
      expect(isLinkPreviewComment(comment), isTrue);
    });

    test('omits desc/site/img keys when their fields are null', () {
      final comment = encodeLinkPreviewComment(buildBlock());
      expect(comment, contains('"ts":"2024-03-10T08:15:30.000Z"'));
      expect(comment, isNot(contains('"desc"')));
      expect(comment, isNot(contains('"site"')));
      expect(comment, isNot(contains('"img"')));
    });

    test('omits desc/site/img keys when their fields are empty strings', () {
      final comment = encodeLinkPreviewComment(
        buildBlock(description: '', siteName: '', thumbnailAssetId: ''),
      );
      expect(comment, isNot(contains('"desc"')));
      expect(comment, isNot(contains('"site"')));
      expect(comment, isNot(contains('"img"')));
    });
  });

  group('decodeLinkPreview', () {
    test('reconstructs a block with all fields present', () {
      final block = buildBlock(
        description: 'A great article',
        siteName: 'Example',
        thumbnailAssetId: 'qp://asset/abc123',
      );
      final decoded = decodeLinkPreview(
        linkLine: '[A Great Article](https://example.com/article)',
        commentLine: encodeLinkPreviewComment(block),
        id: 'preview-id',
      );
      expect(decoded, isNotNull);
      expect(decoded, equals(block));
    });

    test('reconstructs with missing optional keys', () {
      final decoded = decodeLinkPreview(
        linkLine: '[Title Only](https://example.com)',
        commentLine:
            '<!-- qp-link-preview: {"ts":"2024-03-10T08:15:30.000Z"} -->',
        id: 'x',
      );
      expect(decoded, isNotNull);
      expect(decoded!.title, 'Title Only');
      expect(decoded.url, 'https://example.com');
      expect(decoded.description, isNull);
      expect(decoded.siteName, isNull);
      expect(decoded.thumbnailAssetId, isNull);
      expect(decoded.fetchedAt, fetchedAt);
    });

    test('reconstructs a partial subset of optional keys', () {
      final decoded = decodeLinkPreview(
        linkLine: '[Partial](https://example.com)',
        commentLine:
            '<!-- qp-link-preview: {"site":"Example","ts":"2024-03-10T08:15:30.000Z"} -->',
        id: 'x',
      );
      expect(decoded, isNotNull);
      expect(decoded!.siteName, 'Example');
      expect(decoded.description, isNull);
      expect(decoded.thumbnailAssetId, isNull);
    });

    test('returns null when the link line is not a markdown link', () {
      final decoded = decodeLinkPreview(
        linkLine: 'just some plain text',
        commentLine:
            '<!-- qp-link-preview: {"ts":"2024-03-10T08:15:30.000Z"} -->',
        id: 'x',
      );
      expect(decoded, isNull);
    });

    test('returns null when the comment line is not a sentinel', () {
      final decoded = decodeLinkPreview(
        linkLine: '[Title](https://example.com)',
        commentLine: 'not a sentinel comment',
        id: 'x',
      );
      expect(decoded, isNull);
    });

    test('falls back to now when ts is missing', () {
      final decoded = decodeLinkPreview(
        linkLine: '[Title](https://example.com)',
        commentLine: '<!-- qp-link-preview: {} -->',
        id: 'x',
      );
      expect(decoded, isNotNull);
      expect(decoded!.fetchedAt, isA<DateTime>());
    });
  });

  group('serialize -> parse -> serialize idempotency', () {
    void expectIdempotent(LinkPreviewBlock block) {
      final doc = RichDocument(blocks: [block]);
      final md = serializer.serialize(doc);
      final reparsed = parser.parse(md);
      // The reparsed document promotes the link + sentinel back to a block.
      expect(reparsed.blocks.length, 1);
      expect(reparsed.blocks.first, isA<LinkPreviewBlock>());
      expect(serializer.serialize(reparsed), md);
    }

    test('round-trips with all optional fields', () {
      expectIdempotent(buildBlock(
        description: 'desc here',
        siteName: 'Example Site',
        thumbnailAssetId: 'qp://asset/thumb-1',
      ));
    });

    test('round-trips without thumbnailAssetId/description/siteName', () {
      expectIdempotent(buildBlock());
    });

    test('round-trips with only a thumbnail', () {
      expectIdempotent(buildBlock(thumbnailAssetId: 'qp://asset/thumb-2'));
    });

    test('reparsed block preserves field values', () {
      final block = buildBlock(
        description: 'desc here',
        siteName: 'Example Site',
        thumbnailAssetId: 'qp://asset/thumb-1',
      );
      final md = serializer.serialize(RichDocument(blocks: [block]));
      final reparsed = parser.parse(md).blocks.first as LinkPreviewBlock;
      expect(reparsed.url, block.url);
      expect(reparsed.title, block.title);
      expect(reparsed.description, block.description);
      expect(reparsed.siteName, block.siteName);
      expect(reparsed.thumbnailAssetId, block.thumbnailAssetId);
      expect(reparsed.fetchedAt, block.fetchedAt);
    });
  });

  group('mixed documents and plain-link degradation', () {
    test('mixes a link preview with ordinary paragraphs and links', () {
      final preview = buildBlock(description: 'summary', siteName: 'Example');
      final md = serializer.serialize(RichDocument(blocks: [
        ParagraphBlock.fromText('Intro paragraph.', id: 'p1'),
        preview,
        ParagraphBlock(id: 'p2', spans: const []),
      ]));

      final reparsed = parser.parse(md);
      final previewBlocks =
          reparsed.blocks.whereType<LinkPreviewBlock>().toList();
      expect(previewBlocks.length, 1);
      expect(previewBlocks.first.title, preview.title);
      // Re-serialization is stable.
      expect(serializer.serialize(reparsed), md);
    });

    test('a lone https link without a sentinel stays a plain inline link', () {
      const md = '[Example](https://example.com)';
      final doc = parser.parse(md);
      expect(doc.blocks.length, 1);
      expect(doc.blocks.first, isA<ParagraphBlock>());
      expect(doc.blocks.first, isNot(isA<LinkPreviewBlock>()));
      expect(serializer.serialize(doc), md);
    });

    test('an orphan sentinel with no preceding link is dropped', () {
      const md = '<!-- qp-link-preview: {"ts":"2024-03-10T08:15:30.000Z"} -->';
      final doc = parser.parse(md);
      expect(doc.blocks.whereType<LinkPreviewBlock>(), isEmpty);
      // The sentinel must not surface as visible paragraph text.
      for (final block in doc.blocks) {
        expect(block.plainText.contains('qp-link-preview'), isFalse);
      }
    });
  });

  group('JSON serialization', () {
    test('RichBlock.fromJson(toJson()) equality for a full block', () {
      final block = buildBlock(
        description: 'A great article',
        siteName: 'Example',
        thumbnailAssetId: 'qp://asset/abc123',
      );
      expect(RichBlock.fromJson(block.toJson()), equals(block));
    });

    test('RichBlock.fromJson(toJson()) equality with null optionals', () {
      final block = buildBlock();
      final restored = RichBlock.fromJson(block.toJson());
      expect(restored, equals(block));
      expect((restored as LinkPreviewBlock).description, isNull);
      expect(restored.siteName, isNull);
      expect(restored.thumbnailAssetId, isNull);
    });
  });
}
