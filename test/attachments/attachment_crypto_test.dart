import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';

void main() {
  group('AttachmentCrypto Tests', () {
    late CryptoService cryptoService;
    late AttachmentCrypto attachmentCrypto;
    late Uint8List masterKey;
    const attachmentId = '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d';

    setUp(() {
      cryptoService = DefaultCryptoService();
      attachmentCrypto = AttachmentCrypto(cryptoService: cryptoService);
      masterKey = cryptoService.generateRandomBytes(32);
    });

    test('Encrypts and decrypts raw image bytes with Master Key', () async {
      final plaintext = Uint8List.fromList(
        utf8.encode('Fake PNG binary header and contents for testing attachments 12345'),
      );

      final encrypted = await attachmentCrypto.encryptAttachment(
        plaintextBytes: plaintext,
        masterKeyBytes: masterKey,
        attachmentId: attachmentId,
      );

      // Verify header magic bytes
      expect(encrypted.length, greaterThan(32));
      expect(encrypted.sublist(0, 4), AttachmentCrypto.magicBytes);

      // Decrypt
      final decrypted = await attachmentCrypto.decryptAttachment(
        encryptedEnvelopeBytes: encrypted,
        masterKeyBytes: masterKey,
        attachmentId: attachmentId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('Throws AttachmentDecryptionException if ciphertext is tampered', () async {
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      final encrypted = await attachmentCrypto.encryptAttachment(
        plaintextBytes: plaintext,
        masterKeyBytes: masterKey,
        attachmentId: attachmentId,
      );

      // Tamper one byte in the ciphertext body
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => attachmentCrypto.decryptAttachment(
          encryptedEnvelopeBytes: tampered,
          masterKeyBytes: masterKey,
          attachmentId: attachmentId,
        ),
        throwsA(isA<AttachmentDecryptionException>()),
      );
    });

    test('Throws AttachmentDecryptionException if wrong Master Key is used', () async {
      final plaintext = Uint8List.fromList([10, 20, 30, 40, 50]);

      final encrypted = await attachmentCrypto.encryptAttachment(
        plaintextBytes: plaintext,
        masterKeyBytes: masterKey,
        attachmentId: attachmentId,
      );

      final wrongKey = cryptoService.generateRandomBytes(32);

      expect(
        () => attachmentCrypto.decryptAttachment(
          encryptedEnvelopeBytes: encrypted,
          masterKeyBytes: wrongKey,
          attachmentId: attachmentId,
        ),
        throwsA(isA<AttachmentDecryptionException>()),
      );
    });

    test('Throws AttachmentDecryptionException if wrong attachmentId is provided (AAD mismatch)', () async {
      final plaintext = Uint8List.fromList([100, 101, 102]);

      final encrypted = await attachmentCrypto.encryptAttachment(
        plaintextBytes: plaintext,
        masterKeyBytes: masterKey,
        attachmentId: attachmentId,
      );

      const differentAttachmentId = '11111111-2222-3333-4444-555555555555';

      expect(
        () => attachmentCrypto.decryptAttachment(
          encryptedEnvelopeBytes: encrypted,
          masterKeyBytes: masterKey,
          attachmentId: differentAttachmentId,
        ),
        throwsA(isA<AttachmentDecryptionException>()),
      );
    });

    test('Computes deterministic SHA-256 digest', () {
      final bytes = Uint8List.fromList(utf8.encode('Quiet Paper attachment content'));
      final hash1 = AttachmentCrypto.computeSha256(bytes);
      final hash2 = AttachmentCrypto.computeSha256(bytes);

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
    });
  });
}
