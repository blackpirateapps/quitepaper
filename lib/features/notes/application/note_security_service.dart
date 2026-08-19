import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../../core/crypto/crypto_service.dart';

class InvalidNotePasswordException implements Exception {
  final String message;
  const InvalidNotePasswordException([this.message = 'Incorrect password']);

  @override
  String toString() => message;
}

class DecryptedNotePayload {
  final String title;
  final String content;
  final List<String> tags;
  final String? hint;

  const DecryptedNotePayload({
    required this.title,
    required this.content,
    this.tags = const [],
    this.hint,
  });
}

/// Service for encrypting and decrypting individual password-protected notes.
class NoteSecurityService {
  static const String _encryptedPrefix = '<!-- quiet-paper-encrypted-note-v1:';
  static const String _encryptedSuffix = ' -->';

  static final CryptoService _cryptoService = DefaultCryptoService();

  /// Checks if a note's raw content is encrypted with a note password.
  static bool isEncrypted(String content) {
    final trimmed = content.trimLeft();
    return trimmed.startsWith(_encryptedPrefix) && trimmed.endsWith(_encryptedSuffix);
  }

  /// Extracts the optional password hint from an encrypted note payload without decrypting.
  static String? getHint(String content) {
    if (!isEncrypted(content)) return null;
    try {
      final jsonStr = _extractJson(content);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map['hint'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Encrypts note title, content, and tags into an encrypted envelope string.
  static Future<String> encryptNote({
    required String title,
    required String content,
    List<String> tags = const [],
    required String password,
    String? hint,
  }) async {
    final salt = _cryptoService.generateRandomBytes(16);
    final nonce = _cryptoService.generateRandomBytes(24);

    final secretKey = await _cryptoService.deriveKeyFromPassword(
      password: password,
      salt: salt,
      parameters: KdfParameters.standard,
    );

    final payloadMap = {
      'title': title,
      'content': content,
      'tags': tags,
      if (hint != null && hint.isNotEmpty) 'hint': hint,
    };
    final plaintextBytes = utf8.encode(jsonEncode(payloadMap));

    final combinedCiphertext = await _cryptoService.encryptRawBytes(
      plaintextBytes: plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'version': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(combinedCiphertext),
      if (hint != null && hint.isNotEmpty) 'hint': hint,
    };

    return '$_encryptedPrefix${jsonEncode(envelope)}$_encryptedSuffix';
  }

  /// Decrypts an encrypted note using the provided password.
  /// Throws [InvalidNotePasswordException] if password is incorrect.
  static Future<DecryptedNotePayload> decryptNote({
    required String encryptedContent,
    required String password,
  }) async {
    if (!isEncrypted(encryptedContent)) {
      return DecryptedNotePayload(
        title: '',
        content: encryptedContent,
      );
    }

    try {
      final jsonStr = _extractJson(encryptedContent);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final salt = base64Decode(map['salt'] as String);
      final nonce = base64Decode(map['nonce'] as String);
      final combinedCiphertext = base64Decode(map['ciphertext'] as String);
      final hint = map['hint'] as String?;

      final secretKey = await _cryptoService.deriveKeyFromPassword(
        password: password,
        salt: Uint8List.fromList(salt),
        parameters: KdfParameters.standard,
      );

      final decryptedBytes = await _cryptoService.decryptRawBytes(
        combinedCiphertext: combinedCiphertext,
        secretKey: secretKey,
        nonce: nonce,
      );

      final decryptedJson = utf8.decode(decryptedBytes);
      final payloadMap = jsonDecode(decryptedJson) as Map<String, dynamic>;

      final rawTags = payloadMap['tags'];
      final tagsList = rawTags is List
          ? rawTags.map((t) => t.toString()).toList()
          : <String>[];

      return DecryptedNotePayload(
        title: payloadMap['title'] as String? ?? '',
        content: payloadMap['content'] as String? ?? '',
        tags: tagsList,
        hint: hint,
      );
    } on SecretBoxAuthenticationError {
      throw const InvalidNotePasswordException('Incorrect password');
    } catch (e) {
      if (e is InvalidNotePasswordException) rethrow;
      throw const InvalidNotePasswordException('Incorrect password or corrupt note data');
    }
  }

  static String _extractJson(String content) {
    final trimmed = content.trim();
    return trimmed.substring(
      _encryptedPrefix.length,
      trimmed.length - _encryptedSuffix.length,
    );
  }
}
