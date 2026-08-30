import 'dart:io';
import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/attachments/cloudinary_client.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/maintenance/attachment_maintenance_service.dart';
import 'package:quitepaper/core/maintenance/maintenance_models.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_search_service.dart';
import 'package:quitepaper/core/ocr/ocr_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCloudinaryClient implements CloudinaryClient {
  Uint8List? downloadBytesResponse;
  final List<String> downloadedUrls = [];
  bool throwOnDownload = false;

  @override
  Future<Uint8List> downloadEncryptedBytes({required String cloudUrl}) async {
    if (throwOnDownload) {
      throw const CloudinaryException('Download failed: 404 Not Found', statusCode: 404);
    }
    downloadedUrls.add(cloudUrl);
    return downloadBytesResponse ?? Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOcrService implements OcrService {
  MockOcrService({required this.mockPage});

  final OcrPage mockPage;
  int recognizePageCalls = 0;

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    recognizePageCalls++;
    return mockPage;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPdfPageRenderer implements PdfPageRenderer {
  MockPdfPageRenderer({required this.renderedPages});

  final List<RenderedPage> renderedPages;

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    return renderedPages;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentMaintenanceService Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late AttachmentLocalStorage attachmentStorage;
    late DocumentLocalStorage documentStorage;
    late MockKeyManager keyManager;
    late MockCloudinaryClient cloudinaryClient;
    late AttachmentCrypto attachmentCrypto;
    late DocumentCrypto documentCrypto;
    late OcrCrypto ocrCrypto;
    late MockOcrService ocrService;
    late MockPdfPageRenderer pageRenderer;
    late OcrSearchService ocrSearchService;
    late AttachmentMaintenanceService maintenanceService;
    late Uint8List masterKey;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('maintenance_test_');
      final attDir = Directory('${tempDir.path}/attachments');
      final docDir = Directory('${tempDir.path}/documents');
      await attDir.create(recursive: true);
      await docDir.create(recursive: true);

      attachmentStorage = AttachmentLocalStorage(customBaseDirectory: attDir);
      documentStorage = DocumentLocalStorage(customDocumentsDirectory: docDir);

      final cryptoService = DefaultCryptoService();
      masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      cloudinaryClient = MockCloudinaryClient();
      attachmentCrypto = AttachmentCrypto(cryptoService: cryptoService);
      documentCrypto = DocumentCrypto(cryptoService: cryptoService);
      ocrCrypto = OcrCrypto(cryptoService: cryptoService);

      final testImage = img.Image(width: 50, height: 50);
      final validPngBytes = Uint8List.fromList(img.encodePng(testImage));

      final mockPage = OcrPage(
        pageNumber: 1,
        plainText: 'Recognized Text Content',
        width: 50,
        height: 50,
        blocks: [],
      );
      ocrService = MockOcrService(mockPage: mockPage);

      pageRenderer = MockPdfPageRenderer(renderedPages: [
        RenderedPage(
          pageNumber: 1,
          imageBytes: validPngBytes,
          width: 50,
          height: 50,
        ),
      ]);

      ocrSearchService = OcrSearchService(database: database, keyManager: keyManager);

      maintenanceService = AttachmentMaintenanceService(
        database: database,
        keyManager: keyManager,
        attachmentStorage: attachmentStorage,
        documentStorage: documentStorage,
        cloudinaryClient: cloudinaryClient,
        attachmentCrypto: attachmentCrypto,
        documentCrypto: documentCrypto,
        ocrCrypto: ocrCrypto,
        ocrService: ocrService,
        pageRenderer: pageRenderer,
        ocrSearchService: ocrSearchService,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloadAllAttachments returns completed with 0 items when no remote files need download', () async {
      final progressList = <MaintenanceProgress>[];
      final result = await maintenanceService.downloadAllAttachments(
        onProgress: progressList.add,
      );

      expect(result.phase, MaintenancePhase.completed);
      expect(result.totalItems, 0);
      expect(result.completedItems, 0);
      expect(cloudinaryClient.downloadedUrls, isEmpty);
    });

    test('downloadAllAttachments downloads missing attachments and documents from cloud', () async {
      // 1. Prepare dummy encrypted bytes
      final dummyBytes = Uint8List.fromList([10, 20, 30, 40]);
      cloudinaryClient.downloadBytesResponse = dummyBytes;

      // 2. Save active attachment with cloudUrl but missing localPath
      await database.saveAttachment(
        id: 'att-1',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileName: 'photo.jpg',
        kind: 'image',
        mimeType: 'image/jpeg',
        cloudUrl: 'https://cloudinary.com/test-att-1',
        localPath: null,
      );

      // 3. Save active document with cloudUrl but missing localPath
      await database.saveDocument(
        id: 'doc-1',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'contract.pdf',
        mimeType: 'application/pdf',
        cloudUrl: 'https://cloudinary.com/test-doc-1',
        localPath: null,
      );

      final progressList = <MaintenanceProgress>[];
      final result = await maintenanceService.downloadAllAttachments(
        onProgress: progressList.add,
      );

      expect(result.phase, MaintenancePhase.completed);
      expect(result.totalItems, 2);
      expect(result.completedItems, 2);
      expect(result.failedItems, 0);
      expect(cloudinaryClient.downloadedUrls, [
        'https://cloudinary.com/test-att-1',
        'https://cloudinary.com/test-doc-1',
      ]);

      // Check database updated with valid local paths
      final updatedAtt = await database.getAttachment('att-1');
      expect(updatedAtt?.localPath, isNotNull);
      expect(await File(updatedAtt!.localPath!).exists(), isTrue);

      final updatedDoc = await database.getDocument('doc-1');
      expect(updatedDoc?.localPath, isNotNull);
      expect(await File(updatedDoc!.localPath!).exists(), isTrue);
    });

    test('downloadAllAttachments handles individual download failures without crashing', () async {
      await database.saveAttachment(
        id: 'att-fail',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileName: 'broken.png',
        cloudUrl: 'https://cloudinary.com/broken',
      );

      cloudinaryClient.throwOnDownload = true;

      final result = await maintenanceService.downloadAllAttachments();
      expect(result.phase, MaintenancePhase.completed);
      expect(result.totalItems, 1);
      expect(result.completedItems, 0);
      expect(result.failedItems, 1);
      expect(result.errorMessages, isNotEmpty);
    });

    test('downloadAllAttachments cancels cooperatively when token is triggered', () async {
      await database.saveAttachment(
        id: 'att-1',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileName: 'photo1.jpg',
        cloudUrl: 'https://cloudinary.com/photo1',
      );

      final cancelToken = MaintenanceCancellationToken();
      cancelToken.cancel(); // Cancel before start

      final result = await maintenanceService.downloadAllAttachments(
        cancelToken: cancelToken,
      );

      expect(result.phase, MaintenancePhase.cancelled);
      expect(cloudinaryClient.downloadedUrls, isEmpty);
    });

    test('rerunOcrForAll fails when keyManager is locked', () async {
      keyManager.isUnlocked = false;

      expect(
        () => maintenanceService.rerunOcrForAll(),
        throwsA(isA<StateError>()),
      );
    });

    test('rerunOcrForAll processes image attachments and PDF documents and updates OCR cache', () async {
      // 1. Create and encrypt a valid test image
      final testImage = img.Image(width: 20, height: 20);
      final rawImageBytes = Uint8List.fromList(img.encodePng(testImage));

      final encryptedImage = await attachmentCrypto.encryptAttachment(
        plaintextBytes: rawImageBytes,
        masterKeyBytes: masterKey,
        attachmentId: 'att-ocr-1',
      );

      final attPath = await attachmentStorage.saveEncryptedBytes(
        attachmentId: 'att-ocr-1',
        encryptedBytes: encryptedImage,
      );

      await database.saveAttachment(
        id: 'att-ocr-1',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileName: 'receipt.png',
        kind: 'image',
        mimeType: 'image/png',
        localPath: attPath,
      );

      // 2. Create and encrypt a valid test document
      final rawPdfBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encryptedPdf = await documentCrypto.encryptDocument(
        plaintextBytes: rawPdfBytes,
        masterKeyBytes: masterKey,
        documentId: 'doc-ocr-1',
      );

      final docPath = await documentStorage.saveEncryptedBytes(
        documentId: 'doc-ocr-1',
        encryptedBytes: encryptedPdf,
      );

      await database.saveDocument(
        id: 'doc-ocr-1',
        noteId: 'note-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'statement.pdf',
        mimeType: 'application/pdf',
        source: 'scanner',
        localPath: docPath,
      );

      final progressList = <MaintenanceProgress>[];
      final result = await maintenanceService.rerunOcrForAll(
        onProgress: progressList.add,
      );

      expect(result.phase, MaintenancePhase.completed);
      expect(result.totalItems, 2);
      expect(result.completedItems, 2);
      expect(result.failedItems, 0);

      // Verify attachment OCR records saved and state available
      final att = await database.getAttachment('att-ocr-1');
      expect(att?.ocrState, 'available');
      final attOcrPages = await database.getAttachmentOcrPages('att-ocr-1');
      expect(attOcrPages.length, 1);

      // Verify document OCR records saved and state available
      final doc = await database.getDocument('doc-ocr-1');
      expect(doc?.ocrState, 'available');
      final docOcrPages = await database.getDocumentOcrPages('doc-ocr-1');
      expect(docOcrPages.length, 1);
    });

    test('rebuildSearchIndex clears and rebuilds FTS5 indexes and invalidates OCR cache', () async {
      await database.saveNote(
        id: 'note-search-1',
        title: 'Project Roadmap',
        content: 'Discussing the 2026 delivery targets.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await maintenanceService.rebuildSearchIndex();

      // Search prefix should match note
      final results = await database.customSelect(
        'SELECT note_id FROM note_search_prefix WHERE note_search_prefix MATCH ?;',
        variables: [Variable.withString('Roadmap*')],
        readsFrom: {},
      ).get();
      expect(results, isNotEmpty);
      expect(results.first.data['note_id'], 'note-search-1');
    });
  });
}
