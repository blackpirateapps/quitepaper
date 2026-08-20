import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../crypto/crypto_service.dart';
import 'ocr_models.dart';

/// Thrown when OCR payload decryption or MAC verification fails.
class OcrDecryptionException implements Exception {
  const OcrDecryptionException(this.message);
  final String message;

  @override
  String toString() => 'OcrDecryptionException: $message';
}

/// Cryptographic service dedicated to client-side OCR payload encryption/decryption
/// using XChaCha20-Poly1305 AEAD and the user's Master Key.
class OcrCrypto {
  OcrCrypto({
    CryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? DefaultCryptoService();

  final CryptoService _cryptoService;

  /// Magic header bytes for Quiet Paper encrypted OCR documents ('QPOC').
  static const List<int> magicBytes = [0x51, 0x50, 0x4F, 0x43]; // 'Q', 'P', 'O', 'C'
  static const int currentFormatVersion = 1;
  static const int nonceLength = 24; // XChaCha20 24-byte nonce
  static const int macLength = 16; // Poly1305 16-byte MAC tag
  static const int headerLength = 8 + nonceLength; // 4 magic + 2 formatVersion + 2 keyVersion + 24 nonce = 32 bytes

  /// Builds authenticated associated data string bound strictly to the document ID.
  static String buildAad(String documentId, {int version = 1}) {
    return 'quietpaper:document-ocr:$documentId:v$version';
  }

  /// Encrypts an [OcrDocument] into a self-describing authenticated binary envelope using the Master Key.
  Future<Uint8List> encryptOcrDocument({
    required OcrDocument ocrDocument,
    required Uint8List masterKeyBytes,
    int keyVersion = 1,
  }) async {
    final jsonString = jsonEncode(ocrDocument.toJson());
    final plaintextBytes = utf8.encode(jsonString);

    return encryptRawOcrBytes(
      plaintextBytes: Uint8List.fromList(plaintextBytes),
      masterKeyBytes: masterKeyBytes,
      documentId: ocrDocument.documentId,
      keyVersion: keyVersion,
    );
  }

  /// Encrypts raw plaintext OCR bytes (UTF-8 JSON) using the Master Key.
  Future<Uint8List> encryptRawOcrBytes({
    required Uint8List plaintextBytes,
    required Uint8List masterKeyBytes,
    required String documentId,
    int keyVersion = 1,
  }) async {
    final nonce = _cryptoService.generateRandomBytes(nonceLength);
    final aadString = buildAad(documentId, version: currentFormatVersion);
    final aad = utf8.encode(aadString);

    final secretKey = SecretKey(masterKeyBytes);

    final ciphertextWithMac = await _cryptoService.encryptRawBytes(
      plaintextBytes: plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
      associatedData: aad,
    );

    final builder = BytesBuilder(copy: false);

    // 1. Magic bytes (4 bytes: 'QPOC')
    builder.add(magicBytes);

    // 2. Format version & Key version (4 bytes, big-endian)
    final versionData = ByteData(4);
    versionData.setUint16(0, currentFormatVersion, Endian.big);
    versionData.setUint16(2, keyVersion, Endian.big);
    builder.add(versionData.buffer.asUint8List());

    // 3. Nonce (24 bytes)
    builder.add(nonce);

    // 4. Ciphertext + MAC (variable length)
    builder.add(ciphertextWithMac);

    return builder.takeBytes();
  }

  /// Decrypts an encrypted OCR payload and parses it into an [OcrDocument].
  Future<OcrDocument> decryptOcrDocument({
    required Uint8List encryptedEnvelopeBytes,
    required Uint8List masterKeyBytes,
    required String documentId,
  }) async {
    final decryptedBytes = await decryptRawOcrBytes(
      encryptedEnvelopeBytes: encryptedEnvelopeBytes,
      masterKeyBytes: masterKeyBytes,
      documentId: documentId,
    );

    try {
      final jsonString = utf8.decode(decryptedBytes);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return OcrDocument.fromJson(jsonMap);
    } catch (e) {
      throw OcrDecryptionException('Failed to deserialize decrypted OCR JSON: $e');
    }
  }

  /// Decrypts raw encrypted OCR envelope bytes using the Master Key.
  Future<Uint8List> decryptRawOcrBytes({
    required Uint8List encryptedEnvelopeBytes,
    required Uint8List masterKeyBytes,
    required String documentId,
  }) async {
    if (encryptedEnvelopeBytes.length < headerLength + macLength) {
      throw const OcrDecryptionException(
        'Encrypted OCR payload is too short or malformed',
      );
    }

    // 1. Verify Magic bytes
    for (var i = 0; i < magicBytes.length; i++) {
      if (encryptedEnvelopeBytes[i] != magicBytes[i]) {
        throw const OcrDecryptionException(
          'Invalid OCR magic header. Payload may be corrupt or unencrypted.',
        );
      }
    }

    // 2. Read versions
    final byteData = ByteData.sublistView(encryptedEnvelopeBytes, 4, 8);
    final formatVersion = byteData.getUint16(0, Endian.big);
    if (formatVersion != currentFormatVersion) {
      throw OcrDecryptionException(
        'Unsupported OCR format version: $formatVersion (expected $currentFormatVersion)',
      );
    }

    // 3. Extract Nonce
    final nonce = encryptedEnvelopeBytes.sublist(8, 8 + nonceLength);

    // 4. Extract Ciphertext + MAC
    final ciphertextWithMac = encryptedEnvelopeBytes.sublist(headerLength);

    // 5. Reconstruct Associated Data bound to document ID
    final aadString = buildAad(documentId, version: formatVersion);
    final aad = utf8.encode(aadString);

    final secretKey = SecretKey(masterKeyBytes);

    try {
      final decrypted = await _cryptoService.decryptRawBytes(
        combinedCiphertext: ciphertextWithMac,
        secretKey: secretKey,
        nonce: nonce,
        associatedData: aad,
      );
      return decrypted;
    } catch (e) {
      throw OcrDecryptionException(
        'Failed to authenticate/decrypt OCR payload. Key mismatch or ciphertext tampered: $e',
      );
    }
  }
}
