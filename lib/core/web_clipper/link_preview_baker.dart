import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../features/editor/application/link_preview_metadata.dart';
import '../../features/editor/domain/rich_block.dart';
import '../attachments/attachment_provider.dart';
import '../attachments/attachment_service.dart';
import '../image_processing/image_adjustments.dart';
import '../image_processing/image_processor.dart';
import '../ocr/ocr_provider.dart';
import '../utils/web_url_helper.dart';
import 'article_extractor.dart';
import 'link_fetch_diagnostics.dart';
import 'web_clipper_models.dart';

/// Bakes a plain web URL into a rich [LinkPreviewBlock]: fetches the page,
/// extracts OpenGraph/Twitter preview metadata, and downloads + compresses the
/// lead image into a HIDDEN encrypted attachment (kind `linkPreview`, no OCR).
///
/// The service is a plain async coordinator with no UI dependency, so its
/// network and crypto work runs off the UI thread naturally. It never logs the
/// previewed URL.
class LinkPreviewBaker {
  LinkPreviewBaker({
    http.Client? client,
    required AttachmentService attachmentService,
    ImageProcessor? imageProcessor,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _attachmentService = attachmentService,
        _imageProcessor = imageProcessor ?? const DartImageProcessor();

  final http.Client _client;
  final AttachmentService _attachmentService;
  final ImageProcessor _imageProcessor;

  static const _uuid = Uuid();

  /// Max dimension (px) for the baked, compressed preview thumbnail. Smaller
  /// than any settings-enum image preset (whose floor is 1280px) because a
  /// link-preview card only ever renders a small inline thumbnail.
  static const int _thumbnailMaxDimension = 800;

  /// Modern browser navigation headers for fetching the page HTML.
  static const Map<String, String> _htmlHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Upgrade-Insecure-Requests': '1',
  };

  /// Browser headers for fetching the lead image bytes.
  static const Map<String, String> _imageHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static final RegExp _markdownLinkLineRegex =
      RegExp(r'^\s*\[([^\]]*)\]\((https?://[^)\s]+)(?:\s+"[^"]*")?\)\s*$');

  /// Fetches [uri] with [headers], following 301/302/303/307/308 redirects manually
  /// up to [maxRedirects]. This avoids dart:io's refusal to follow cross-scheme
  /// (HTTP -> HTTPS) redirects which throws a RedirectException.
  /// Helper holding the outcome of a manual redirect chain with diagnostics.
  Future<_RedirectResult> _getWithRedirectsDetailed(
    Uri uri,
    Map<String, String> headers, {
    Duration timeout = const Duration(seconds: 10),
    int maxRedirects = 5,
  }) async {
    var currentUri = uri;
    for (var i = 0; i < maxRedirects; i++) {
      final request = http.Request('GET', currentUri);
      request.headers.addAll(headers);
      request.followRedirects = false;

      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await _client.send(request).timeout(timeout);
      } catch (e) {
        return _RedirectResult(finalUri: currentUri, exception: e);
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        final nextUri = currentUri.resolve(location);
        if (!nextUri.isScheme('http') && !nextUri.isScheme('https')) {
          return _RedirectResult(
            response: response,
            finalUri: currentUri,
            exception: 'Redirected to unsupported scheme: ${nextUri.scheme}',
          );
        }
        currentUri = nextUri;
        continue;
      }
      return _RedirectResult(response: response, finalUri: currentUri);
    }
    return _RedirectResult(
      finalUri: currentUri,
      redirectLimitExceeded: true,
      exception: 'Exceeded maximum redirect limit of $maxRedirects',
    );
  }

