import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

void main() {
  group('OcrCrypto End-to-End Encryption & AEAD Tests', () {
    late OcrCrypto ocrCrypto;
    late Uint8List testMasterKey;

    setUp(() {
      ocrCrypto = OcrCrypto();
      // 32-byte test master key
      testMasterKey = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
    });

    test('Encrypts and decrypts structured OcrDocument with authenticated envelope', () async {
      const documentId = '55555555-4444-3333-2222-111111111111';

      const page = OcrPage(
        pageNumber: 1,
        plainText: 'Encrypted OCR confidential invoice text',
        width: 800,
        height: 1200,
        blocks: [
          OcrBlock(
            text: 'Encrypted OCR confidential invoice text',
            bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2),
          ),
        ],
      );

      final originalDoc = OcrDocument(
        documentId: documentId,
        language: OcrLanguage.english,
        engine: 'quietpaper_ocr_v1',
        engineVersion: '1.0.0',
        processedAt: DateTime.now(),
        pages: [page],
      );

      final encryptedEnvelope = await ocrCrypto.encryptOcrDocument(
        ocrDocument: originalDoc,
        masterKeyBytes: testMasterKey,
      );

      // Verify Magic Bytes 'QPOC'
      expect(encryptedEnvelope.sublist(0, 4), equals(OcrCrypto.magicBytes));

      final decryptedDoc = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: encryptedEnvelope,
        masterKeyBytes: testMasterKey,
        documentId: documentId,
      );

      expect(decryptedDoc.documentId, equals(documentId));
      expect(decryptedDoc.pages.length, equals(1));
      expect(decryptedDoc.pages.first.plainText, equals('Encrypted OCR confidential invoice text'));
    });

    test('Fails decryption if documentId AAD is mismatched or tampered', () async {
      const documentId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      const otherDocId = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';

      final originalDoc = OcrDocument(
        documentId: documentId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(pageNumber: 1, plainText: 'Top Secret Payload', width: 500, height: 500),
        ],
      );

      final encryptedEnvelope = await ocrCrypto.encryptOcrDocument(
        ocrDocument: originalDoc,
        masterKeyBytes: testMasterKey,
      );

      // Decrypting under a different document ID should fail AAD MAC verification
      expect(
        () async => await ocrCrypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedEnvelope,
          masterKeyBytes: testMasterKey,
          documentId: otherDocId,
        ),
        throwsA(isA<OcrDecryptionException>()),
      );
    });

    test('Fails decryption if wrong master key is provided', () async {
      const documentId = '12345678-1234-1234-1234-123456789012';
      final wrongMasterKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

      final originalDoc = OcrDocument(
        documentId: documentId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(pageNumber: 1, plainText: 'Plaintext string', width: 500, height: 500),
        ],
      );

      final encryptedEnvelope = await ocrCrypto.encryptOcrDocument(
        ocrDocument: originalDoc,
        masterKeyBytes: testMasterKey,
      );

      expect(
        () async => await ocrCrypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedEnvelope,
          masterKeyBytes: wrongMasterKey,
          documentId: documentId,
        ),
        throwsA(isA<OcrDecryptionException>()),
      );
    });
  });
}
