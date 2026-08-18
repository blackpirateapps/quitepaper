import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Versioned envelope for encrypted note content
@immutable
class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.version,
    required this.algorithm,
    required this.keyVersion,
    required this.nonce,
    required this.ciphertext,
    this.contentVersion = 1,
  });

  final int version;
  final String algorithm;
  final int keyVersion;
  final String nonce; // Base64 encoded
  final String ciphertext; // Base64 encoded (ciphertext + MAC)
  final int contentVersion;

  Map<String, dynamic> toJson() => {
        'version': version,
        'algorithm': algorithm,
        'keyVersion': keyVersion,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'contentVersion': contentVersion,
      };

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    return EncryptedEnvelope(
      version: json['version'] as int? ?? 1,
      algorithm: json['algorithm'] as String? ?? 'xchacha20-poly1305',
      keyVersion: json['keyVersion'] as int? ?? 1,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      contentVersion: json['contentVersion'] as int? ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedEnvelope &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          algorithm == other.algorithm &&
          keyVersion == other.keyVersion &&
          nonce == other.nonce &&
          ciphertext == other.ciphertext &&
          contentVersion == other.contentVersion;

  @override
  int get hashCode =>
      version.hashCode ^
      algorithm.hashCode ^
      keyVersion.hashCode ^
      nonce.hashCode ^
      ciphertext.hashCode ^
      contentVersion.hashCode;
}

/// Plaintext note content object before encryption
@immutable
class NotePlaintext {
  const NotePlaintext({
    required this.title,
    required this.body,
    required this.tags,
  });

  final String title;
  final String body;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'tags': tags,
      };

  factory NotePlaintext.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((t) => t.toString()).toList()
        : <String>[];

    return NotePlaintext(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tags: tagsList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePlaintext &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body &&
          listEquals(tags, other.tags);

  @override
  int get hashCode => title.hashCode ^ body.hashCode ^ tags.hashCode;
}

/// Parameters for Argon2id Key Derivation
@immutable
class KdfParameters {
  const KdfParameters({
    this.memory = 19 * 1024, // 19 MB (RFC 9106 recommended minimum for interactive)
    this.iterations = 2,
    this.parallelism = 1,
    this.hashLength = 32,
  });

  final int memory;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Map<String, dynamic> toJson() => {
        'memory': memory,
        'iterations': iterations,
        'parallelism': parallelism,
        'hashLength': hashLength,
      };

  factory KdfParameters.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const KdfParameters();
    return KdfParameters(
      memory: json['memory'] as int? ?? 19 * 1024,
      iterations: json['iterations'] as int? ?? 2,
      parallelism: json['parallelism'] as int? ?? 1,
      hashLength: json['hashLength'] as int? ?? 32,
    );
  }
}

/// Wrapped Master Key record stored in Cloud DB / Local Key Storage
@immutable
class WrappedMasterKeyData {
  const WrappedMasterKeyData({
    required this.keyVersion,
    required this.wrappedMasterKey,
    required this.wrappedNonce,
    required this.kdfAlgorithm,
    required this.kdfSalt,
    required this.kdfParameters,
    required this.encryptionFormatVersion,
    this.recoveryWrappedMasterKey,
    this.recoveryNonce,
    this.recoverySalt,
    this.recoveryParameters,
  });

  final int keyVersion;
  final String wrappedMasterKey; // Base64 ciphertext + MAC tag
  final String wrappedNonce; // Base64 nonce
  final String kdfAlgorithm; // "argon2id"
  final String kdfSalt; // Base64 salt
  final KdfParameters kdfParameters;
  final int encryptionFormatVersion;

  // Optional recovery key wrapping
  final String? recoveryWrappedMasterKey;
  final String? recoveryNonce;
  final String? recoverySalt;
  final KdfParameters? recoveryParameters;

  Map<String, dynamic> toJson() => {
        'keyVersion': keyVersion,
        'wrappedMasterKey': wrappedMasterKey,
        'wrappedNonce': wrappedNonce,
        'kdfAlgorithm': kdfAlgorithm,
        'kdfSalt': kdfSalt,
        'kdfParameters': kdfParameters.toJson(),
        'encryptionFormatVersion': encryptionFormatVersion,
        if (recoveryWrappedMasterKey != null)
          'recoveryWrappedMasterKey': recoveryWrappedMasterKey,
        if (recoveryNonce != null) 'recoveryNonce': recoveryNonce,
        if (recoverySalt != null) 'recoverySalt': recoverySalt,
        if (recoveryParameters != null)
          'recoveryParameters': recoveryParameters!.toJson(),
      };

