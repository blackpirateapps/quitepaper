import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';

void main() {
  group('DocumentCrypto Security & Envelope Tests', () {
    late DocumentCrypto documentCrypto;
    late Uint8List masterKey;
    const documentId = '550e8400-e29b-41d4-a716-446655440000';
    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample PDF binary payload content'));

    setUp(() {
      final cryptoService = DefaultCryptoService();
      documentCrypto = DocumentCrypto(cryptoService: cryptoService);
      masterKey = cryptoService.generateRandomBytes(32);
    });

    test('Encrypts and decrypts PDF bytes successfully with authenticated AAD', () async {
      final encrypted = await documentCrypto.encryptDocument(
        plaintextBytes: samplePdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      // Verify Magic Header 'QPD1'
      expect(encrypted.sublist(0, 4), [0x51, 0x50, 0x44, 0x31]);
      expect(encrypted.length, greaterThan(samplePdfBytes.length + 32));

      final decrypted = await documentCrypto.decryptDocument(
        encryptedEnvelopeBytes: encrypted,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      expect(decrypted, samplePdfBytes);
    });

    test('Fails decryption when Master Key is wrong', () async {
      final wrongKey = DefaultCryptoService().generateRandomBytes(32);
      final encrypted = await documentCrypto.encryptDocument(
        plaintextBytes: samplePdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      expect(
        () => documentCrypto.decryptDocument(
          encryptedEnvelopeBytes: encrypted,
          masterKeyBytes: wrongKey,
          documentId: documentId,
        ),
        throwsA(isA<DocumentDecryptionException>()),
      );
    });

    test('Fails decryption when document ID does not match bound AAD', () async {
      const differentDocumentId = '660e8400-e29b-41d4-a716-446655440000';
      final encrypted = await documentCrypto.encryptDocument(
        plaintextBytes: samplePdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      expect(
        () => documentCrypto.decryptDocument(
          encryptedEnvelopeBytes: encrypted,
          masterKeyBytes: masterKey,
          documentId: differentDocumentId,
        ),
        throwsA(isA<DocumentDecryptionException>()),
      );
    });

    test('Fails decryption when ciphertext is tampered', () async {
      final encrypted = await documentCrypto.encryptDocument(
        plaintextBytes: samplePdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      // Tamper ciphertext byte
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => documentCrypto.decryptDocument(
          encryptedEnvelopeBytes: tampered,
          masterKeyBytes: masterKey,
          documentId: documentId,
        ),
        throwsA(isA<DocumentDecryptionException>()),
      );
    });

    test('Fails decryption when magic header is invalid', () async {
      final encrypted = await documentCrypto.encryptDocument(
        plaintextBytes: samplePdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      final invalidMagic = Uint8List.fromList(encrypted);
      invalidMagic[0] = 0x00; // Corrupt 'Q'

      expect(
        () => documentCrypto.decryptDocument(
          encryptedEnvelopeBytes: invalidMagic,
          masterKeyBytes: masterKey,
          documentId: documentId,
        ),
        throwsA(isA<DocumentDecryptionException>()),
      );
    });

    test('Computes deterministic SHA-256 for PDF bytes', () {
      final sha1 = DocumentCrypto.computeSha256(samplePdfBytes);
      final sha2 = DocumentCrypto.computeSha256(samplePdfBytes);
      expect(sha1, sha2);
      expect(sha1.length, 64);
    });
  });
}
