import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/core/web_clipper/web_image_downloader.dart';
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
  group('WebClipperService', () {
    test('clips basic article without images or snapshot', () async {
      final repository = InMemoryNotesRepository();
      final mockClient = MockClient((request) async {
        const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>How Local-First Software Works</title>
  <meta name="author" content="Jordan Key" />
  <meta name="description" content="A guide to local first apps." />
</head>
<body>
  <article>
    <h1>How Local-First Software Works</h1>
    <p>Local data is the primary copy; cloud is secondary.</p>
  </article>
</body>
</html>
''';
        return http.Response(html, 200, headers: {'content-type': 'text/html'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final service = WebClipperService(
        notesRepository: repository,
        scanner: scanner,
      );

      final scanResult = await service.scanUrl('https://example.com/local-first');
      expect(scanResult.metadata.title, 'How Local-First Software Works');

      final clipResult = await service.clipArticle(
        scanResult: scanResult,
        options: const WebClipperOptions(
          tags: ['offline', 'architecture'],
          saveHtmlSnapshot: false,
          downloadImages: false,
        ),
      );

      expect(clipResult.note.title, 'How Local-First Software Works');
      expect(clipResult.note.tags, contains('clipped'));
      expect(clipResult.note.tags, contains('example.com'));
      expect(clipResult.note.tags, contains('offline'));
      expect(clipResult.note.content, contains('title: "How Local-First Software Works"'));
      expect(clipResult.note.content, contains('Local data is the primary copy'));

      final savedNote = await repository.getNoteById(clipResult.note.id);
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'How Local-First Software Works');
    });

    test('downloads images, rewrites markdown body to qp://asset/<UUID>, and creates web snapshot', () async {
      final repository = InMemoryNotesRepository();
      final fakeAttachmentService = FakeAttachmentService();
      final fakeDocumentService = FakeDocumentService();

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.endsWith('.png') || url.endsWith('.jpg')) {
          return http.Response.bytes(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }

        const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Deep Dive into Architecture</title>
  <meta property="og:image" content="https://example.com/hero.jpg" />
  <meta name="author" content="Alice Dev" />
</head>
<body>
  <article>
    <h1>Deep Dive into Architecture</h1>
    <p>Here is an illustration:</p>
    <img src="https://example.com/diagram.png" alt="Architecture Diagram" />
    <p>And here is a secondary diagram:</p>
    <figure>
      <img src="https://example.com/database.png" alt="Database Schema" />
      <figcaption>Figure 1: Database</figcaption>
    </figure>
  </article>
</body>
</html>
''';
        return http.Response(html, 200, headers: {'content-type': 'text/html'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final imageDownloader = WebImageDownloader(
        attachmentService: fakeAttachmentService,
        httpClient: mockClient,
      );

      final service = WebClipperService(
        notesRepository: repository,
        attachmentService: fakeAttachmentService,
        documentService: fakeDocumentService,
        scanner: scanner,
        imageDownloader: imageDownloader,
      );

      final scanResult = await service.scanUrl('https://example.com/architecture');
      expect(scanResult.images.length, 3);

      final clipResult = await service.clipArticle(
        scanResult: scanResult,
        options: const WebClipperOptions(
          saveHtmlSnapshot: true,
          downloadImages: true,
        ),
      );

      final content = clipResult.note.content;

      // 1. Verify snapshot document was created and linked with qp://document/
      expect(clipResult.snapshotDocument, isNotNull);
      expect(clipResult.snapshotDocument!.source, DocumentSource.webSnapshot.identifier);
      expect(clipResult.snapshotDocument!.mimeType, 'text/html');
      expect(content, contains('qp://document/${clipResult.snapshotDocument!.id}'));
      expect(content, contains('Original Web Snapshot Attached'));

      // 2. Verify all image references are rewritten to local qp://asset/ links
      expect(content, contains('qp://asset/00000000-0000-0000-0000-00000000000'));
      expect(content, contains('![Architecture Diagram](qp://asset/'));
      expect(content, contains('![Database Schema](qp://asset/'));

      // 3. Verify zero remote image URLs remain in markdown body
      expect(content.contains('https://example.com/diagram.png'), isFalse);
      expect(content.contains('https://example.com/database.png'), isFalse);
      expect(content.contains('https://example.com/hero.jpg'), isFalse);

      // 4. Verify attachments were ingested in fakeAttachmentService
      expect(fakeAttachmentService.importedBytes.length, 3);
      expect(fakeDocumentService.createdSnapshots.length, 1);
    });

    test('deduplicates hero lead image if first image in article body is the same image', () async {
      final repository = InMemoryNotesRepository();
      final fakeAttachmentService = FakeAttachmentService();

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.endsWith('.jpg')) {
          return http.Response.bytes(
            Uint8List.fromList([255, 216, 255]),
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }

        const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Article with Duplicate Hero</title>
  <meta property="og:image" content="https://example.com/banner.jpg" />
</head>
<body>
  <article>
    <img src="https://example.com/banner.jpg" alt="Hero Banner" />
    <p>Body paragraph text.</p>
  </article>
</body>
</html>
''';
        return http.Response(html, 200, headers: {'content-type': 'text/html'});
      });

      final scanner = WebClipperScanner(httpClient: mockClient);
      final imageDownloader = WebImageDownloader(
        attachmentService: fakeAttachmentService,
        httpClient: mockClient,
      );

      final service = WebClipperService(
        notesRepository: repository,
        attachmentService: fakeAttachmentService,
        scanner: scanner,
        imageDownloader: imageDownloader,
      );

      final scanResult = await service.scanUrl('https://example.com/hero-test');
      final clipResult = await service.clipArticle(
        scanResult: scanResult,
        options: const WebClipperOptions(
          saveHtmlSnapshot: false,
          downloadImages: true,
        ),
      );

      final content = clipResult.note.content;

      // Count occurrences of qp://asset/ in content
      final matches = RegExp(r'qp:\/\/asset\/[a-zA-Z0-9_\-]+').allMatches(content);
      expect(matches.length, 1, reason: 'Hero image must appear exactly once without duplicate in body');
    });
  });
}
