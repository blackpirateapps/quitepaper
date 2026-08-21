import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_snapshot_generator.dart';

void main() {
  group('WebSnapshotGenerator', () {
    const generator = WebSnapshotGenerator();

    test('generates self-contained HTML snapshot with responsive viewport & Quiet Paper styling', () {
      const htmlFragment = '''
<div>
  <h2>Snapshot Test</h2>
  <p>Article body for testing snapshot bundling.</p>
  <img src="https://example.com/photo.jpg" alt="Photo" />
</div>
''';

      final element = html_parser.parseFragment(htmlFragment).children.first;
      final metadata = ExtractedArticleMetadata(
        sourceUrl: 'https://example.com/article',
        title: 'Snapshot Test Article',
        author: 'John Smith',
        publishedDate: DateTime(2026, 8, 22),
        domain: 'example.com',
      );

      final snapshotHtml = generator.generateHtmlSnapshot(
        cleanedElement: element,
        metadata: metadata,
        localImageSources: {
          'https://example.com/photo.jpg': 'qp://asset/photo-uuid',
        },
      );

      expect(snapshotHtml, contains('<!DOCTYPE html>'));
      expect(snapshotHtml, contains('<meta name="viewport"'));
      expect(snapshotHtml, contains('Snapshot Test Article'));
      expect(snapshotHtml, contains('By John Smith'));
      expect(snapshotHtml, contains('example.com'));
      expect(snapshotHtml, contains('--qp-bg: #F7F6F2;'));
      expect(snapshotHtml, contains('--qp-bg: #1D1C1A;'));
      expect(snapshotHtml, contains('qp://asset/photo-uuid'));
    });
  });
}
