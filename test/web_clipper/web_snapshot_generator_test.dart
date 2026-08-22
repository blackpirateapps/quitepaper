import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_snapshot_generator.dart';

void main() {
  group('WebSnapshotGenerator', () {
    const metadata = ExtractedArticleMetadata(
      sourceUrl: 'https://example.com/blog/article-1',
      title: 'Authentic Snapshot Article',
      author: 'John Smith',
      publishedDate: null,
      domain: 'example.com',
    );

    test('preserves original HTML structure and inlines external CSS stylesheets with rewritten asset URLs', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/assets/theme.css') {
          const css = '''
body { background: #fafafa; font-family: "Helvetica Neue", sans-serif; }
.hero { background-image: url('../images/banner.jpg'); color: #111; }
''';
          return http.Response(css, 200, headers: {'content-type': 'text/css'});
        }
        return http.Response('Not Found', 404);
      });

      final generator = WebSnapshotGenerator(httpClient: mockClient);

      const rawHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Original Page Title</title>
  <link rel="stylesheet" href="/assets/theme.css" />
  <script src="/analytics.js"></script>
</head>
<body onclick="trackClick()">
  <header class="hero">
    <h1>Welcome to Authentic Design</h1>
  </header>
  <main>
    <p>Original paragraph with styling.</p>
    <img src="/media/photo.png" alt="Photo" />
    <img src="https://cdn.example.com/hero.jpg" alt="Hero" />
  </main>
  <script>console.log('secret tracker');</script>
</body>
</html>
''';

      final snapshotHtml = await generator.generateHtmlSnapshot(
        rawHtml: rawHtml,
        metadata: metadata,
        localImageSources: {
          'https://cdn.example.com/hero.jpg': 'qp://asset/hero-uuid-1',
        },
      );

      // Verify authentic DOM is preserved
      expect(snapshotHtml, contains('<!DOCTYPE html>'));
      expect(snapshotHtml, contains('<base href="https://example.com/blog/article-1">'));
      expect(snapshotHtml, contains('<meta name="viewport" content="width=device-width, initial-scale=1.0">'));
      expect(snapshotHtml, contains('Welcome to Authentic Design'));
      expect(snapshotHtml, contains('<header class="hero">'));

      // Verify CSS is inlined and relative image url() inside CSS is resolved to absolute
      expect(snapshotHtml, contains('<style data-source-href="https://example.com/assets/theme.css">'));
      expect(snapshotHtml, contains('url("https://example.com/images/banner.jpg")'));

      // Verify scripts and inline on* event handlers are completely stripped
      expect(snapshotHtml, isNot(contains('<script')));
      expect(snapshotHtml, isNot(contains('secret tracker')));
      expect(snapshotHtml, isNot(contains('analytics.js')));
      expect(snapshotHtml, isNot(contains('onclick')));

      // Verify image src rewriting and resolution
      expect(snapshotHtml, contains('src="qp://asset/hero-uuid-1"'));
      expect(snapshotHtml, contains('src="https://example.com/media/photo.png"'));
    });

    test('generates snapshot bytes cleanly even if rawHtml is empty (fallback to cleanedElement)', () async {
      final generator = WebSnapshotGenerator();

      final bytes = await generator.generateSnapshotBytes(
        rawHtml: '',
        metadata: metadata,
      );

      expect(bytes.isNotEmpty, isTrue);
      final decoded = String.fromCharCodes(bytes);
      expect(decoded, contains('<base href="https://example.com/blog/article-1">'));
      expect(decoded, contains('Authentic Snapshot Article'));
    });
  });
}