  factory WrappedMasterKeyData.fromJson(Map<String, dynamic> json) {
    return WrappedMasterKeyData(
      keyVersion: json['keyVersion'] as int? ?? 1,
      wrappedMasterKey: json['wrappedMasterKey'] as String,
      wrappedNonce: json['wrappedNonce'] as String,
      kdfAlgorithm: json['kdfAlgorithm'] as String? ?? 'argon2id',
      kdfSalt: json['kdfSalt'] as String,
      kdfParameters: KdfParameters.fromJson(
        json['kdfParameters'] as Map<String, dynamic>?,
      ),
      encryptionFormatVersion: json['encryptionFormatVersion'] as int? ?? 1,
      recoveryWrappedMasterKey: json['recoveryWrappedMasterKey'] as String?,
      recoveryNonce: json['recoveryNonce'] as String?,
      recoverySalt: json['recoverySalt'] as String?,
      recoveryParameters: json['recoveryParameters'] != null
          ? KdfParameters.fromJson(
              json['recoveryParameters'] as Map<String, dynamic>?,
            )
          : null,
    );
  }
}

/// Abstract Cryptography Service interface isolating all cryptographic operations
abstract class CryptoService {
  /// Generates a new 256-bit cryptographically secure random Master Key
  Future<Uint8List> generateMasterKey();

  /// Generates cryptographically secure random bytes
  Uint8List generateRandomBytes(int length);

  /// Derives a 32-byte key from password using Argon2id
  Future<SecretKey> deriveKeyFromPassword({
    required String password,
    required Uint8List salt,
    KdfParameters parameters = const KdfParameters(),
  });

  /// Derives a 32-byte key from recovery phrase/key
  Future<SecretKey> deriveKeyFromRecoveryKey({
    required String recoveryKey,
    required Uint8List salt,
    KdfParameters parameters = const KdfParameters(),
  });

  /// Wraps master key bytes with a derived key
  Future<EncryptedEnvelope> wrapMasterKey({
    required Uint8List masterKeyBytes,
    required SecretKey wrappingKey,
    int keyVersion = 1,
  });

  /// Unwraps master key bytes using a derived key
  Future<Uint8List> unwrapMasterKey({
    required String wrappedMasterKeyBase64,
    required String nonceBase64,
    required SecretKey wrappingKey,
  });

  /// Encrypts NotePlaintext object using Master Key with Authenticated Associated Data
  Future<EncryptedEnvelope> encryptNote({
    required NotePlaintext plaintext,
    required Uint8List masterKeyBytes,
    required String noteId,
    int keyVersion = 1,
  });

  /// Decrypts EncryptedEnvelope back to NotePlaintext using Master Key
  Future<NotePlaintext> decryptNote({
    required EncryptedEnvelope envelope,
    required Uint8List masterKeyBytes,
    required String noteId,
  });

  /// Generates a human-friendly high-entropy Recovery Key formatted with words/chunks
  String generateRecoveryKey();

  /// Standardizes / cleans recovery key string
  String normalizeRecoveryKey(String key);
}

/// Production implementation of CryptoService using Argon2id and XChaCha20-Poly1305
class DefaultCryptoService implements CryptoService {
  DefaultCryptoService({
    Cipher? cipher,
  }) : _cipher = cipher ?? Xchacha20.poly1305Aead();

  final Cipher _cipher;
  final Random _secureRandom = Random.secure();

  static const String _keyWrapAadPrefix = 'quietpaper:key-wrap:v1';
  static const String _noteAadPrefix = 'quietpaper:note';

