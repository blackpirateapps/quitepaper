import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/core/web_clipper/web_image_downloader.dart';
import 'package:quitepaper/core/web_clipper/web_snapshot_generator.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

class InMemoryNotesRepository implements NotesRepository {
  final Map<String, Note> _notes = {};

  @override
  Future<void> saveNote(Note note) async {
    _notes[note.id] = note;
  }

  @override
  Future<Note?> getNoteById(String id) async => _notes[id];

  @override
  Stream<List<Note>> watchNotes({
    bool isArchived = false,
    bool isTrashed = false,
    bool? isPinned,
    String? filterTag,
    String? searchQuery,
  }) {
    return Stream.value(_notes.values.toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAttachmentService implements AttachmentService {
  int _importCounter = 0;
  final Map<String, Uint8List> importedBytes = {};

  @override
  Future<({AttachmentEntity attachment, String markdownSnippet})> importImageFromBytes(
    Uint8List bytes, {
    required String mimeType,
    String? noteId,
    String preferredAltText = 'Image',
  }) async {
    _importCounter++;
    final assetId = '00000000-0000-0000-0000-00000000000$_importCounter';
    importedBytes[assetId] = bytes;

    final entity = AttachmentEntity(
      id: assetId,
      noteId: noteId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: mimeType,
      byteSize: bytes.length,
      sha256: 'hash-$assetId',
      encryptionKeyVersion: 1,
      isDirty: true,
      isDeleted: false,
      serverRevision: 0,
      uploadState: 'local_only',
      localPath: '/vault/$assetId.qpa',
      ocrState: 'queued',
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

class FakeDocumentService implements DocumentService {
  int _docCounter = 0;
  final Map<String, Uint8List> createdSnapshots = {};

  @override
  Future<({DocumentEntity document, String markdownSnippet})> createWebSnapshotDocument({
    required Uint8List htmlBytes,
    String? noteId,
    String title = 'Web Snapshot',
  }) async {
    _docCounter++;
    final docId = '11111111-1111-1111-1111-11111111111$_docCounter';
    createdSnapshots[docId] = htmlBytes;

    final entity = DocumentEntity(
      id: docId,
      noteId: noteId,
      title: title,
      source: DocumentSource.webSnapshot.identifier,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: 'text/html',
      byteSize: htmlBytes.length,
      pageCount: 1,
      sha256: 'sha-$docId',
      encryptionKeyVersion: 1,
      isDirty: true,
      isDeleted: false,
      serverRevision: 0,
      uploadState: 'local_only',
      localPath: '/vault/$docId.qpd',
      ocrState: 'not_requested',
      ocrLanguage: 'en',
    );

    return (
      document: entity,
      markdownSnippet: '[$title](qp://document/$docId)',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Browser Acquisition Service Integration', () {
    test('scans browser payload with full article HTML and saves complete note', () async {
      final repository = InMemoryNotesRepository();
      final fakeAttachmentService = FakeAttachmentService();
      final fakeDocumentService = FakeDocumentService();

      final mockClient = MockClient((request) async {
        if (request.url.toString().endsWith('.png')) {
          return http.Response.bytes(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response('', 200);
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final imageDownloader = WebImageDownloader(
        attachmentService: fakeAttachmentService,
        httpClient: mockClient,
      );
      final snapshotGenerator = WebSnapshotGenerator(httpClient: mockClient);

      final service = WebClipperService(
        notesRepository: repository,
        attachmentService: fakeAttachmentService,
        documentService: fakeDocumentService,
        scanner: scanner,
        imageDownloader: imageDownloader,
        snapshotGenerator: snapshotGenerator,
      );

      final payload = WebCapturePayload(
        requestedUrl: 'https://browser-test.com/post',
        finalUrl: 'https://browser-test.com/post/final',
        html: '''
<!DOCTYPE html>
<html>
<head>
  <title>Browser Captured Article — Engineering</title>
  <meta name="author" content="Browser User">
  <meta name="description" content="Captured directly from in-app browser session.">
</head>
<body>
  <article>
    <h1>Browser Captured Article</h1>
    <p>This article was captured after user authentication and normal interaction.</p>
    <img src="https://browser-test.com/diagram.png" alt="Architecture Diagram">
  </article>
</body>
</html>
''',
        acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
      );

      final scanResult = await service.scanPayload(payload);

      expect(scanResult.metadata.title, 'Browser Captured Article');
      expect(scanResult.metadata.author, 'Browser User');
      expect(scanResult.metadata.domain, 'browser-test.com');
      expect(scanResult.images.length, 1);
      expect(scanResult.acquisitionMethod, WebAcquisitionMethod.inAppBrowser);

      final clipResult = await service.clipArticle(
        scanResult: scanResult,
        options: const WebClipperOptions(
          saveHtmlSnapshot: true,
          downloadImages: true,
          tags: ['research', 'web'],
        ),
      );

      final note = clipResult.note;
      expect(note.title, 'Browser Captured Article');
      expect(note.tags, contains('clipped'));
      expect(note.tags, contains('browser-test.com'));
      expect(note.tags, contains('research'));
      expect(note.tags, contains('web'));
      expect(note.content, contains('qp://asset/'));
      expect(note.content, contains('qp://document/'));
      expect(clipResult.snapshotDocument, isNotNull);

      // Verify saved in repository
      final saved = await repository.getNoteById(note.id);
      expect(saved, isNotNull);
      expect(saved!.content, equals(note.content));
    });

    test('falls back to sanitized page content when no article container is detected', () async {
      final mockClient = MockClient((request) async => http.Response('', 200));
      final scanner = WebClipperScanner(httpClient: mockClient);

      final payload = WebCapturePayload(
        requestedUrl: 'https://dashboard.io/metrics',
        finalUrl: 'https://dashboard.io/metrics',
        html: '''
<!DOCTYPE html>
<html>
<head><title>System Metrics Dashboard</title></head>
<body>
  <div class="non-standard-container">
    <h2>Active Clusters</h2>
    <p>Cluster 1: Healthy. Latency 12ms.</p>
    <p>Cluster 2: Healthy. Latency 15ms.</p>
  </div>
</body>
</html>
''',
        pageTitle: 'System Metrics Dashboard',
        acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
      );

      final scanResult = await scanner.scanPayload(payload, allowFallback: true);

      expect(scanResult.isPageContentFallback, isTrue);
      expect(scanResult.metadata.title, 'System Metrics Dashboard');
      expect(scanResult.markdownBody, contains('Active Clusters'));
      expect(scanResult.markdownBody, contains('Cluster 1: Healthy'));
    });
  });
}
