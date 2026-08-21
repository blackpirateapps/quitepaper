import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';

void main() {
  group('WebClipperScanner', () {
    test('scans URL, fetches HTML, and estimates sizes', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '150000'});
        }

        const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Deep Dive into Mobile Architectures</title>
  <meta name="author" content="Alex Doe" />
</head>
<body>
  <article>
    <h1>Deep Dive into Mobile Architectures</h1>
    <p>Offline-first systems require predictable local storage and conflict-free delta sync.</p>
    <img src="https://example.com/arch.png" alt="Architecture" />
  </article>
</body>
</html>
''';
        return http.Response(html, 200, headers: {'content-type': 'text/html; charset=utf-8'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanUrl('https://example.com/mobile-arch');

      expect(result.metadata.title, 'Deep Dive into Mobile Architectures');
      expect(result.metadata.author, 'Alex Doe');
      expect(result.metadata.domain, 'example.com');
      expect(result.markdownSizeEstimate, greaterThan(50));
      expect(result.htmlSnapshotSizeEstimate, greaterThan(100));
      expect(result.images.length, 1);
      expect(result.images.first.estimatedSizeBytes, 150000);
      expect(result.effectiveTotalSize, greaterThan(150000));
    });
  });
}
