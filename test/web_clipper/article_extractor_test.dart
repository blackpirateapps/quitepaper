import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/web_clipper/article_extractor.dart';

void main() {
  group('ArticleExtractor', () {
    const extractor = ArticleExtractor();

    test('extracts OpenGraph metadata and article content', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Old Title — SomeSite</title>
  <meta property="og:title" content="Calm Technology in Modern Era" />
  <meta property="og:description" content="Why distraction-free software is the future." />
  <meta property="og:image" content="https://example.com/images/hero.jpg" />
  <meta property="og:site_name" content="Calm Times" />
  <meta property="article:author" content="Jane Doe" />
  <meta property="article:published_time" content="2026-08-22T10:00:00Z" />
</head>
<body>
  <nav>
    <a href="/home">Home</a>
    <a href="/about">About</a>
  </nav>
  <article>
    <h1>Calm Technology in Modern Era</h1>
    <p>In a world of constant noise, quiet software is essential.</p>
    <figure>
      <img src="/images/diagram.png" alt="Architecture Diagram" />
      <figcaption>Figure 1: Distraction-free design.</figcaption>
    </figure>
    <p>Local-first software persists data securely on device.</p>
  </article>
  <div class="advertisement">
    <p>Buy our widgets!</p>
  </div>
  <footer>
    <p>&copy; 2026 Calm Times</p>
  </footer>
</body>
</html>
''';

      final result = extractor.extract(
        htmlContent: sampleHtml,
        sourceUrl: 'https://example.com/posts/calm-tech',
      );

      expect(result.metadata.title, 'Calm Technology in Modern Era');
      expect(result.metadata.author, 'Jane Doe');
      expect(result.metadata.description, 'Why distraction-free software is the future.');
      expect(result.metadata.leadImageUrl, 'https://example.com/images/hero.jpg');
      expect(result.metadata.domain, 'example.com');
      expect(result.metadata.publishedDate, isNotNull);

      // Verify noise removal
      expect(result.cleanedElement.querySelector('nav'), isNull);
      expect(result.cleanedElement.querySelector('footer'), isNull);
      expect(result.cleanedElement.querySelector('.advertisement'), isNull);

      // Verify image discovery
      expect(result.images.length, 2);
      expect(result.images.first.isLeadImage, isTrue);
      expect(result.images.first.resolvedUrl, 'https://example.com/images/hero.jpg');

      final bodyImg = result.images.last;
      expect(bodyImg.isLeadImage, isFalse);
      expect(bodyImg.resolvedUrl, 'https://example.com/images/diagram.png');
      expect(bodyImg.caption, 'Figure 1: Distraction-free design.');
    });

    test('handles fallback meta tags and title cleanup', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Essential Principles of Typography | Design Daily</title>
  <meta name="author" content="Alex Smith" />
  <meta name="description" content="A guide to typography." />
</head>
<body>
  <div class="post-content">
    <p>Good typography is invisible. It guides the reader effortlessly through the text.</p>
    <p>Hierarchy, line height, and contrast are the foundational pillars.</p>
  </div>
</body>
</html>
''';

      final result = extractor.extract(
        htmlContent: sampleHtml,
        sourceUrl: 'https://designdaily.org/typography',
      );

      expect(result.metadata.title, 'Essential Principles of Typography');
      expect(result.metadata.author, 'Alex Smith');
      expect(result.metadata.domain, 'designdaily.org');
      expect(result.cleanedElement.text, contains('Good typography is invisible'));
    });

    test('extracts lazy loaded images with data-src', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<body>
  <article>
    <p>Check out this photo:</p>
    <img src="data:image/svg+xml;base64,PHN2Z..." data-src="https://cdn.example.com/photo.webp" alt="Landscape" />
  </article>
</body>
</html>
''';

      final result = extractor.extract(
        htmlContent: sampleHtml,
        sourceUrl: 'https://example.com/gallery',
      );

      expect(result.images.length, 1);
      expect(result.images.first.resolvedUrl, 'https://cdn.example.com/photo.webp');
      expect(result.images.first.altText, 'Landscape');
    });
  });
}
