import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_processing_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/ocr/document_processing_service.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey});
  final Uint8List masterKey;

  @override
  bool get isUnlocked => true;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() => masterKey;

  @override
  Future<WrappedMasterKeyData?> getStoredWrappedKeyData() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CountingOcrService implements OcrService {
  int recognizeDocumentCalls = 0;
  int recognizePageCalls = 0;

  @override
  Future<OcrDocument> recognizeDocument(
    Uint8List pdfBytes, {
    required String documentId,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    recognizeDocumentCalls++;
    return OcrDocument(
      documentId: documentId,
      processedAt: DateTime.now(),
      pages: const [
        OcrPage(
          pageNumber: 1,
          plainText: 'Recognized document text',
          width: 600,
          height: 800,
        ),
      ],
    );
  }

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    recognizePageCalls++;
    return OcrPage(
      pageNumber: pageNumber,
      plainText: 'Recognized image text',
      width: 400,
      height: 400,
    );
  }
}

class MockPdfPageRenderer implements PdfPageRenderer {
  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    return RenderedPage(
      pageNumber: pageIndex + 1,
      imageBytes: Uint8List(10),
      width: 100,
      height: 100,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockKeyManager keyManager;
  late CountingOcrService ocrService;
  late DocumentProcessingService docService;
  late AttachmentProcessingService attService;
  late Uint8List masterKey;

  setUp(() {
    db = AppDatabase.memory();
    masterKey = Uint8List.fromList(List.generate(32, (i) => i));
    keyManager = MockKeyManager(masterKey: masterKey);
    ocrService = CountingOcrService();
    docService = DocumentProcessingService(
      database: db,
      keyManager: keyManager,
      ocrService: ocrService,
      pageRenderer: MockPdfPageRenderer(),
    );
    attService = AttachmentProcessingService(
      database: db,
      keyManager: keyManager,
      ocrService: ocrService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('OCR Manual-Only Policy Tests', () {
    test('processDocument skips recognition when OCR pages exist and force is false', () async {
      const docId = 'doc-test-1';
      final dummyPdf = Uint8List.fromList([1, 2, 3, 4]);

      // Seed existing OCR page row
      final ocrCrypto = OcrCrypto();
      final pageDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Existing synced OCR text',
            width: 100,
            height: 100,
          ),
        ],
      );
      final encBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: pageDoc,
        masterKeyBytes: masterKey,
      );
      await db.saveDocumentOcrPage(
        documentId: docId,
        pageNumber: 1,
        encryptedPayload: base64Encode(encBytes),
        processedAt: DateTime.now(),
        isDirty: false,
      );

      // Call processDocument without force (e.g. automatic initial scan call)
      await docService.processDocument(
        documentId: docId,
        pdfBytes: dummyPdf,
        force: false,
      );

      expect(ocrService.recognizeDocumentCalls, equals(0));

      // Call processDocument with force: true (manual retry / regenerate)
      await docService.processDocument(
        documentId: docId,
        pdfBytes: dummyPdf,
        force: true,
      );

      expect(ocrService.recognizePageCalls, equals(1));
    });

    test('processAttachment skips recognition when OCR pages exist and force is false', () async {
      const attId = 'att-test-1';
      final dummyImage = Uint8List.fromList([5, 6, 7, 8]);

      // Seed existing OCR page row
      final ocrCrypto = OcrCrypto();
      final pageDoc = OcrDocument(
        documentId: attId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Existing image OCR text',
            width: 100,
            height: 100,
          ),
        ],
      );
      final encBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: pageDoc,
        masterKeyBytes: masterKey,
      );
      await db.saveAttachmentOcrPage(
        attachmentId: attId,
        pageNumber: 1,
        encryptedPayload: base64Encode(encBytes),
        processedAt: DateTime.now(),
        isDirty: false,
      );

      // Call processAttachment without force
      await attService.processAttachment(
        attachmentId: attId,
        imageBytes: dummyImage,
        force: false,
      );

      expect(ocrService.recognizePageCalls, equals(0));

      // Call processAttachment with force: true (manual regeneration)
      await attService.processAttachment(
        attachmentId: attId,
        imageBytes: dummyImage,
        force: true,
      );

      expect(ocrService.recognizePageCalls, equals(1));
    });

    test('DocumentService imported PDF initializes to not_requested and does not auto-run OCR', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_policy_test_');
      try {
        final storage = DocumentLocalStorage(
          customDocumentsDirectory: tempDir,
          customTempDirectory: tempDir,
        );
        final fullDocService = DocumentService(
          database: db,
          keyManager: keyManager,
          crypto: DocumentCrypto(),
          storage: storage,
          processingService: docService,
        );

        final samplePdf = Uint8List.fromList(utf8.encode('%PDF-1.4 test document payload'));
        final createResult = await fullDocService.createDocumentFromPdfBytes(
          pdfBytes: samplePdf,
          pageCount: 1,
          title: 'Manual PDF Check',
          source: DocumentSource.importedPdf,
        );

        expect(createResult.document.ocrState, equals(OcrProcessingState.notRequested.identifier));
        expect(ocrService.recognizeDocumentCalls, equals(0));
        expect(ocrService.recognizePageCalls, equals(0));

        final saved = await db.getDocument(createResult.document.id);
        expect(saved?.ocrState, equals('not_requested'));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