  /// Fetches [url], extracts preview metadata, and captures comprehensive
  /// diagnostic telemetry explaining the outcome of each step.
  Future<LinkBakeResult> bakeUrlWithDiagnostics(
    String url, {
    String? noteId,
  }) async {
    final stopwatch = Stopwatch()..start();
    final target = url.trim();
    final uri = Uri.tryParse(target);
    final now = DateTime.now();

    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.urlValidation,
          reason: uri == null
              ? 'Could not parse "$target" as a valid URL.'
              : 'Unsupported URL scheme "${uri.scheme}". Only http:// and https:// URLs are supported.',
          duration: stopwatch.elapsed,
        ),
      );
    }

    final http.Response response;
    final Uri finalUri;
    try {
      final redirectResult =
          await _getWithRedirectsDetailed(uri, _htmlHeaders);
      if (redirectResult.exception != null) {
        return LinkBakeResult(
          diagnostics: LinkFetchDiagnostics(
            url: target,
            timestamp: now,
            stage: LinkFetchStage.pageFetch,
            reason: _friendlyNetworkError(redirectResult.exception!),
            rawException: redirectResult.exception.toString(),
            duration: stopwatch.elapsed,
            resolvedRedirectUri: redirectResult.finalUri?.toString(),
          ),
        );
      }
      if (redirectResult.response == null) {
        return LinkBakeResult(
          diagnostics: LinkFetchDiagnostics(
            url: target,
            timestamp: now,
            stage: LinkFetchStage.pageFetch,
            reason: redirectResult.redirectLimitExceeded
                ? 'Too many redirects (exceeded limit of 5).'
                : 'Failed to establish connection to $target.',
            duration: stopwatch.elapsed,
            resolvedRedirectUri: redirectResult.finalUri?.toString(),
          ),
        );
      }
      response = redirectResult.response!;
      finalUri = redirectResult.finalUri ?? uri;
    } catch (e) {
      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.pageFetch,
          reason: _friendlyNetworkError(e),
          rawException: e.toString(),
          duration: stopwatch.elapsed,
        ),
      );
    }

    // Check HTTP status code
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String reason = 'Server returned HTTP ${response.statusCode}';
      if (response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty) {
        reason += ' (${response.reasonPhrase})';
      }
      if (response.statusCode == 403) {
        reason += ' — Access denied or anti-bot challenge (Cloudflare/WAF).';
      } else if (response.statusCode == 404) {
        reason += ' — Page not found on the server.';
      } else if (response.statusCode >= 500) {
        reason += ' — Remote web server error.';
      }

      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.pageFetch,
          reason: reason,
          httpStatusCode: response.statusCode,
          httpStatusReason: response.reasonPhrase,
          contentType: response.headers['content-type'],
          duration: stopwatch.elapsed,
          resolvedRedirectUri: finalUri.toString(),
        ),
      );
    }

    // Check Content-Type
    final contentType = response.headers['content-type']?.toLowerCase();
    if (contentType != null &&
        !contentType.contains('html') &&
        !contentType.contains('xml')) {
      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.htmlParsing,
          reason:
              'Expected HTML document, but server returned Content-Type "$contentType".',
          httpStatusCode: response.statusCode,
          httpStatusReason: response.reasonPhrase,
          contentType: contentType,
          duration: stopwatch.elapsed,
          resolvedRedirectUri: finalUri.toString(),
        ),
      );
    }

    if (response.body.trim().isEmpty) {
      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.htmlParsing,
          reason: 'Server returned an empty response body (0 bytes).',
          httpStatusCode: response.statusCode,
          httpStatusReason: response.reasonPhrase,
          contentType: contentType,
          duration: stopwatch.elapsed,
          resolvedRedirectUri: finalUri.toString(),
        ),
      );
    }

    // Extract metadata
    final ExtractedArticleMetadata metadata;
    try {
      metadata =
          const ArticleExtractor().extractFromHtml(response.body, target).metadata;
    } catch (e) {
      return LinkBakeResult(
        diagnostics: LinkFetchDiagnostics(
          url: target,
          timestamp: now,
          stage: LinkFetchStage.metadataExtraction,
          reason: 'Failed to extract metadata from HTML: $e',
          rawException: e.toString(),
          httpStatusCode: response.statusCode,
          httpStatusReason: response.reasonPhrase,
          contentType: contentType,
          duration: stopwatch.elapsed,
          resolvedRedirectUri: finalUri.toString(),
        ),
      );
    }

    var title = _sanitizeTitle(metadata.title);
    if (title.isEmpty || title == 'Web Article') {
      title = metadata.domain.isNotEmpty
          ? metadata.domain
          : (finalUri.host.isNotEmpty ? finalUri.host : target);
    }

    final description =
        (metadata.description != null && metadata.description!.isNotEmpty)
            ? metadata.description
            : null;
    final siteName =
        (metadata.siteName != null && metadata.siteName!.isNotEmpty)
            ? metadata.siteName
            : (metadata.domain.isNotEmpty ? metadata.domain : finalUri.host);

    final thumbResult = await _bakeThumbnailWithDiagnostics(
      metadata.leadImageUrl,
      noteId: noteId,
      altText: title,
    );

    final block = LinkPreviewBlock(
      id: _uuid.v4(),
      url: target,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbResult.assetId,
      fetchedAt: DateTime.now(),
    );

    return LinkBakeResult(
      block: block,
      diagnostics: LinkFetchDiagnostics(
        url: target,
        timestamp: now,
        stage: LinkFetchStage.metadataExtraction,
        reason:
            'Successfully fetched link metadata${thumbResult.assetId != null ? ' and thumbnail' : ''}.',
        httpStatusCode: response.statusCode,
        httpStatusReason: response.reasonPhrase,
        contentType: contentType,
        duration: stopwatch.elapsed,
        resolvedRedirectUri: finalUri.toString(),
        extractedTitle: title,
        extractedDescription: description,
        extractedSiteName: siteName,
        leadImageUrl: metadata.leadImageUrl,
        leadImageStatusCode: thumbResult.statusCode,
        leadImageError: thumbResult.error,
      ),
    );
  }

  /// Fetches [url], extracts preview metadata, and (best-effort) bakes its lead
  /// image into a hidden encrypted thumbnail attachment.
  ///
  /// Returns `null` ONLY when the page fetch / metadata step fails (non-2xx,
  /// non-HTML, network error, or unparseable) so a broken card is never baked.
  /// If only the thumbnail step fails, a text-only block (null
  /// [LinkPreviewBlock.thumbnailAssetId]) is still returned. Never logs [url].
  Future<LinkPreviewBlock?> bakeUrl(String url, {String? noteId}) async {
    final result = await bakeUrlWithDiagnostics(url, noteId: noteId);
    return result.block;
  }

  /// Lone-line bare `http(s)` URLs or lone `[title](url)` Markdown links in [markdown]
  /// eligible for baking: a line whose trimmed content is exactly one web URL
  /// ([isSingleWebUrl]) or a standalone Markdown link not followed by a
  /// `qp-link-preview` sentinel comment.
  ///
  /// A line already in baked `[title](url)` form with a sentinel comment is
  /// naturally excluded (no re-bake). Order-preserving.
  List<String> findUnbakedLoneLineUrls(String markdown) {
    final urls = <String>[];
    final lines = markdown.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;

      String? urlCandidate;
      if (isSingleWebUrl(trimmed)) {
        urlCandidate = trimmed;
      } else {
        final match = _markdownLinkLineRegex.firstMatch(trimmed);
        if (match != null) {
          urlCandidate = match.group(2);
        }
      }

      if (urlCandidate != null) {
        final isBaked = i + 1 < lines.length && isLinkPreviewComment(lines[i + 1]);
        if (!isBaked) {
          urls.add(urlCandidate);
        }
      }
    }
    return urls;
  }

  /// Bakes each eligible lone-line URL in [markdown] and substitutes it in
  /// place with the visible link line followed by the sentinel comment line
  /// (`[<title>](<url>)\n<encodeLinkPreviewComment(block)>`).
  ///
  /// Order-preserving. Returns the input unchanged if nothing is bakeable or
  /// every fetch fails (e.g. offline). Never logs any URL.
  Future<String> bakeMarkdown(String markdown, {String? noteId}) async {
    if (markdown.isEmpty) return markdown;

    final lines = markdown.split('\n');
    final output = <String>[];
    var changed = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      String? urlCandidate;
      if (isSingleWebUrl(trimmed)) {
        urlCandidate = trimmed;
      } else {
        final match = _markdownLinkLineRegex.firstMatch(trimmed);
        if (match != null) {
          urlCandidate = match.group(2);
        }
      }

      if (urlCandidate != null) {
        if (i + 1 < lines.length && isLinkPreviewComment(lines[i + 1])) {
          output.add(line);
          continue;
        }

        final block = await bakeUrl(urlCandidate, noteId: noteId);
        if (block != null) {
          output.add('[${block.title}](${block.url})');
          output.add(encodeLinkPreviewComment(block));
          changed = true;
          continue;
        }
      }

      output.add(line);
    }

    if (!changed) return markdown;
    return output.join('\n');
  }

  /// Best-effort: downloads [leadImageUrl], compresses it to
  /// [_thumbnailMaxDimension], and imports it as a hidden `linkPreview`
  /// attachment. Returns the `qp://asset/<id>` ref, or `null` on any failure.
  /// Best-effort: downloads [leadImageUrl], compresses it to
  /// [_thumbnailMaxDimension], and imports it as a hidden `linkPreview`
  /// attachment, capturing status codes and errors if it fails.
  Future<({String? assetId, int? statusCode, String? error})>
      _bakeThumbnailWithDiagnostics(
    String? leadImageUrl, {
    String? noteId,
    required String altText,
  }) async {
    if (leadImageUrl == null || leadImageUrl.trim().isEmpty) {
      return (
        assetId: null,
        statusCode: null,
        error: 'No lead image specified in page metadata',
      );
    }
    final imageUri = Uri.tryParse(leadImageUrl.trim());
    if (imageUri == null ||
        (!imageUri.isScheme('http') && !imageUri.isScheme('https'))) {
      return (
        assetId: null,
        statusCode: null,
        error: 'Invalid lead image URL scheme: "${imageUri?.scheme}"',
      );
    }

    try {
      final redirectResult =
          await _getWithRedirectsDetailed(imageUri, _imageHeaders);
      if (redirectResult.exception != null) {
        return (
          assetId: null,
          statusCode: null,
          error: 'Lead image download failed: ${redirectResult.exception}',
        );
      }
      final response = redirectResult.response;
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return (
          assetId: null,
          statusCode: response?.statusCode,
          error:
              'Lead image server returned HTTP ${response?.statusCode ?? "no response"}',
        );
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return (
          assetId: null,
          statusCode: response.statusCode,
          error: 'Lead image response body was empty (0 bytes)',
        );
      }
      if (bytes.length > AttachmentService.maxFileSizeBytes) {
        return (
          assetId: null,
          statusCode: response.statusCode,
          error: 'Lead image exceeded 10MB limit (${bytes.length} bytes)',
        );
      }

      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != null &&
          contentType.isNotEmpty &&
          !contentType.startsWith('image/')) {
        return (
          assetId: null,
          statusCode: response.statusCode,
          error: 'Lead image Content-Type "$contentType" is not an image',
        );
      }

      final compressed = await _imageProcessor.process(
        bytes,
        ImageAdjustments.neutral,
        maxDimension: _thumbnailMaxDimension,
      );
      if (compressed.isEmpty) {
        return (
          assetId: null,
          statusCode: response.statusCode,
          error: 'Lead image compression/downscaling produced empty bytes',
        );
      }

      final result = await _attachmentService.importImageFromBytes(
        compressed,
        mimeType: 'image/jpeg',
        noteId: noteId,
        preferredAltText: altText.isNotEmpty ? altText : 'Link preview',
        kind: 'linkPreview',
        skipOcr: true,
      );

      return (
        assetId: 'qp://asset/${result.attachment.id}',
        statusCode: response.statusCode,
        error: null,
      );
    } catch (e) {
      return (
        assetId: null,
        statusCode: null,
        error: 'Thumbnail processing failed: $e',
      );
    }
  }

  /// Maps technical network errors to clear, actionable human explanations.
  String _friendlyNetworkError(Object error) {
    final str = error.toString();
    if (str.contains('SocketException') || str.contains('Failed host lookup')) {
      return 'Network connection failed: Unable to resolve hostname (DNS lookup failed or device offline).';
    }
    if (str.contains('TimeoutException') || str.contains('timed out')) {
      return 'Network request timed out after 10 seconds.';
    }
    if (str.contains('HandshakeException') ||
        str.contains('CERTIFICATE_VERIFY_FAILED')) {
      return 'SSL/TLS handshake failed: Invalid or untrusted certificate.';
    }
    if (str.contains('Connection refused')) {
      return 'Connection refused by remote server.';
    }
    return 'Network request failed: $str';
  }

  /// Collapses whitespace and strips `[`/`]` so the title stays a single-line,
  /// decodable Markdown link text.
  String _sanitizeTitle(String input) {
    return input
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Helper holding redirect chain results and exception info.
class _RedirectResult {
  const _RedirectResult({
    this.response,
    this.finalUri,
    this.exception,
    this.redirectLimitExceeded = false,
  });

  final http.Response? response;
  final Uri? finalUri;
  final Object? exception;
  final bool redirectLimitExceeded;
}

/// Riverpod provider exposing a [LinkPreviewBaker] wired to the shared
/// attachment service and the pure-Dart image processor.
final linkPreviewBakerProvider = Provider<LinkPreviewBaker>((ref) {
  return LinkPreviewBaker(
    attachmentService: ref.watch(attachmentServiceProvider),
    imageProcessor: ref.watch(imageProcessorProvider),
  );
});
