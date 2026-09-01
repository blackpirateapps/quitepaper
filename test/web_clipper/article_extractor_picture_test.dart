import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/web_clipper/article_extractor.dart';

void main() {
  group('ArticleExtractor with Modern Responsive Images', () {
    const extractor = ArticleExtractor();

    test('discovers AVIF image from <picture> and discards navigation icons', () {
      const complexHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Engineering the Future of Offline Software</title>
  <meta property="og:title" content="Engineering the Future of Offline Software" />
  <meta property="og:description" content="Local first and cryptographic architectures." />
  <meta property="og:image" content="https://example.com/assets/og-cover.avif" />
</head>
<body>
  <header>
    <nav>
      <img src="https://example.com/icons/logo.svg" width="24" height="24" alt="Site Logo" />
      <a href="/topics">Topics</a>
    </nav>
  </header>

  <article>
    <h1>Engineering the Future of Offline Software</h1>
    <p>Modern applications need local-first storage and end-to-end encryption.</p>

    <picture>
      <source type="image/avif" srcset="https://cdn.example.com/media/crypto-architecture-800.avif 800w, https://cdn.example.com/media/crypto-architecture-1600.avif 1600w">
      <source type="image/webp" srcset="https://cdn.example.com/media/crypto-architecture.webp">
      <img src="data:image/svg+xml;utf8,<svg/>" alt="Cryptographic Architecture">
    </picture>

    <p>Below is the system throughput benchmark chart.</p>

    <figure>
      <img src="https://cdn.example.com/charts/throughput.svg" alt="Throughput Benchmark Chart" />
      <figcaption>Figure 1: Throughput under heavy load.</figcaption>
    </figure>

    <div class="social-share">
      <img src="https://example.com/icons/twitter.png" width="16" height="16" alt="Share on Twitter" />
      <img src="https://example.com/icons/linkedin.png" width="16" height="16" alt="Share on LinkedIn" />
    </div>
  </article>

  <footer>
    <img src="https://example.com/tracker/1x1.gif" width="1" height="1" alt="telemetry" />
  </footer>
</body>
</html>
''';

      final result = extractor.extract(
        htmlContent: complexHtml,
        sourceUrl: 'https://example.com/posts/offline-software',
      );

      // Verify discovered images:
      // 1. Lead image: og-cover.avif
      // 2. Picture candidate: crypto-architecture-1600.avif
      // 3. Figure chart: throughput.svg
      // Noise images (logo.svg, twitter.png, linkedin.png, 1x1.gif) must ALL be excluded!
      final urls = result.images.map((img) => img.resolvedUrl).toList();

      expect(urls, contains('https://example.com/assets/og-cover.avif'));
      expect(urls, contains('https://cdn.example.com/media/crypto-architecture-1600.avif'));
      expect(urls, contains('https://cdn.example.com/charts/throughput.svg'));

      expect(urls, isNot(contains('https://example.com/icons/logo.svg')));
      expect(urls, isNot(contains('https://example.com/icons/twitter.png')));
      expect(urls, isNot(contains('https://example.com/icons/linkedin.png')));
      expect(urls, isNot(contains('https://example.com/tracker/1x1.gif')));

      // In the sanitized element, picture should have src updated to high-res AVIF
      final sanitizedImg = result.cleanedElement.querySelector('img');
      expect(sanitizedImg, isNotNull);
      expect(
        sanitizedImg!.attributes['src'],
        'https://cdn.example.com/media/crypto-architecture-1600.avif',
      );
    });
  });
}
