import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentService Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late DocumentLocalStorage storage;
    late MockKeyManager keyManager;
    late DocumentService documentService;
    late CryptoService cryptoService;

    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample PDF binary payload'));

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_documents_');
      storage = DocumentLocalStorage(
        customDocumentsDirectory: tempDir,
        customTempDirectory: tempDir,
      );
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      documentService = DocumentService(
        database: database,
        keyManager: keyManager,
        crypto: DocumentCrypto(cryptoService: cryptoService),
        storage: storage,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates document from PDF bytes, saves to DB, encrypts, and emits markdown snippet', () async {
      final result = await documentService.createDocumentFromPdfBytes(
        pdfBytes: samplePdfBytes,
        pageCount: 3,
        title: 'Tax Document',
      );

      final doc = result.document;
      expect(doc.id, isNotEmpty);
      expect(doc.title, 'Tax Document');
      expect(doc.mimeType, 'application/pdf');
      expect(doc.pageCount, 3);
      expect(doc.byteSize, samplePdfBytes.length);
      expect(doc.sha256, DocumentCrypto.computeSha256(samplePdfBytes));
      expect(doc.isDirty, isTrue);
      expect(doc.uploadState, 'upload_pending');

      expect(result.markdownSnippet, '[Tax Document](qp://document/${doc.id})');

      // Verify file written to disk
      final hasFile = await storage.hasEncryptedFile(documentId: doc.id);
      expect(hasFile, isTrue);
    });

    test('Resolves document from local cache and disk', () async {
      final createResult = await documentService.createDocumentFromPdfBytes(
        pdfBytes: samplePdfBytes,
        pageCount: 2,
        title: 'Report',
      );

      final resolution = await documentService.resolveDocument(createResult.document.id);

      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, isNotNull);
      expect(resolution.data!.documentId, createResult.document.id);
      expect(resolution.data!.pdfBytes, samplePdfBytes);
      expect(resolution.data!.pageCount, 2);
    });

    test('Returns locked resolution when keyManager is locked and RAM cache cleared', () async {
      final createResult = await documentService.createDocumentFromPdfBytes(
        pdfBytes: samplePdfBytes,
        pageCount: 1,
        title: 'Private Note',
      );

      // Clear memory cache and lock key manager
      storage.clearDecryptedCache();
      keyManager.lock();

      final resolution = await documentService.resolveDocument(createResult.document.id);
      expect(resolution.status, ResourceStatus.locked);
    });

    test('Deletes document and invalidates cache', () async {
      final createResult = await documentService.createDocumentFromPdfBytes(
        pdfBytes: samplePdfBytes,
        pageCount: 1,
      );

      await documentService.deleteDocument(createResult.document.id, enqueueSync: false);

      final docInDb = await database.getDocument(createResult.document.id);
      expect(docInDb?.isDeleted, isTrue);

      final hasFile = await storage.hasEncryptedFile(documentId: createResult.document.id);
      expect(hasFile, isFalse);

      final resolution = await documentService.resolveDocument(createResult.document.id);
      expect(resolution.isMissing, isTrue);
    });

    test('Imports PDF file from local storage and tracks source as imported_pdf', () async {
      final dummyPdfFile = File('${tempDir.path}/Quarterly_Financial_Report.pdf');
      await dummyPdfFile.writeAsBytes(samplePdfBytes);

      final result = await documentService.importPdfFile(
        file: dummyPdfFile,
        title: 'Quarterly Financial Report',
      );

      final doc = result.document;
      expect(doc.id, isNotEmpty);
      expect(doc.title, equals('Quarterly Financial Report'));
      expect(doc.source, equals('imported_pdf'));
      expect(doc.mimeType, equals('application/pdf'));
      expect(result.markdownSnippet, equals('[Quarterly Financial Report](qp://document/${doc.id})'));

      final resolution = await documentService.resolveDocument(doc.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data?.source, equals('imported_pdf'));
    });

    test('renameDocument updates document title and replaces markdown link in note content', () async {
      const noteId = 'note-with-doc-123';
      const docTitle = 'Initial Invoice';
      const newDocTitle = 'Renamed Invoice 2026';

      final createResult = await documentService.createDocumentFromPdfBytes(
        pdfBytes: samplePdfBytes,
        pageCount: 1,
        title: docTitle,
        noteId: noteId,
      );
      final docId = createResult.document.id;

      // Create note containing the document link
      await database.saveNote(
        id: noteId,
        title: 'Expenses Note',
        content: '# Expenses\n\nSee attachment: [$docTitle](qp://document/$docId)\n\nEnd of note.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Rename the document
      await documentService.renameDocument(
        documentId: docId,
        newTitle: newDocTitle,
        noteId: noteId,
      );

      // 1. Verify document entity updated
      final updatedDoc = await database.getDocument(docId);
      expect(updatedDoc?.title, equals(newDocTitle));

      // 2. Verify note content updated with new title
      final updatedNote = await database.getNoteWithTags(noteId);
      expect(updatedNote?.note.content, contains('[$newDocTitle](qp://document/$docId)'));
      expect(updatedNote?.note.content, isNot(contains('[$docTitle]')));
    });

    test('createWebSnapshotDocument creates document with web_snapshot source and text/html MIME type', () async {
      final htmlBytes = Uint8List.fromList(utf8.encode('<!DOCTYPE html><html><body><h1>Offline Snapshot</h1></body></html>'));
      final result = await documentService.createWebSnapshotDocument(
        htmlBytes: htmlBytes,
        title: 'Article (Web Snapshot)',
      );

      final doc = result.document;
      expect(doc.id, isNotEmpty);
      expect(doc.title, 'Article (Web Snapshot)');
      expect(doc.source, 'web_snapshot');
      expect(doc.mimeType, 'text/html');
      expect(doc.pageCount, 1);
      expect(doc.byteSize, htmlBytes.length);
      expect(result.markdownSnippet, '[Article (Web Snapshot)](qp://document/${doc.id})');

      final resolution = await documentService.resolveDocument(doc.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data!.source, 'web_snapshot');
      expect(resolution.data!.pdfBytes, htmlBytes);
    });

    test('isHtmlDocumentPayload accurately identifies HTML payloads by content, source, and title', () {
      final htmlBytes1 = Uint8List.fromList(utf8.encode('<!DOCTYPE html><html><body>Hello</body></html>'));
      final htmlBytes2 = Uint8List.fromList(utf8.encode('<html lang="en"><head></head><body>Hello</body></html>'));
      final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 binary data'));

      expect(DocumentService.isHtmlDocumentPayload(bytes: htmlBytes1), isTrue);
      expect(DocumentService.isHtmlDocumentPayload(bytes: htmlBytes2), isTrue);
      expect(DocumentService.isHtmlDocumentPayload(bytes: pdfBytes), isFalse);
      expect(DocumentService.isHtmlDocumentPayload(bytes: pdfBytes, source: 'web_snapshot'), isTrue);
      expect(DocumentService.isHtmlDocumentPayload(bytes: pdfBytes, mimeType: 'text/html'), isTrue);
      expect(DocumentService.isHtmlDocumentPayload(bytes: pdfBytes, title: 'My Page (Web Snapshot)'), isTrue);
    });
  });
}
