import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as standard_crypto;
import 'package:cryptography/cryptography.dart';
import '../crypto/crypto_service.dart';

/// Thrown when document decryption or MAC authentication fails.
class DocumentDecryptionException implements Exception {
  const DocumentDecryptionException(this.message);
  final String message;

  @override
  String toString() => 'DocumentDecryptionException: $message';
}

/// Cryptographic service dedicated to client-side scanned document (PDF) encryption/decryption
/// using XChaCha20-Poly1305 AEAD and the user's Master Key.
class DocumentCrypto {
  DocumentCrypto({
    CryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? DefaultCryptoService();

  final CryptoService _cryptoService;

  /// Magic header bytes for Quiet Paper encrypted binary documents ('QPD1').
  static const List<int> magicBytes = [0x51, 0x50, 0x44, 0x31]; // 'Q', 'P', 'D', '1'
  static const int currentFormatVersion = 1;
  static const int nonceLength = 24; // XChaCha20 24-byte nonce
  static const int macLength = 16; // Poly1305 16-byte MAC tag
  static const int headerLength = 8 + nonceLength; // 4 magic + 2 formatVersion + 2 keyVersion + 24 nonce = 32 bytes

  /// Computes standard hex SHA-256 of plaintext PDF bytes.
  static String computeSha256(Uint8List bytes) {
    return standard_crypto.sha256.convert(bytes).toString();
  }

  /// Builds authenticated associated data string bound strictly to the document ID.
  static String buildAad(String documentId, {int version = 1}) {
    return 'quietpaper:document:$documentId:v$version';
  }

  /// Encrypts raw plaintext PDF bytes using the user's Master Key.
  ///
  /// Returns a self-describing binary envelope:
  /// `[4-byte magic | 2-byte formatVersion | 2-byte keyVersion | 24-byte nonce | ciphertext + 16-byte MAC]`
  Future<Uint8List> encryptDocument({
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

    // 1. Magic bytes (4 bytes: 'QPD1')
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

  /// Decrypts an encrypted document binary payload using the user's Master Key.
  ///
  /// Verifies the envelope magic, format version, and Poly1305 MAC tag with bound document AAD.
  Future<Uint8List> decryptDocument({
    required Uint8List encryptedEnvelopeBytes,
    required Uint8List masterKeyBytes,
    required String documentId,
  }) async {
    if (encryptedEnvelopeBytes.length < headerLength + macLength) {
      throw const DocumentDecryptionException(
        'Encrypted document payload is too short or malformed',
      );
    }

    // 1. Verify Magic bytes
    for (var i = 0; i < magicBytes.length; i++) {
      if (encryptedEnvelopeBytes[i] != magicBytes[i]) {
        throw const DocumentDecryptionException(
          'Invalid document magic header. Payload may be corrupt or unencrypted.',
        );
      }
    }

    // 2. Read versions
    final byteData = ByteData.sublistView(encryptedEnvelopeBytes, 4, 8);
    final formatVersion = byteData.getUint16(0, Endian.big);
    if (formatVersion != currentFormatVersion) {
      throw DocumentDecryptionException(
        'Unsupported document format version: $formatVersion (expected $currentFormatVersion)',
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
      throw DocumentDecryptionException(
        'Failed to authenticate/decrypt document. Key mismatch or ciphertext tampered: $e',
      );
    }
  }
}
