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
  Future<http.Response?> _getWithRedirects(
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
      } catch (_) {
        return null;
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        final nextUri = currentUri.resolve(location);
        if (!nextUri.isScheme('http') && !nextUri.isScheme('https')) {
          return null;
        }
        currentUri = nextUri;
        continue;
      }
      return response;
    }
    return null;
  }

  /// Fetches [url], extracts preview metadata, and (best-effort) bakes its lead
  /// image into a hidden encrypted thumbnail attachment.
  ///
  /// Returns `null` ONLY when the page fetch / metadata step fails (non-2xx,
  /// non-HTML, network error, or unparseable) so a broken card is never baked.
  /// If only the thumbnail step fails, a text-only block (null
  /// [LinkPreviewBlock.thumbnailAssetId]) is still returned. Never logs [url].
  Future<LinkPreviewBlock?> bakeUrl(String url, {String? noteId}) async {
    final target = url.trim();
    final uri = Uri.tryParse(target);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return null;
    }

    final String html;
    try {
      final response = await _getWithRedirects(uri, _htmlHeaders);
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }
      final contentType = response.headers['content-type']?.toLowerCase();
      if (contentType != null &&
          !contentType.contains('html') &&
          !contentType.contains('xml')) {
        return null; // Not an HTML document.
      }
      if (response.body.trim().isEmpty) {
        return null;
      }
      html = response.body;
    } catch (_) {
      return null;
    }

    final ExtractedArticleMetadata metadata;
    try {
      metadata = const ArticleExtractor().extractFromHtml(html, target).metadata;
    } catch (_) {
      return null;
    }

    var title = _sanitizeTitle(metadata.title);
    if (title.isEmpty || title == 'Web Article') {
      title = metadata.domain.isNotEmpty
          ? metadata.domain
          : (uri.host.isNotEmpty ? uri.host : target);
    }

    final description =
        (metadata.description != null && metadata.description!.isNotEmpty)
            ? metadata.description
            : null;
    final siteName =
        (metadata.siteName != null && metadata.siteName!.isNotEmpty)
            ? metadata.siteName
            : (metadata.domain.isNotEmpty ? metadata.domain : uri.host);

    final thumbnailAssetId = await _bakeThumbnail(
      metadata.leadImageUrl,
      noteId: noteId,
      altText: title,
    );

    return LinkPreviewBlock(
      id: _uuid.v4(),
      url: target,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: DateTime.now(),
    );
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
  Future<String?> _bakeThumbnail(
    String? leadImageUrl, {
    String? noteId,
    required String altText,
  }) async {
    if (leadImageUrl == null || leadImageUrl.trim().isEmpty) return null;
    final imageUri = Uri.tryParse(leadImageUrl.trim());
    if (imageUri == null ||
        (!imageUri.isScheme('http') && !imageUri.isScheme('https'))) {
      return null;
    }

    try {
      final response = await _getWithRedirects(imageUri, _imageHeaders);
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > AttachmentService.maxFileSizeBytes) {
        return null;
      }

      final contentType =
          response.headers['content-type']?.split(';').first.trim().toLowerCase();
      if (contentType != null &&
          contentType.isNotEmpty &&
          !contentType.startsWith('image/')) {
        return null; // Not an image response.
      }

      // Re-encodes to JPEG at <=800px. Falls back to the source bytes if the
      // image cannot be decoded (never throws).
      final compressed = await _imageProcessor.process(
        bytes,
        ImageAdjustments.neutral,
        maxDimension: _thumbnailMaxDimension,
      );
      if (compressed.isEmpty) return null;

      final result = await _attachmentService.importImageFromBytes(
        compressed,
        mimeType: 'image/jpeg',
        noteId: noteId,
        preferredAltText: altText.isNotEmpty ? altText : 'Link preview',
        kind: 'linkPreview',
        skipOcr: true,
      );

      return 'qp://asset/${result.attachment.id}';
    } catch (_) {
      // Thumbnail failures must never fail the whole bake.
      return null;
    }
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

/// Riverpod provider exposing a [LinkPreviewBaker] wired to the shared
/// attachment service and the pure-Dart image processor.
final linkPreviewBakerProvider = Provider<LinkPreviewBaker>((ref) {
  return LinkPreviewBaker(
    attachmentService: ref.watch(attachmentServiceProvider),
    imageProcessor: ref.watch(imageProcessorProvider),
  );
});
