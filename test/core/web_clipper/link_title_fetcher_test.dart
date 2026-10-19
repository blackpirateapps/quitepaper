import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/link_title_fetcher.dart';

void main() {
  group('LinkTitleFetcher.fetchTitle', () {
    test('returns the <title> for an HTML page', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head><title>My Page Title</title></head>'
          '<body><p>Body text.</p></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('https://example.com'), 'My Page Title');
    });

    test('og:title takes precedence over <title>', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head>'
          '<meta property="og:title" content="Open Graph Title Here">'
          '<title>Fallback Document Title</title>'
          '</head><body><p>Body.</p></body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(
        await fetcher.fetchTitle('https://example.com'),
        'Open Graph Title Here',
      );
    });

    test('non-2xx (404) returns null', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head><title>Not Found</title></head></html>',
          404,
          headers: {'content-type': 'text/html'},
        );
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('https://example.com'), isNull);
    });

    test('non-HTML content-type returns null', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"title": "Not HTML"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('https://example.com'), isNull);
    });

    test('a client that throws returns null', () async {
      final client = MockClient((request) async {
        throw http.ClientException('network down');
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('https://example.com'), isNull);
    });

    test('a slow response that exceeds the timeout returns null', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return http.Response(
          '<html><head><title>Too Late</title></head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final fetcher = LinkTitleFetcher(
        client: client,
        timeout: const Duration(milliseconds: 50),
      );
      expect(await fetcher.fetchTitle('https://example.com'), isNull);
    });

    test('HTML with no usable title returns null (generic fallback)', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><body><p>Just some text, no title.</p></body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('https://example.com'), isNull);
    });

    test('rejects non-http(s) schemes without a request', () async {
      final fetcher = LinkTitleFetcher(client: MockClient((request) async {
        fail('should not perform a request for a non-http(s) url');
      }));
      expect(await fetcher.fetchTitle('qp://note/x'), isNull);
      expect(await fetcher.fetchTitle('mailto:a@b.com'), isNull);
    });

    test('follows 301/302 redirects across schemes and locations', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == 'http://example.com') {
          return http.Response(
            '',
            301,
            headers: {'location': 'https://example.com/blog'},
          );
        }
        if (request.url.toString() == 'https://example.com/blog') {
          return http.Response(
            '<html><head><title>Redirected Blog</title></head></html>',
            200,
            headers: {'content-type': 'application/xhtml+xml'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final fetcher = LinkTitleFetcher(client: client);
      expect(await fetcher.fetchTitle('http://example.com'), 'Redirected Blog');
    });
  });
}
