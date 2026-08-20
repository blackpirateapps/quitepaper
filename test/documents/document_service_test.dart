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
  });
}