  @override
  Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  @override
  Future<Uint8List> generateMasterKey() async {
    final secretKey = await _cipher.newSecretKey();
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  @override
  Future<SecretKey> deriveKeyFromPassword({
    required String password,
    required Uint8List salt,
    KdfParameters parameters = const KdfParameters(),
  }) async {
    final kdf = Argon2id(
      memory: parameters.memory,
      iterations: parameters.iterations,
      parallelism: parameters.parallelism,
      hashLength: parameters.hashLength,
    );
    return kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  @override
  Future<SecretKey> deriveKeyFromRecoveryKey({
    required String recoveryKey,
    required Uint8List salt,
    KdfParameters parameters = const KdfParameters(),
  }) async {
    final normalized = normalizeRecoveryKey(recoveryKey);
    return deriveKeyFromPassword(
      password: normalized,
      salt: salt,
      parameters: parameters,
    );
  }

  @override
  Future<EncryptedEnvelope> wrapMasterKey({
    required Uint8List masterKeyBytes,
    required SecretKey wrappingKey,
    int keyVersion = 1,
  }) async {
    final nonce = _cipher.newNonce();
    final aad = utf8.encode(_keyWrapAadPrefix);

    final secretBox = await _cipher.encrypt(
      masterKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
      aad: aad,
    );

    // secretBox.concatenation() contains ciphertext + MAC
    final concatenated = secretBox.concatenation(nonce: false);

    return EncryptedEnvelope(
      version: 1,
      algorithm: 'xchacha20-poly1305',
      keyVersion: keyVersion,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(concatenated),
      contentVersion: 1,
    );
  }

  @override
  Future<Uint8List> unwrapMasterKey({
    required String wrappedMasterKeyBase64,
    required String nonceBase64,
    required SecretKey wrappingKey,
  }) async {
    final nonce = base64Decode(nonceBase64);
    final combinedCiphertext = base64Decode(wrappedMasterKeyBase64);
    final aad = utf8.encode(_keyWrapAadPrefix);

    if (combinedCiphertext.length < 16) {
      throw const FormatException('Invalid ciphertext length for key unwrap');
    }

    final cipherBytes = combinedCiphertext.sublist(0, combinedCiphertext.length - 16);
    final macBytes = combinedCiphertext.sublist(combinedCiphertext.length - 16);

    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _cipher.decrypt(
      secretBox,
      secretKey: wrappingKey,
      aad: aad,
    );

    return Uint8List.fromList(decrypted);
  }

  @override
  Future<EncryptedEnvelope> encryptNote({
    required NotePlaintext plaintext,
    required Uint8List masterKeyBytes,
    required String noteId,
    int keyVersion = 1,
  }) async {
    final payloadJson = jsonEncode(plaintext.toJson());
    final payloadBytes = utf8.encode(payloadJson);

    final masterSecretKey = SecretKey(masterKeyBytes);
    final nonce = _cipher.newNonce();
    final aad = utf8.encode('$_noteAadPrefix:$noteId:v1');

    final secretBox = await _cipher.encrypt(
      payloadBytes,
      secretKey: masterSecretKey,
      nonce: nonce,
      aad: aad,
    );

    final combinedCiphertext = secretBox.concatenation(nonce: false);

    return EncryptedEnvelope(
      version: 1,
      algorithm: 'xchacha20-poly1305',
      keyVersion: keyVersion,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(combinedCiphertext),
      contentVersion: 1,
    );
  }

  @override
  Future<NotePlaintext> decryptNote({
    required EncryptedEnvelope envelope,
    required Uint8List masterKeyBytes,
    required String noteId,
  }) async {
    final nonce = base64Decode(envelope.nonce);
    final combinedCiphertext = base64Decode(envelope.ciphertext);
    final aad = utf8.encode('$_noteAadPrefix:$noteId:v${envelope.version}');

    if (combinedCiphertext.length < 16) {
      throw const FormatException('Ciphertext too short for Poly1305 MAC');
    }

    final cipherBytes = combinedCiphertext.sublist(0, combinedCiphertext.length - 16);
    final macBytes = combinedCiphertext.sublist(combinedCiphertext.length - 16);

    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final masterSecretKey = SecretKey(masterKeyBytes);

    final decryptedBytes = await _cipher.decrypt(
      secretBox,
      secretKey: masterSecretKey,
      aad: aad,
    );

    final jsonMap = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
    return NotePlaintext.fromJson(jsonMap);
  }

  @override
  String generateRecoveryKey() {
    final bytes = generateRandomBytes(32);
    final hexChars = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final chunks = <String>[];
    for (var i = 0; i < hexChars.length; i += 4) {
      chunks.add(hexChars.substring(i, i + 4));
    }
    return 'qp-${chunks.join('-')}';
  }

  @override
  String normalizeRecoveryKey(String key) {
    return key.trim().toLowerCase().replaceAll(RegExp(r'[^a-f0-9]'), '');
  }
}
