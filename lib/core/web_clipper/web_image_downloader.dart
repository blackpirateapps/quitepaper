import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../attachments/attachment_service.dart';
import 'clipped_image_filter.dart';
import 'web_clipper_models.dart';

/// Concurrently downloads article images, encrypts them client-side using [AttachmentService],
/// and rewrites image references to canonical `qp://asset/<UUID>` URIs.
class WebImageDownloader {
  WebImageDownloader({
    required this.attachmentService,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final AttachmentService attachmentService;
  final http.Client _httpClient;

  /// Concurrently downloads all [candidates], encrypts them into the local attachment vault,
  /// and returns a map from original image URL to canonical `![alt](qp://asset/<UUID>)` markdown snippet.
  Future<Map<String, String>> downloadAndEncryptImages({
    required List<ClippedImageCandidate> candidates,
    required String noteId,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, String>{};
    final selectedCandidates = candidates.where((c) => c.isSelected).toList();
    final listToDownload = selectedCandidates.isNotEmpty ? selectedCandidates : candidates;
    if (listToDownload.isEmpty) {
      return results;
    }

    var completedCount = 0;
    const maxConcurrency = 4;
    final queue = List<ClippedImageCandidate>.from(listToDownload);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        try {
          var uri = Uri.tryParse(item.resolvedUrl.trim());
          if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
            try {
              uri = Uri.tryParse(Uri.encodeFull(item.resolvedUrl.trim()));
            } catch (_) {}
          }

          if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
            continue;
          }

          final response = await _httpClient.get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
              'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              if (uri.hasAuthority) 'Referer': '${uri.scheme}://${uri.authority}/',
              'Sec-Fetch-Dest': 'image',
              'Sec-Fetch-Mode': 'no-cors',
              'Sec-Fetch-Site': 'cross-site',
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
            final bytes = response.bodyBytes;
            if (bytes.length > AttachmentService.maxFileSizeBytes) {
              debugPrint('Image ${item.resolvedUrl} exceeds max size limit, skipping');
              continue;
            }

            // Verify content is a meaningful image and not an empty spacer or icon
            if (!ClippedImageFilter.isMeaningfulImageBytes(bytes)) {
              debugPrint('Image ${item.resolvedUrl} is a tiny icon or tracking spacer (<400B or <32x32), skipping');
              continue;
            }

            final mimeType = _resolveMimeType(
              response.headers['content-type'],
              item.resolvedUrl,
            );

            final importResult = await attachmentService.importImageFromBytes(
              bytes,
              mimeType: mimeType,
              noteId: noteId,
              preferredAltText: item.altText.isNotEmpty ? item.altText : 'Image',
            );

            final snippet = importResult.markdownSnippet;
            _registerSnippet(results, item.rawUrl, snippet);
            _registerSnippet(results, item.resolvedUrl, snippet);
          }
        } catch (e) {
          debugPrint('Failed to download image ${item.resolvedUrl}: $e');
        } finally {
          completedCount++;
          onProgress?.call(completedCount, listToDownload.length);
        }
      }
    }

    final workers = List.generate(
      maxConcurrency.clamp(1, listToDownload.length),
      (_) => worker(),
    );

    await Future.wait(workers);
    return results;
  }

  String _resolveMimeType(String? contentType, String url) {
    if (contentType != null && contentType.isNotEmpty) {
      final clean = contentType.split(';').first.trim().toLowerCase();
      if (AttachmentService.supportedMimeTypes.contains(clean)) {
        return clean;
      }
    }

    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    if (lower.contains('.avif')) return 'image/avif';
    if (lower.contains('.svg')) return 'image/svg+xml';
    if (lower.contains('.gif')) return 'image/gif';
    if (lower.contains('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  void _registerSnippet(Map<String, String> map, String url, String snippet) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    map[trimmed] = snippet;
    if (trimmed.contains('?')) {
      final base = trimmed.split('?').first;
      if (base.isNotEmpty) {
        map[base] = snippet;
      }
    }
    try {
      final decoded = Uri.decodeFull(trimmed);
      if (decoded != trimmed) {
        map[decoded] = snippet;
        if (decoded.contains('?')) {
          final base = decoded.split('?').first;
          if (base.isNotEmpty) {
            map[base] = snippet;
          }
        }
      }
      final encoded = Uri.encodeFull(trimmed);
      if (encoded != trimmed) {
        map[encoded] = snippet;
      }
    } catch (_) {}
  }
}
