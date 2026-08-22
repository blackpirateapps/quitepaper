import 'dart:convert';
import 'package:http/http.dart' as http;
import 'article_extractor.dart';
import 'html_to_markdown_converter.dart';
import 'web_clipper_models.dart';
import 'web_snapshot_generator.dart';

/// Pre-scanner for fetching article HTML, parsing metadata, and calculating storage estimates.
class WebClipperScanner {
  WebClipperScanner({
    http.Client? httpClient,
    ArticleExtractor? extractor,
    HtmlToMarkdownConverter? markdownConverter,
    WebSnapshotGenerator? snapshotGenerator,
  })  : _httpClient = httpClient ?? http.Client(),
        _extractor = extractor ?? const ArticleExtractor(),
        _markdownConverter = markdownConverter ?? const HtmlToMarkdownConverter(),
        _snapshotGenerator = snapshotGenerator ??
            WebSnapshotGenerator(httpClient: httpClient ?? http.Client());

  final http.Client _httpClient;
  final ArticleExtractor _extractor;
  final HtmlToMarkdownConverter _markdownConverter;
  final WebSnapshotGenerator _snapshotGenerator;

  /// Scans a [targetUrl], extracts article content, probes candidate images,
  /// and returns a complete [WebClipScanResult] with storage size estimates.
  Future<WebClipScanResult> scanUrl(String targetUrl) async {
    final uri = Uri.tryParse(targetUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw ArgumentError('Invalid webpage URL: $targetUrl');
    }

    // 1. Fetch HTML webpage
    final response = await _httpClient.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 QuietPaper/1.5',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch webpage (HTTP ${response.statusCode})');
    }

    final rawHtml = _decodeBody(response);

    // 2. Extract metadata and article elements
    final extracted = _extractor.extract(
      htmlContent: rawHtml,
      sourceUrl: targetUrl,
    );

    // 3. Probe images for size estimates
    final probedImages = await _probeImages(extracted.images);

    // 4. Generate preliminary Markdown & HTML snapshot to compute sizes
    final leadImageMarkdown = extracted.metadata.leadImageUrl != null
        ? '![${extracted.metadata.title}](${extracted.metadata.leadImageUrl})'
        : null;

    final preliminaryMarkdown = _markdownConverter.convert(
      cleanedElement: extracted.cleanedElement,
      metadata: extracted.metadata,
      leadImageMarkdown: leadImageMarkdown,
    );

    final preliminarySnapshotHtml = await _snapshotGenerator.generateHtmlSnapshot(
      rawHtml: rawHtml,
      metadata: extracted.metadata,
      cleanedElement: extracted.cleanedElement,
    );

    final markdownSizeEstimate = utf8.encode(preliminaryMarkdown).length;
    final htmlSnapshotSizeEstimate = utf8.encode(preliminarySnapshotHtml).length;

    return WebClipScanResult(
      metadata: extracted.metadata,
      rawHtml: rawHtml,
      cleanedArticleHtml: extracted.cleanedElement.outerHtml,
      markdownBody: preliminaryMarkdown,
      markdownSizeEstimate: markdownSizeEstimate,
      htmlSnapshotSizeEstimate: htmlSnapshotSizeEstimate,
      images: probedImages,
    );
  }

  Future<List<ClippedImageCandidate>> _probeImages(
    List<ClippedImageCandidate> rawCandidates,
  ) async {
    final probed = <ClippedImageCandidate>[];

    for (final candidate in rawCandidates) {
      var size = candidate.estimatedSizeBytes;

      try {
        final uri = Uri.tryParse(candidate.resolvedUrl);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          final headRes = await _httpClient.head(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
            },
          ).timeout(const Duration(seconds: 3));

          final cl = headRes.headers['content-length'];
          if (cl != null) {
            final parsedCl = int.tryParse(cl);
            if (parsedCl != null && parsedCl > 0) {
              size = parsedCl;
            }
          }
        }
      } catch (_) {
        // Fallback to default estimate if HEAD fails
      }

      probed.add(candidate.copyWith(estimatedSizeBytes: size));
    }

    return probed;
  }

  String _decodeBody(http.Response response) {
    try {
      final contentType = response.headers['content-type'];
      if (contentType != null && contentType.toLowerCase().contains('charset=')) {
        final charsetMatch = RegExp(r'charset=([a-zA-Z0-9_\-]+)', caseSensitive: false)
            .firstMatch(contentType);
        if (charsetMatch != null) {
          final charsetName = charsetMatch.group(1)?.toLowerCase();
          if (charsetName == 'latin1' || charsetName == 'iso-8859-1') {
            return latin1.decode(response.bodyBytes);
          }
        }
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      return response.body;
    }
  }
}
