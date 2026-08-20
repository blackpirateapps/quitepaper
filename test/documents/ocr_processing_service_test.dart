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
import 'package:quitepaper/core/pdf/pdf_text_extractor.dart';

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

class FakePdfTextExtractor implements PdfTextExtractor {
  FakePdfTextExtractor({required this.hasText, this.mockText = 'Sample PDF Text'});
  final bool hasText;
  final String mockText;

  @override
  Future<PdfTextExtractionResult> extractText(Uint8List pdfBytes) async {
    if (!hasText) {
      return const PdfTextExtractionResult(hasUsableText: false);
    }
    return PdfTextExtractionResult(
      hasUsableText: true,
      pages: [
        OcrPage(
          pageNumber: 1,
          plainText: mockText,
          width: 800,
          height: 1100,
          source: OcrSource.embeddedPdfText,
        ),
      ],
      extractedText: mockText,
    );
  }
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
  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    return OcrPage(
      pageNumber: pageNumber,
      plainText: 'Recognized on-device scan text',
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

    test('Extracts text layer for imported PDF, encrypts with Master Key, and updates state to available', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        textExtractor: FakePdfTextExtractor(hasText: true, mockText: 'Embedded PDF Text Content'),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(),
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
      expect(decryptedDoc?.fullPlainText, contains('Embedded PDF Text Content'));
      expect(decryptedDoc?.pages.first.source, equals(OcrSource.embeddedPdfText));
    });

    test('Falls back to on-device OCR when PDF text layer is absent', () async {
      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
        textExtractor: FakePdfTextExtractor(hasText: false),
        pageRenderer: FakePdfPageRenderer(),
        ocrService: FakeOcrService(),
      );

      await processingService.processDocument(
        documentId: testDocId,
        pdfBytes: samplePdfBytes,
        source: DocumentSource.importedPdf,
      );

      final doc = await database.getDocument(testDocId);
      expect(doc?.ocrState, equals(OcrProcessingState.available.identifier));

      final decryptedDoc = await processingService.getDecryptedOcrDocument(testDocId);
      expect(decryptedDoc, isNotNull);
      expect(decryptedDoc?.fullPlainText, equals('Recognized on-device scan text'));
      expect(decryptedDoc?.pages.first.source, equals(OcrSource.onDeviceOcr));
    });
  });
}
