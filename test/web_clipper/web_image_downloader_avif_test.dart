import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_image_downloader.dart';

class MockAttachmentService implements AttachmentService {
  int _counter = 0;
  final List<({String mimeType, Uint8List bytes, String altText})> imports = [];

  @override
  Future<({AttachmentEntity attachment, String markdownSnippet})> importImageFromBytes(
    Uint8List bytes, {
    required String mimeType,
    String fileName = 'image.png',
    String? noteId,
    String preferredAltText = 'Image',
  }) async {
    _counter++;
    final assetId = '11111111-2222-3333-4444-55555555555$_counter';
    imports.add((mimeType: mimeType, bytes: bytes, altText: preferredAltText));

    final entity = AttachmentEntity(
      id: assetId,
      noteId: noteId,
      fileName: fileName,
      kind: 'image',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: mimeType,
      byteSize: bytes.length,
      sha256: 'fake_hash',
      encryptionKeyVersion: 1,
      isDirty: false,
      isDeleted: false,
      serverRevision: 0,
      uploadState: 'available',
      localPath: '/fake/$assetId',
      ocrState: 'available',
      ocrLanguage: 'en',
    );

    return (
      attachment: entity,
      markdownSnippet: '![$preferredAltText](qp://asset/$assetId)',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WebImageDownloader AVIF & Anti-Hotlinking', () {
    test('sends browser headers and Referer when downloading AVIF images', () async {
      final fakeAttachmentService = MockAttachmentService();
      final capturedHeaders = <String, String>{};

      // Mock HTTP client that verifies request headers
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('.avif')) {
          capturedHeaders.addAll(request.headers);
          // Return sample AVIF payload (> 400 bytes)
          final sampleAvifBytes = Uint8List(1200);
          return http.Response.bytes(
            sampleAvifBytes,
            200,
            headers: {'content-type': 'image/avif'},
          );
        }
        return http.Response('Not found', 404);
      });

      final downloader = WebImageDownloader(
        attachmentService: fakeAttachmentService,
        httpClient: mockClient,
      );

      final candidates = [
        const ClippedImageCandidate(
          rawUrl: 'https://cdn.example.com/images/architecture.avif?token=xyz',
          resolvedUrl: 'https://cdn.example.com/images/architecture.avif?token=xyz',
          altText: 'System Diagram',
          isSelected: true,
          estimatedSizeBytes: 1200,
        ),
      ];

      final results = await downloader.downloadAndEncryptImages(
        candidates: candidates,
        noteId: 'note-123',
      );

      // Verify headers sent
      expect(capturedHeaders['Referer'], 'https://cdn.example.com/');
      expect(capturedHeaders['User-Agent'], contains('Mozilla/5.0'));
      expect(capturedHeaders['Accept'], contains('image/avif'));
      expect(capturedHeaders['Sec-Fetch-Dest'], 'image');

      // Verify attachment was imported with image/avif mime type
      expect(fakeAttachmentService.imports.length, 1);
      expect(fakeAttachmentService.imports.first.mimeType, 'image/avif');

      // Verify snippet mappings for both raw URL and query-stripped URL
      expect(results, contains('https://cdn.example.com/images/architecture.avif?token=xyz'));
      expect(results, contains('https://cdn.example.com/images/architecture.avif'));
      expect(results.values.first, contains('qp://asset/11111111-2222-3333-4444-555555555551'));
    });
  });
}
