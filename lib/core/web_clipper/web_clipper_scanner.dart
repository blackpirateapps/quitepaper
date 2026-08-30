import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'article_extractor.dart';
import 'html_to_markdown_converter.dart';
import 'web_clipper_models.dart';
import 'web_snapshot_generator.dart';

/// Pre-scanner for fetching article HTML, parsing metadata, probing images,
/// and calculating storage estimates.
///
/// Features a Multi-Tier Resilient Scraping Engine:
/// 1. Direct HTTP fetch with modern standard browser navigation headers.
/// 2. Automatic fallback to high-performance Reader Engine (r.jina.ai) when direct
///    requests encounter WAF / anti-bot blocks (HTTP 403, 401, 429, 503) or empty JS SPAs.
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

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'en-US,en;q=0.9',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };

  /// Scans a [targetUrl], extracts article content, probes candidate images,
  /// and returns a complete [WebClipScanResult] with storage size estimates.
  Future<WebClipScanResult> scanUrl(String targetUrl) async {
    final uri = Uri.tryParse(targetUrl);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw ArgumentError('Invalid webpage URL: $targetUrl');
    }

    // 1. Try Direct HTTP fetch first
    http.Response? directResponse;
    Object? directError;

    try {
      directResponse = await _httpClient.get(
        uri,
        headers: _browserHeaders,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      directError = e;
    }

    if (directResponse != null &&
        directResponse.statusCode >= 200 &&
        directResponse.statusCode < 300) {
      final rawHtml = _decodeBody(directResponse);
      final extracted = _extractor.extract(
        htmlContent: rawHtml,
        sourceUrl: targetUrl,
      );

      final extractedText = extracted.cleanedElement.text.trim();
      final hasContent = extractedText.length >= 10;

      // If direct fetch has meaningful extracted content, use direct result
      if (hasContent) {
        return _compileScanResult(
          metadata: extracted.metadata,
          rawHtml: rawHtml,
          cleanedElement: extracted.cleanedElement,
          rawImages: extracted.images,
        );
      }
    }

    // 2. If direct fetch failed (403, 401, 429, 500, 503, network error, or empty JS SPA body),
    // trigger resilient Reader Engine fallback (r.jina.ai).
    try {
      return await _scanViaReaderFallback(targetUrl, uri);
    } catch (fallbackError) {
      final domain = uri.host.replaceFirst(RegExp(r'^www\.'), '');
      if (directResponse != null && directResponse.statusCode == 403) {
        throw Exception(
          'Failed to clip $domain: Direct access was blocked (HTTP 403 Forbidden) and reader fallback was unable to retrieve content.',
        );
      } else if (directResponse != null && directResponse.statusCode == 401) {
        throw Exception(
          'Failed to clip $domain: Access is restricted (HTTP 401 Unauthorized / Login Required).',
        );
      } else if (directResponse != null && directResponse.statusCode >= 400) {
        throw Exception(
          'Failed to clip $domain (HTTP ${directResponse.statusCode}): ${fallbackError.toString().replaceFirst("Exception: ", "")}',
        );
      }
      throw Exception(
        'Failed to clip $domain: ${directError ?? fallbackError}'.replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<WebClipScanResult> _scanViaReaderFallback(
    String targetUrl,
    Uri originalUri,
  ) async {
    final readerUri = Uri.parse('https://r.jina.ai/$targetUrl');

    final readerResponse = await _httpClient.get(
      readerUri,
      headers: const {
        'Accept': 'application/json',
        'X-Return-Format': 'markdown',
      },
    ).timeout(const Duration(seconds: 20));

    if (readerResponse.statusCode < 200 || readerResponse.statusCode >= 300) {
      throw Exception('Reader service returned HTTP ${readerResponse.statusCode}');
    }

    final rawBody = _decodeBody(readerResponse);
    return _parseReaderOutput(rawBody, targetUrl, originalUri);
  }

  Future<WebClipScanResult> _parseReaderOutput(
    String rawBody,
    String targetUrl,
    Uri originalUri,
  ) async {
    String title = 'Web Article';
    String? description;
    String? author;
    String? leadImageUrl;
    String markdownBody = '';
    DateTime? publishedDate;
    String? siteName;

    // Try parsing as JSON first
    bool isJson = false;
    try {
      final decoded = json.decode(rawBody);
      if (decoded is Map<String, dynamic>) {
        isJson = true;
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        title = data['title'] as String? ?? 'Web Article';
        description = data['description'] as String?;
        markdownBody = data['content'] as String? ?? '';

        final meta = (data['metadata'] is Map<String, dynamic>)
            ? data['metadata'] as Map<String, dynamic>
            : <String, dynamic>{};

        author = meta['author'] as String? ??
            meta['twitter:creator'] as String? ??
            meta['twitter:site'] as String?;
        leadImageUrl = meta['og:image'] as String? ??
            meta['twitter:image'] as String? ??
            meta['twitter:image:src'] as String?;
        siteName = meta['og:site_name'] as String? ?? meta['site_name'] as String?;

        final pubDateStr = meta['article:published_time']?.toString() ??
            meta['date']?.toString() ??
            meta['pubdate']?.toString();
        if (pubDateStr != null && pubDateStr.isNotEmpty) {
          publishedDate = DateTime.tryParse(pubDateStr);
        }
      }
    } catch (_) {}

    // If not JSON or plain text format, parse plain markdown with headers
    if (!isJson || markdownBody.isEmpty) {
      final lines = rawBody.split('\n');
      var contentStartIndex = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('Title:')) {
          title = line.substring('Title:'.length).trim();
        } else if (line.startsWith('URL Source:')) {
          // target url verified
        } else if (line.startsWith('Markdown Content:')) {
          contentStartIndex = i + 1;
          break;
        }
      }

      markdownBody = lines.sublist(contentStartIndex).join('\n').trim();
      if (markdownBody.isEmpty) {
        markdownBody = rawBody.trim();
      }
    }

    // Clean title and extract author if embedded in title (e.g. "Title | Bill Gates")
    final cleanedTitle = _cleanTitle(title);
    if (author == null || author.isEmpty) {
      author = _extractAuthorFromTitle(title);
    }

    String domain = originalUri.host.replaceFirst(RegExp(r'^www\.'), '');
    if (domain.isEmpty) {
      domain = 'web';
    }

    // Clean leading duplicate title in markdownBody if redundant
    markdownBody = _cleanRedundantMarkdownHeader(markdownBody, title, cleanedTitle);

    // Extract image candidates from markdown body and lead image
    final discoveredImages = _discoverImagesFromMarkdown(
      markdownBody: markdownBody,
      leadImageUrl: leadImageUrl,
      sourceUri: originalUri,
    );

    if (leadImageUrl == null && discoveredImages.isNotEmpty) {
      final firstLeadCandidate = discoveredImages.firstWhere(
        (img) => img.isLeadImage,
        orElse: () => discoveredImages.first,
      );
      leadImageUrl = firstLeadCandidate.resolvedUrl;
    }

    final metadata = ExtractedArticleMetadata(
      sourceUrl: targetUrl,
      title: cleanedTitle,
      author: author,
      publishedDate: publishedDate,
      description: description,
      leadImageUrl: leadImageUrl,
      domain: domain,
      siteName: siteName,
    );

    // Convert markdown to HTML representation for cleanedElement & snapshot
    final htmlContent = md.markdownToHtml(
      markdownBody,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final syntheticRawHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${_htmlEscape(cleanedTitle)}</title>
  ${author != null ? '<meta name="author" content="${_htmlEscape(author)}">' : ''}
  ${description != null ? '<meta name="description" content="${_htmlEscape(description)}">' : ''}
  <meta property="og:title" content="${_htmlEscape(cleanedTitle)}">
  ${leadImageUrl != null ? '<meta property="og:image" content="${_htmlEscape(leadImageUrl)}">' : ''}
  <base href="$targetUrl">
</head>
<body>
  <article>
    <h1>${_htmlEscape(cleanedTitle)}</h1>
    $htmlContent
  </article>
</body>
</html>
''';

    final doc = html_parser.parse(syntheticRawHtml);
    final cleanedElement = doc.querySelector('article') ?? doc.body ?? doc.documentElement!;

    return _compileScanResult(
      metadata: metadata,
      rawHtml: syntheticRawHtml,
      cleanedElement: cleanedElement,
      rawImages: discoveredImages,
      customMarkdownBody: markdownBody,
    );
  }

  String _cleanTitle(String rawTitle) {
    var cleaned = rawTitle.trim();
    final separators = [' — ', ' – ', ' | ', ' :: ', ' - '];
    for (final sep in separators) {
      if (cleaned.contains(sep)) {
        final parts = cleaned.split(sep);
        if (parts.first.trim().length >= 8) {
          cleaned = parts.first.trim();
          break;
        }
      }
    }
    return cleaned;
  }

  String? _extractAuthorFromTitle(String rawTitle) {
    final separators = [' — ', ' – ', ' | '];
    for (final sep in separators) {
      if (rawTitle.contains(sep)) {
        final parts = rawTitle.split(sep);
        if (parts.length >= 2) {
          final candidate = parts.last.trim();
          if (candidate.length >= 3 && candidate.length <= 40 && !candidate.contains('.')) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  String _cleanRedundantMarkdownHeader(String markdown, String rawTitle, String cleanTitle) {
    var cleaned = markdown.trim();
    final firstLine = cleaned.split('\n').first.trim();
    final strippedFirstLine = firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();

    if (strippedFirstLine == rawTitle.trim() ||
        strippedFirstLine == cleanTitle.trim() ||
        strippedFirstLine.toLowerCase() == cleanTitle.toLowerCase()) {
      final lines = cleaned.split('\n');
      lines.removeAt(0);
      cleaned = lines.join('\n').trim();
    }
    return cleaned;
  }

  List<ClippedImageCandidate> _discoverImagesFromMarkdown({
    required String markdownBody,
    required String? leadImageUrl,
    required Uri sourceUri,
  }) {
    final images = <ClippedImageCandidate>[];
    final seenUrls = <String>{};

    if (leadImageUrl != null && leadImageUrl.trim().isNotEmpty) {
      final resolved = _resolveUrl(leadImageUrl, sourceUri);
      if (_isValidImageUrl(resolved)) {
        images.add(ClippedImageCandidate(
          rawUrl: leadImageUrl,
          resolvedUrl: resolved,
          altText: 'Lead Image',
          isLeadImage: true,
          isSelected: true,
          estimatedSizeBytes: 350 * 1024,
        ));
        seenUrls.add(resolved);
      }
    }

    final imgRegex = RegExp(r'!\[(.*?)\]\(((https?:\/\/[^\s\)]+))\)');
    final matches = imgRegex.allMatches(markdownBody);

    for (final match in matches) {
      final alt = match.group(1)?.trim() ?? '';
      final rawSrc = match.group(2)?.trim() ?? '';
      if (rawSrc.isEmpty || _isIgnoredAltText(alt)) continue;

      final resolved = _resolveUrl(rawSrc, sourceUri);
      if (seenUrls.contains(resolved) || !_isValidImageUrl(resolved)) continue;

      images.add(ClippedImageCandidate(
        rawUrl: rawSrc,
        resolvedUrl: resolved,
        altText: alt.isNotEmpty ? alt : 'Article image',
        isLeadImage: false,
        isSelected: true,
        estimatedSizeBytes: 250 * 1024,
      ));
      seenUrls.add(resolved);

      // Bound discovery to the top 25 highest quality content images
      if (images.length >= 25) {
        break;
      }
    }

    return images;
  }

  bool _isIgnoredAltText(String alt) {
    final lower = alt.toLowerCase().trim();
    return lower.contains('icon') ||
        lower.contains('logo') ||
        lower.contains('close') ||
        lower.contains('arrow') ||
        lower.contains('hamburger') ||
        lower.contains('menu');
  }

  String _resolveUrl(String url, Uri baseUri) {
    final trimmed = url.trim();
    if (trimmed.startsWith('//')) {
      return '${baseUri.scheme.isNotEmpty ? baseUri.scheme : "https"}:$trimmed';
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;
    if (parsed.hasScheme) return trimmed;
    return baseUri.resolveUri(parsed).toString();
  }

  bool _isValidImageUrl(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.isEmpty) return false;
    if (lower.startsWith('data:image/svg') ||
        lower.endsWith('.svg') ||
        lower.contains('.svg?') ||
        lower.contains('.svg#')) {
      return false;
    }
    if (lower.contains('tracker') ||
        lower.contains('1x1') ||
        lower.contains('pixel') ||
        lower.contains('adsct') ||
        lower.contains('beacon')) {
      return false;
    }
    if (lower.contains('icon_') ||
        lower.contains('/icons/') ||
        lower.contains('hamburger') ||
        lower.contains('logostack')) {
      return false;
    }
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  String _htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<WebClipScanResult> _compileScanResult({
    required ExtractedArticleMetadata metadata,
    required String rawHtml,
    required dom.Element cleanedElement,
    required List<ClippedImageCandidate> rawImages,
    String? customMarkdownBody,
  }) async {
    // 1. Probe images for size estimates
    final probedImages = await _probeImages(rawImages);

    // 2. Generate Markdown & HTML snapshot to compute sizes
    final leadImageMarkdown = metadata.leadImageUrl != null
        ? '![${metadata.title}](${metadata.leadImageUrl})'
        : null;

    final markdown = customMarkdownBody != null
        ? _markdownConverter.convertWithBody(
            bodyMarkdown: customMarkdownBody,
            metadata: metadata,
            leadImageMarkdown: leadImageMarkdown,
          )
        : _markdownConverter.convert(
            cleanedElement: cleanedElement,
            metadata: metadata,
            leadImageMarkdown: leadImageMarkdown,
          );

    final preliminarySnapshotHtml = await _snapshotGenerator.generateHtmlSnapshot(
      rawHtml: rawHtml,
      metadata: metadata,
      cleanedElement: cleanedElement,
    );

    final markdownSizeEstimate = utf8.encode(markdown).length;
    final htmlSnapshotSizeEstimate = utf8.encode(preliminarySnapshotHtml).length;

    return WebClipScanResult(
      metadata: metadata,
      rawHtml: rawHtml,
      cleanedArticleHtml: cleanedElement.outerHtml,
      markdownBody: markdown,
      markdownSizeEstimate: markdownSizeEstimate,
      htmlSnapshotSizeEstimate: htmlSnapshotSizeEstimate,
      images: probedImages,
    );
  }

  Future<List<ClippedImageCandidate>> _probeImages(
    List<ClippedImageCandidate> rawCandidates,
  ) async {
    if (rawCandidates.isEmpty) return const [];

    final candidatesToProbe = rawCandidates.take(20).toList();
    final remaining = rawCandidates.skip(20).toList();

    final probed = await Future.wait(
      candidatesToProbe.map((candidate) async {
        var size = candidate.estimatedSizeBytes;

        try {
          final uri = Uri.tryParse(candidate.resolvedUrl);
          if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
            final headRes = await _httpClient.head(
              uri,
              headers: {
                'User-Agent': _browserHeaders['User-Agent']!,
              },
            ).timeout(const Duration(milliseconds: 1500));

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

        return candidate.copyWith(estimatedSizeBytes: size);
      }),
    );

    return [...probed, ...remaining];
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

