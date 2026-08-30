import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';

void main() {
  group('WebClipperScanner', () {
    test('Tier 1: scans URL directly when HTTP 200 and substantial HTML is returned', () async {
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
    <p>Offline-first systems require predictable local storage and conflict-free delta sync with end-to-end cryptographic encryption across all active nodes.</p>
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

    test('Tier 2: automatically triggers Reader Fallback on HTTP 403 Forbidden (Gates Notes)', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '320000'});
        }

        // Direct request returns 403 Forbidden Access Denied from Akamai
        if (request.url.toString().contains('gatesnotes.com') && !request.url.toString().contains('r.jina.ai')) {
          return http.Response(
            '<html><head><title>Access Denied</title></head><body><h1>Access Denied</h1></body></html>',
            403,
            headers: {'server': 'AkamaiGHost', 'content-type': 'text/html'},
          );
        }

        // Reader proxy request
        if (request.url.toString().contains('r.jina.ai')) {
          final jsonPayload = json.encode({
            'code': 200,
            'status': 20000,
            'data': {
              'title': 'The choices we make about AI now are critical | Bill Gates',
              'description': 'AI will either be the greatest equalizer ever invented, or the worst source of injustice.',
              'url': 'https://www.gatesnotes.com/work/make-ai-work-for-everyone/reader/a-turbulent-ai-era-and-critical-choices-to-make',
              'content': '''## The turbulent AI era is here. The choices we make now are critical.

AI will either be the greatest equalizer ever invented, or the worst source of injustice. We need to start planning now so it makes the world a fairer place.

![Graphic concept of a human brain with digital line drawings](https://images.gatesnotes.com/ai_brain_hero.jpg)

A core principle underlying the Gates Foundation's work is closing the innovation gap between rich countries and everyone else.

![Health Care AI](https://images.gatesnotes.com/health_ai.jpg)''',
              'metadata': {
                'author': 'Bill Gates',
                'og:image': 'https://images.gatesnotes.com/share_image.jpg',
                'og:site_name': 'gatesnotes.com',
                'article:published_time': '2026-08-26T12:00:00Z',
              },
            },
          });
          return http.Response(jsonPayload, 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('Not Found', 404);
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanUrl(
        'https://www.gatesnotes.com/work/make-ai-work-for-everyone/reader/a-turbulent-ai-era-and-critical-choices-to-make?WT.mc_id=20260826_ai-overture-2026-med-med',
      );

      expect(result.metadata.title, 'The choices we make about AI now are critical');
      expect(result.metadata.author, 'Bill Gates');
      expect(result.metadata.domain, 'gatesnotes.com');
      expect(result.metadata.leadImageUrl, 'https://images.gatesnotes.com/share_image.jpg');
      expect(result.markdownBody, contains('## The turbulent AI era is here'));
      expect(result.markdownBody, contains('closing the innovation gap'));
      expect(result.images.length, greaterThanOrEqualTo(2));
      expect(result.images.any((img) => img.resolvedUrl.contains('share_image.jpg')), isTrue);
    });

    test('Tier 2: triggers Reader Fallback on HTTP 429 Too Many Requests', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '10000'});
        }

        if (!request.url.toString().contains('r.jina.ai')) {
          return http.Response('Too Many Requests', 429);
        }

        final jsonPayload = json.encode({
          'data': {
            'title': 'Rate Limited Article — Tech Blog',
            'content': 'This article was successfully recovered via the reader fallback pipeline after rate limiting.',
            'metadata': {'author': 'Dev Author'},
          },
        });
        return http.Response(jsonPayload, 200, headers: {'content-type': 'application/json'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanUrl('https://techblog.io/rate-limited');

      expect(result.metadata.title, 'Rate Limited Article');
      expect(result.metadata.author, 'Dev Author');
      expect(result.markdownBody, contains('successfully recovered'));
    });

    test('Tier 2: triggers Reader Fallback when direct HTML is an empty JS SPA shell', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '10000'});
        }

        // Direct fetch returns blank Next.js SPA shell (< 120 chars text)
        if (!request.url.toString().contains('r.jina.ai')) {
          return http.Response(
            '<html><head><title>Next.js App</title></head><body><div id="__next"></div></body></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        }

        final jsonPayload = json.encode({
          'data': {
            'title': 'Client-Rendered SPA Article',
            'content': 'This SPA article content was rendered on the serverless headless cluster and returned cleanly.',
            'metadata': {'author': 'SPA Dev'},
          },
        });
        return http.Response(jsonPayload, 200, headers: {'content-type': 'application/json'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanUrl('https://spa-site.com/post/1');

      expect(result.metadata.title, 'Client-Rendered SPA Article');
      expect(result.metadata.author, 'SPA Dev');
      expect(result.markdownBody, contains('serverless headless cluster'));
    });

    test('Tier 3: throws descriptive error when both direct fetch and reader fallback fail', () async {
      final mockClient = MockClient((request) async {
        if (!request.url.toString().contains('r.jina.ai')) {
          return http.Response('Forbidden', 403);
        }
        return http.Response('Reader service unavailable', 503);
      });

      final scanner = WebClipperScanner(httpClient: mockClient);

      expect(
        () => scanner.scanUrl('https://strictly-private.com/secret'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Direct access was blocked (HTTP 403 Forbidden) and reader fallback was unable to retrieve content'),
        )),
      );
    });

    test('filters UI navigation icons, SVGs, and tracking pixels from markdown image discovery', () async {
      final mockClient = MockClient((request) async {
        final url = request.url.toString();

        if (url.contains('r.jina.ai')) {
          final payload = json.encode({
            'data': {
              'title': 'Sample Article with Assets | Example Author',
              'description': 'An article with many UI icons and photos.',
              'url': 'https://example.com/asset-test',
              'content': '''
![Close Icon](https://example.com/icons/icon_Close.svg)
![Hamburger Menu](https://example.com/Hamburger.svg)
![Logo Stack](https://example.com/LogoStack.svg)
![Tracker Pixel](https://example.com/tracker.png?1x1)
![Real Photo 1](https://example.com/editorial_photo_1.jpg)
![Real Photo 2](https://example.com/editorial_photo_2.png)
''',
            },
          });
          return http.Response(payload, 200, headers: {'content-type': 'application/json'});
        }

        // Direct fetch returns 403 to trigger reader fallback
        return http.Response('Access Denied', 403);
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final result = await scanner.scanUrl('https://example.com/asset-test');

      expect(result.images.length, 2);
      expect(result.images.any((img) => img.rawUrl.contains('editorial_photo_1.jpg')), isTrue);
      expect(result.images.any((img) => img.rawUrl.contains('editorial_photo_2.png')), isTrue);
      expect(result.images.any((img) => img.rawUrl.contains('icon_Close.svg')), isFalse);
      expect(result.images.any((img) => img.rawUrl.contains('Hamburger.svg')), isFalse);
      expect(result.images.any((img) => img.rawUrl.contains('tracker.png')), isFalse);
    });
  });
}
