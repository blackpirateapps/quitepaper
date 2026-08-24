import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/ocr/document_processing_service.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
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
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdfPageRenderer implements PdfPageRenderer {
  @override
  Future<List<RenderedPage>> renderPages(Uint8List pdfBytes, {List<int>? pageIndices, double dpi = 150.0}) async {
    return [
      RenderedPage(
        pageNumber: 1,
        imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        width: 800,
        height: 1100,
      ),
    ];
  }

  @override
  Future<RenderedPage?> renderSinglePage(Uint8List pdfBytes, int pageIndex, {double dpi = 150.0}) async {
    final list = await renderPages(pdfBytes);
    return list.first;
  }
}

class FakeOcrService implements OcrService {
  FakeOcrService({this.mockText = 'Recognized on-device scan text'});
  final String mockText;

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    return OcrPage(
      pageNumber: pageNumber,
      plainText: mockText,
      width: 800,
      height: 1100,
      source: OcrSource.onDeviceOcr,
    );
  }

  @override
  Future<OcrDocument> recognizeDocument(
    Uint8List pdfBytes, {
    required String documentId,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    return OcrDocument(
      documentId: documentId,
      processedAt: DateTime.now(),
      pages: [
        await recognizePage(Uint8List(0), pageNumber: 1),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentProcessingService Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late DocumentProcessingService processingService;
    late CryptoService cryptoService;

    const testDocId = '99999999-8888-7777-6666-555555555555';
    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample payload'));

    setUp(() async {
      database = AppDatabase.memory();
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      await database.saveDocument(
        id: testDocId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Imported Document',
        source: DocumentSource.importedPdf.identifier,
        ocrState: OcrProcessingState.queued.identifier,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('Runs on-device OCR for imported PDF, encrypts with Master Key, and updates state to available', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(mockText: 'Imported PDF OCR Recognized Text'),
      );

      await processingService.processDocument(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.importedPdf,
      );

      final doc = await database.getDocument(testDocId);
      expect(doc?.ocrState, equals(OcrProcessingState.available.identifier));

      final ocrPages = await database.getDocumentOcrPages(testDocId);
      expect(ocrPages.length, equals(1));
      expect(ocrPages.first.pageNumber, equals(1));

      final decryptedDoc = await processingService.getDecryptedOcrDocument(testDocId);
      expect(decryptedDoc, isNotNull);
      expect(decryptedDoc?.fullPlainText, contains('Imported PDF OCR Recognized Text'));
      expect(decryptedDoc?.pages.first.source, equals(OcrSource.onDeviceOcr));
    });

    test('Runs on-device OCR for scanner document, encrypts with Master Key, and updates state to available', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(mockText: 'Scanned Document OCR Recognized Text'),
      );

      await processingService.processDocument(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.scanner,
      );

      final doc = await database.getDocument(testDocId);
      expect(doc?.ocrState, equals(OcrProcessingState.available.identifier));

      final decryptedDoc = await processingService.getDecryptedOcrDocument(testDocId);
      expect(decryptedDoc, isNotNull);
      expect(decryptedDoc?.fullPlainText, contains('Scanned Document OCR Recognized Text'));
      expect(decryptedDoc?.pages.first.source, equals(OcrSource.onDeviceOcr));
    });

    test('retryOcr and regenerateOcr atomically re-process and replace OCR dataset', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(mockText: 'Initial OCR Text'),
      );

      await processingService.processDocument(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.importedPdf,
      );

      final doc1 = await processingService.getDecryptedOcrDocument(testDocId);
      expect(doc1?.fullPlainText, contains('Initial OCR Text'));

      // Now regenerate with updated OCR service
      final updatedService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(mockText: 'Updated Regenerated Text'),
      );

      await updatedService.regenerateOcr(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.importedPdf,
      );

      final doc2 = await updatedService.getDecryptedOcrDocument(testDocId);
      expect(doc2?.fullPlainText, contains('Updated Regenerated Text'));
      expect(doc2?.pages.length, equals(1));
    });

    test('getDocumentOcrMetadata, getDecryptedOcrPage, and getDecryptedOcrFormattedCopyText support lazy single-page access', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(mockText: 'Page One Content'),
      );

      await processingService.processDocument(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.importedPdf,
      );

      // Verify metadata query without full payload decryption
      final meta = await processingService.getDocumentOcrMetadata(testDocId);
      expect(meta, isNotNull);
      expect(meta?.pageCount, equals(1));
      expect(meta?.language, equals(OcrLanguage.english));
      expect(meta?.pageNumbers, equals([1]));

      // Verify single page decryption
      final page1 = await processingService.getDecryptedOcrPage(testDocId, 1);
      expect(page1, isNotNull);
      expect(page1?.pageNumber, equals(1));
      expect(page1?.plainText, equals('Page One Content'));

      // Non-existent page returns null
      final page99 = await processingService.getDecryptedOcrPage(testDocId, 99);
      expect(page99, isNull);

      // Verify streaming formatted copy text
      final copyText = await processingService.getDecryptedOcrFormattedCopyText(testDocId);
      expect(copyText, contains('Page 1'));
      expect(copyText, contains('Page One Content'));
    });
  });
}
