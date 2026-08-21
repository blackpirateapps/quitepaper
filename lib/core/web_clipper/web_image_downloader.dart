import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../attachments/attachment_service.dart';
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
    if (selectedCandidates.isEmpty) {
      return results;
    }

    var completedCount = 0;
    const maxConcurrency = 4;
    final queue = List<ClippedImageCandidate>.from(selectedCandidates);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        try {
          final uri = Uri.tryParse(item.resolvedUrl);
          if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
            continue;
          }

          final response = await _httpClient.get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 QuietPaper/1.5',
              'Accept': 'image/webp,image/png,image/jpeg,image/*;q=0.8',
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
            final bytes = response.bodyBytes;
            if (bytes.length > AttachmentService.maxFileSizeBytes) {
              debugPrint('Image ${item.resolvedUrl} exceeds max size limit, skipping');
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

            results[item.rawUrl] = importResult.markdownSnippet;
            results[item.resolvedUrl] = importResult.markdownSnippet;
          }
        } catch (e) {
          debugPrint('Failed to download image ${item.resolvedUrl}: $e');
        } finally {
          completedCount++;
          onProgress?.call(completedCount, selectedCandidates.length);
        }
      }
    }

    final workers = List.generate(
      maxConcurrency.clamp(1, selectedCandidates.length),
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
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
