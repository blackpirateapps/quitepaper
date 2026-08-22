import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/attachments/attachment_processing_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_search_service.dart';
import 'package:quitepaper/core/ocr/ocr_service.dart';

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
  void lock() => isUnlocked = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOcrService implements OcrService {
  MockOcrService({required this.mockPage});

  final OcrPage mockPage;

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    return mockPage;
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
      pages: [mockPage],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentProcessingService Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late OcrCrypto ocrCrypto;
    late OcrSearchService ocrSearchService;
    late AttachmentProcessingService processingService;
    late Uint8List testImageBytes;

    setUp(() async {
      database = AppDatabase.memory();
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);
      ocrCrypto = OcrCrypto(cryptoService: cryptoService);
      ocrSearchService = OcrSearchService(database: database, keyManager: keyManager);

      // Create valid PNG bytes
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(255, 255, 255));
      testImageBytes = Uint8List.fromList(img.encodePng(testImage));

      final mockOcrPage = OcrPage(
        pageNumber: 1,
        plainText: 'Invoice #1042 Total: \$45.00',
        width: 100,
        height: 100,
        blocks: [
          OcrBlock(
            text: 'Invoice #1042 Total: \$45.00',
            bounds: NormalizedRect.full,
            lines: [
              OcrLine(
                text: 'Invoice #1042 Total: \$45.00',
                bounds: NormalizedRect.full,
                words: [
                  OcrWord(text: 'Invoice', bounds: NormalizedRect.full),
                  OcrWord(text: '#1042', bounds: NormalizedRect.full),
                  OcrWord(text: 'Total:', bounds: NormalizedRect.full),
                  OcrWord(text: '\$45.00', bounds: NormalizedRect.full),
                ],
              ),
            ],
          ),
        ],
      );

      final mockOcrService = MockOcrService(mockPage: mockOcrPage);

      processingService = AttachmentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: ocrCrypto,
        ocrService: mockOcrService,
        ocrSearchService: ocrSearchService,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('Processes image, encrypts OCR payload and updates ocrState to available', () async {
      const attachmentId = 'att-test-uuid-1';
      final now = DateTime.now();

      await database.saveAttachment(
        id: attachmentId,
        createdAt: now,
        updatedAt: now,
        ocrState: 'queued',
      );

      await processingService.processAttachment(
        attachmentId: attachmentId,
        imageBytes: testImageBytes,
      );

      final att = await database.getAttachment(attachmentId);
      expect(att, isNotNull);
      expect(att!.ocrState, 'available');

      final ocrPages = await database.getAttachmentOcrPages(attachmentId);
      expect(ocrPages, hasLength(1));
      expect(ocrPages.first.pageNumber, 1);
      expect(ocrPages.first.ocrEngine, 'quietpaper_image_ocr');

      // Verify client-side decryption of saved envelope
      final encryptedBytes = base64Decode(ocrPages.first.encryptedPayload);
      final decryptedDoc = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: encryptedBytes,
        masterKeyBytes: keyManager.getMasterKey(),
        documentId: attachmentId,
      );

      expect(decryptedDoc.documentId, attachmentId);
      expect(decryptedDoc.pages, hasLength(1));
      expect(decryptedDoc.pages.first.plainText, 'Invoice #1042 Total: \$45.00');
    });

    test('Regenerate OCR invalidates search cache and re-processes attachment', () async {
      const attachmentId = 'att-test-uuid-2';
      final now = DateTime.now();

      await database.saveAttachment(
        id: attachmentId,
        createdAt: now,
        updatedAt: now,
        ocrState: 'available',
      );

      await processingService.regenerateOcr(
        attachmentId: attachmentId,
        imageBytes: testImageBytes,
      );

      final att = await database.getAttachment(attachmentId);
      expect(att!.ocrState, 'available');

      final ocrPages = await database.getAttachmentOcrPages(attachmentId);
      expect(ocrPages, hasLength(1));
    });
  });
}
