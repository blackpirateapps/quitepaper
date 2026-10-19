import 'package:http/http.dart' as http;
import 'article_extractor.dart';

/// Thin wrapper that fetches a web page and resolves its display title.
///
/// Used by the web-link feature to upgrade a bare URL into a readable title.
/// Deliberately privacy-preserving: it NEVER logs or prints the fetched [url],
/// and returns null on any failure so callers can fall back to the URL itself.
class LinkTitleFetcher {
  LinkTitleFetcher({
    http.Client? client,
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        // ignore: prefer_initializing_formals
        _timeout = timeout;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  /// Browser-like User-Agent so sites return their normal HTML rather than a
  /// bot/challenge page. Mirrors WebImageDownloader's request headers.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  /// Generic placeholder [ArticleExtractor] returns when no real title exists.
  static const String _genericFallbackTitle = 'Web Article';

  /// Fetches [url], extracts the page/OG title via ArticleExtractor.
  /// Returns null on ANY failure: non-2xx, timeout, non-HTML content-type,
  /// network error, or no usable title. NEVER logs or prints the url.
  Future<String?> fetchTitle(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return null;
    }

    try {
      var currentUri = uri;
      http.Response? response;

      for (var i = 0; i < 5; i++) {
        final request = http.Request('GET', currentUri)
          ..headers.addAll(const {
            'User-Agent': _userAgent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          })
          ..followRedirects = false;

        final streamed = await _client.send(request).timeout(_timeout);
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode >= 300 &&
            resp.statusCode < 400 &&
            resp.headers.containsKey('location')) {
          final location = resp.headers['location']!;
          final nextUri = currentUri.resolve(location);
          if (!nextUri.isScheme('http') && !nextUri.isScheme('https')) {
            return null;
          }
          currentUri = nextUri;
          continue;
        }

        response = resp;
        break;
      }

      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.isNotEmpty &&
          !contentType.contains('html') &&
          !contentType.contains('xml')) {
        return null;
      }

      const extractor = ArticleExtractor();
      final title =
          extractor.extractFromHtml(response.body, currentUri.toString()).metadata.title.trim();

      // Treat the generic fallback as "no title" so callers keep the URL as-is.
      if (title.isEmpty || title == _genericFallbackTitle) {
        return null;
      }
      return title;
    } catch (_) {
      // Swallow timeouts, socket errors, and parse failures: callers fall back
      // to the URL. Intentionally does not surface the url in any log.
      return null;
    } finally {
      if (_ownsClient) {
        _client.close();
      }
    }
  }
}
