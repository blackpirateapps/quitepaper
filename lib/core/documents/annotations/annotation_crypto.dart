import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../crypto/crypto_service.dart';
import 'annotation_models.dart';

/// Thrown when annotation payload decryption or MAC verification fails.
class AnnotationDecryptionException implements Exception {
  const AnnotationDecryptionException(this.message);
  final String message;

  @override
  String toString() => 'AnnotationDecryptionException: $message';
}

/// Client-side encryption for a document page's annotation list, modeled on
/// [OcrCrypto]: XChaCha20-Poly1305 AEAD under the user's Master Key, with a
/// self-describing envelope. The backend only ever sees this ciphertext.
class AnnotationCrypto {
  AnnotationCrypto({CryptoService? cryptoService})
      : _cryptoService = cryptoService ?? DefaultCryptoService();

  final CryptoService _cryptoService;

  /// Magic header bytes for Quiet Paper encrypted annotations ('QPAN').
  static const List<int> magicBytes = [0x51, 0x50, 0x41, 0x4E]; // Q P A N
  static const int currentFormatVersion = 1;
  static const int nonceLength = 24; // XChaCha20 24-byte nonce
  static const int macLength = 16; // Poly1305 16-byte MAC tag
  static const int headerLength = 8 + nonceLength; // 4 magic + 2 fmt + 2 key + 24 nonce

  /// Associated data bound to the document id and page.
  static String buildAad(String documentId, int pageIndex, {int version = 1}) {
    return 'quietpaper:document-annotation:$documentId:p$pageIndex:v$version';
  }

  /// Encrypts a page's [annotations] into an authenticated binary envelope.
  Future<Uint8List> encryptPage({
    required String documentId,
    required int pageIndex,
    required List<Annotation> annotations,
    required Uint8List masterKeyBytes,
    int keyVersion = 1,
  }) async {
    final payload = {
      'v': currentFormatVersion,
      'documentId': documentId,
      'pageIndex': pageIndex,
      'annotations': annotations.map((a) => a.toJson()).toList(),
    };
    final plaintextBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    final nonce = _cryptoService.generateRandomBytes(nonceLength);
    final aad = utf8.encode(buildAad(documentId, pageIndex));
    final secretKey = SecretKey(masterKeyBytes);

    final ciphertextWithMac = await _cryptoService.encryptRawBytes(
      plaintextBytes: plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
      associatedData: aad,
    );

    final builder = BytesBuilder(copy: false);
    builder.add(magicBytes);
    final versionData = ByteData(4);
    versionData.setUint16(0, currentFormatVersion, Endian.big);
    versionData.setUint16(2, keyVersion, Endian.big);
    builder.add(versionData.buffer.asUint8List());
    builder.add(nonce);
    builder.add(ciphertextWithMac);
    return builder.takeBytes();
  }

  /// Decrypts an annotation envelope back into a page's annotation list.
  Future<List<Annotation>> decryptPage({
    required Uint8List encryptedEnvelopeBytes,
    required Uint8List masterKeyBytes,
    required String documentId,
    required int pageIndex,
  }) async {
    if (encryptedEnvelopeBytes.length < headerLength + macLength) {
      throw const AnnotationDecryptionException(
        'Encrypted annotation payload is too short or malformed',
      );
    }

    for (var i = 0; i < magicBytes.length; i++) {
      if (encryptedEnvelopeBytes[i] != magicBytes[i]) {
        throw const AnnotationDecryptionException(
          'Invalid annotation magic header. Payload may be corrupt.',
        );
      }
    }

    final byteData = ByteData.sublistView(encryptedEnvelopeBytes, 4, 8);
    final formatVersion = byteData.getUint16(0, Endian.big);
    if (formatVersion != currentFormatVersion) {
      throw AnnotationDecryptionException(
        'Unsupported annotation format version: $formatVersion',
      );
    }

    final nonce = encryptedEnvelopeBytes.sublist(8, 8 + nonceLength);
    final ciphertextWithMac = encryptedEnvelopeBytes.sublist(headerLength);
    final aad = utf8.encode(buildAad(documentId, pageIndex, version: formatVersion));
    final secretKey = SecretKey(masterKeyBytes);

    final Uint8List decrypted;
    try {
      decrypted = await _cryptoService.decryptRawBytes(
        combinedCiphertext: ciphertextWithMac,
        secretKey: secretKey,
        nonce: nonce,
        associatedData: aad,
      );
    } catch (e) {
      throw AnnotationDecryptionException(
        'Failed to authenticate/decrypt annotation payload: $e',
      );
    }

    try {
      final jsonMap = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
      final raw = jsonMap['annotations'] as List? ?? const [];
      return raw
          .whereType<Map>()
          .map((m) => Annotation.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      throw AnnotationDecryptionException(
        'Failed to deserialize decrypted annotation JSON: $e',
      );
    }
  }
}
