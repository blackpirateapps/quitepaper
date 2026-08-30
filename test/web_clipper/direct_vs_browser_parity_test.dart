import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';

void main() {
  group('Direct vs Browser Acquisition Parity', () {
    const fixtureHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Architectural Invariants in Local-First Applications — Engineering Blog</title>
  <meta name="author" content="Jordan Key">
  <meta name="description" content="A comprehensive analysis of offline resilience, zero-knowledge encryption, and sync.">
  <meta property="og:image" content="https://example.com/images/hero_architecture.jpg">
  <meta property="article:published_time" content="2026-08-20T10:00:00Z">
</head>
<body>
  <nav class="navbar"><a href="/">Home</a><a href="/about">About</a></nav>
  <article>
    <h1>Architectural Invariants in Local-First Applications</h1>
    <p>Local data is the primary source of truth, and the remote cloud is merely a synchronization conduit.</p>
    
    <h2>Cryptographic Envelopes</h2>
    <p>All note payloads are encrypted client-side using <strong>XChaCha20-Poly1305</strong> with password keys derived via <em>Argon2id</em>.</p>
    
    <blockquote>
      Security must be guaranteed mathematically, not through server trust.
    </blockquote>
    
    <h3>Key Benefits</h3>
    <ul>
      <li>Zero plaintext cloud leakage</li>
      <li>Instant offline read and write</li>
      <li>Deterministic local merges</li>
    </ul>

    <h3>Data Pipeline</h3>
    <ol>
      <li>Content capture</li>
      <li>DOM sanitization</li>
      <li>Encrypted storage</li>
    </ol>
    
    <img src="/images/diagram_flow.png" alt="Data Pipeline Diagram">
    
    <pre><code class="language-dart">
void sync() {
  final changes = queue.poll();
}
    </code></pre>
    
    <table>
      <thead>
        <tr><th>Layer</th><th>Protocol</th></tr>
      </thead>
      <tbody>
        <tr><td>Storage</td><td>SQLite (Drift)</td></tr>
        <tr><td>Crypto</td><td>Argon2id + XChaCha20</td></tr>
      </tbody>
    </table>
  </article>
  <footer class="footer">Copyright 2026 Engineering Blog</footer>
</body>
</html>
''';

    test('Direct HTTP acquisition and In-App Browser payload produce identical Markdown, metadata, and images', () async {
      // 1. Setup Direct Acquisition via MockClient
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '85000'});
        }
        return http.Response(
          fixtureHtml,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final directScanner = WebClipperScanner(httpClient: mockClient);
      final directResult = await directScanner.scanUrl('https://example.com/local-first-arch');

      // 2. Setup Browser Acquisition Payload using the exact same HTML fixture
      final browserPayload = WebCapturePayload(
        requestedUrl: 'https://example.com/local-first-arch',
        finalUrl: 'https://example.com/local-first-arch',
        html: fixtureHtml,
        pageTitle: 'Architectural Invariants in Local-First Applications',
        canonicalUrl: 'https://example.com/local-first-arch',
        author: 'Jordan Key',
        description: 'A comprehensive analysis of offline resilience, zero-knowledge encryption, and sync.',
        publishedAt: DateTime.parse('2026-08-20T10:00:00Z'),
        acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
      );

      final browserScanner = WebClipperScanner(httpClient: mockClient);
      final browserResult = await browserScanner.scanPayload(browserPayload);

      // 3. Verify Downstream Parity
      expect(browserResult.metadata.title, equals(directResult.metadata.title));
      expect(browserResult.metadata.author, equals(directResult.metadata.author));
      expect(browserResult.metadata.domain, equals(directResult.metadata.domain));
      expect(browserResult.metadata.description, equals(directResult.metadata.description));
      expect(browserResult.metadata.leadImageUrl, equals(directResult.metadata.leadImageUrl));

      // Markdown parity
      expect(browserResult.markdownBody, equals(directResult.markdownBody));
      expect(browserResult.markdownBody, contains('title: "Architectural Invariants in Local-First Applications"'));
      expect(browserResult.markdownBody, contains('author: "Jordan Key"'));
      expect(browserResult.markdownBody, contains('Local data is the primary source of truth'));
      expect(browserResult.markdownBody, contains('**XChaCha20-Poly1305**'));
      expect(browserResult.markdownBody, contains('*Argon2id*'));
      expect(browserResult.markdownBody, contains('> Security must be guaranteed mathematically'));
      expect(browserResult.markdownBody, contains('- Zero plaintext cloud leakage'));
      expect(browserResult.markdownBody, contains('1. Content capture'));
      expect(browserResult.markdownBody, contains('![Data Pipeline Diagram](https://example.com/images/diagram_flow.png)'));
      expect(browserResult.markdownBody, contains('```dart'));
      expect(browserResult.markdownBody, contains('| Layer | Protocol |'));

      // Image discovery parity
      expect(browserResult.images.length, equals(directResult.images.length));
      for (var i = 0; i < directResult.images.length; i++) {
        expect(browserResult.images[i].resolvedUrl, equals(directResult.images[i].resolvedUrl));
        expect(browserResult.images[i].altText, equals(directResult.images[i].altText));
      }

      // Snapshot size estimate parity
      expect(
        (browserResult.htmlSnapshotSizeEstimate - directResult.htmlSnapshotSizeEstimate).abs(),
        lessThan(50),
      );
    });

    test('resolves relative image URLs identically across direct and browser acquisition', () async {
      final mockClient = MockClient((request) async {
        return http.Response(fixtureHtml, 200, headers: {'content-type': 'text/html'});
      });

      final browserPayload = WebCapturePayload(
        requestedUrl: 'https://example.com/blog/article',
        finalUrl: 'https://example.com/blog/article',
        html: '''
<article>
  <h1>Relative Image Test</h1>
  <p>Article content.</p>
  <img src="../assets/photo.jpg" alt="Relative Asset" />
</article>
''',
        acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
      );

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanPayload(browserPayload);

      expect(result.images.length, 1);
      expect(result.images.first.resolvedUrl, 'https://example.com/assets/photo.jpg');
      expect(result.images.first.altText, 'Relative Asset');
    });
  });
}
