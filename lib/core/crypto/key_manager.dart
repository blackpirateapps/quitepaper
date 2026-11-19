import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../storage/quiet_secure_storage.dart';
import 'crypto_service.dart';
import '../attachments/attachment_storage.dart';

class LocalVaultMigrationException implements Exception {
  @override
  String toString() =>
      'Local encrypted files could not be prepared for cloud sign-in. '
      'Your local files and keys are retained. Please retry sign-in; '
      'restore any missing or damaged local files if this continues.';
}

/// Key Manager interface managing secure key storage and lifecycle
abstract class KeyManager {
  bool get isUnlocked;
  bool get hasKeyData;
  Uint8List? get cachedMasterKey;

  /// Returns active Master Key or throws StateError if locked
  Uint8List getMasterKey();

  /// Initializes KeyManager from secure storage
  Future<void> initialize();

  /// Creates a device-protected key only for a fresh, unlocked local vault.
  /// Never replaces persisted keys or unlocks an explicitly locked notebook.
  Future<void> ensureLocalKey();

  /// Sets up a brand new Master Key protected by user password and optional recovery key
  Future<WrappedMasterKeyData> setupNewKeys({
    required String password,
    String? recoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  });

  /// Unlocks master key using user encryption password
  Future<void> unlockWithPassword({
    required String password,
    WrappedMasterKeyData? remoteWrappedKey,
  });

  /// Unlocks master key using recovery key
  Future<void> unlockWithRecoveryKey({
    required String recoveryKey,
    WrappedMasterKeyData? remoteWrappedKey,
  });

  /// Changes the user encryption password by re-wrapping master key (note ciphertexts stay identical)
  Future<WrappedMasterKeyData> changePassword({
    required String newPassword,
    String? newRecoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  });

  /// Locks key manager and discards decrypted master key from memory
  void lock();

  /// Clears all local secure key storage (e.g. on user logout)
  Future<void> clearLocalKeys();

  /// Gets the currently stored WrappedMasterKeyData
  Future<WrappedMasterKeyData?> getStoredWrappedKeyData();

  /// Stores or updates WrappedMasterKeyData locally
  Future<void> storeWrappedKeyData(WrappedMasterKeyData data);
}

/// Secure implementation of KeyManager using FlutterSecureStorage and CryptoService
class SecureKeyManager implements KeyManager {
  SecureKeyManager({
    CryptoService? cryptoService,
    FlutterSecureStorage? secureStorage,
    this.migrateLocalVault,
  }) : _crypto = cryptoService ?? DefaultCryptoService(),
       _storage =
           secureStorage ??
           const QuietSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           );

  final CryptoService _crypto;
  final FlutterSecureStorage _storage;
  final Future<void> Function(Uint8List oldKey, Uint8List newKey)?
  migrateLocalVault;

  static const String _storageKeyWrappedData =
      'quietpaper_wrapped_master_key_v1';
  static const String _storageKeyMasterKey = 'quietpaper_master_key_v1';
  static const String _storageKeyTransition =
      'quietpaper_local_key_transition_v1';

  Uint8List? _cachedMasterKey;
  WrappedMasterKeyData? _cachedWrappedData;
  Future<void>? _initialization;
  Future<void>? _localKeyInitialization;
  bool _storageHealthy = false;
  bool _explicitlyLocked = false;
  int _lockRevision = 0;
  String? _deviceKeyCommitment;
  bool _keyTransitionInProgress = false;
  Future<void>? _keyMigration;

  @override
  bool get isUnlocked => !_keyTransitionInProgress && _cachedMasterKey != null;

  @override
  bool get hasKeyData => _cachedWrappedData != null;

  @override
  Uint8List? get cachedMasterKey => isUnlocked ? _cachedMasterKey : null;

  @override
  Uint8List getMasterKey() {
    if (isUnlocked) {
      return _cachedMasterKey!;
    }
    throw StateError('KeyManager is locked. Master key is not in memory.');
  }

  @override
  Future<void> initialize() async {
    final pending = _initialization ??= _loadKeys();
    await pending;
    if (!_storageHealthy && identical(_initialization, pending)) {
      _initialization = null;
    }
  }

  Future<void> _loadKeys() async {
    if (_explicitlyLocked) return;
    final revision = _lockRevision;
    try {
      await _resumeDeviceKeyTransition();
      final results = await Future.wait([
        _storage.read(key: _storageKeyWrappedData),
        _storage.read(key: _storageKeyMasterKey),
      ]);
      if (revision != _lockRevision) return;
      final storedJson = results[0];
      final storedMasterKey = results[1];

      if (storedJson != null) {
        final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
        _cachedWrappedData = WrappedMasterKeyData.fromJson(decoded);
      }
      if (storedMasterKey != null) {
        final bytes = base64Decode(storedMasterKey);
        if (bytes.length != 32) throw const FormatException('Invalid key');
        _cachedMasterKey = Uint8List.fromList(bytes);
        if (_cachedWrappedData == null) {
          _deviceKeyCommitment = _crypto.computeKeyAuthCommitment(bytes);
        }
      }
      _storageHealthy = true;
    } catch (_) {
      // Fail closed: unavailable/corrupt storage must never cause key replacement.
      _storageHealthy = false;
      _cachedWrappedData = null;
      _cachedMasterKey = null;
    }
  }

  @override
  Future<void> ensureLocalKey() async {
    await initialize();
    if (isUnlocked ||
        hasKeyData ||
        _explicitlyLocked ||
        _keyTransitionInProgress) {
      return;
    }
    if (!_storageHealthy) throw StateError('Secure storage is unavailable.');
    final pending = _localKeyInitialization ??= _createLocalKey();
    try {
      await pending;
    } finally {
      if (identical(_localKeyInitialization, pending)) {
        _localKeyInitialization = null;
      }
    }
  }

  Future<void> _createLocalKey() async {
    final revision = _lockRevision;
    final key = await _crypto.generateMasterKey();
    try {
      if (revision != _lockRevision) return;
      // Persist successfully before any importer can encrypt assets with this key.
      await _storage.write(key: _storageKeyMasterKey, value: base64Encode(key));
      if (revision != _lockRevision) return;
      _cachedMasterKey = Uint8List.fromList(key);
      _deviceKeyCommitment = _crypto.computeKeyAuthCommitment(key);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<void> _checkDeviceKey(Uint8List key, WrappedMasterKeyData data) async {
    final previous = _keyMigration;
    if (previous != null) await previous;
    final pending = _checkDeviceKeyImpl(key, data);
    _keyMigration = pending;
    try {
      await pending;
    } catch (_) {
      key.fillRange(0, key.length, 0);
      if (migrateLocalVault == null) rethrow;
      lock();
      throw LocalVaultMigrationException();
    } finally {
      if (identical(_keyMigration, pending)) _keyMigration = null;
    }
  }

  Future<void> _checkDeviceKeyImpl(
    Uint8List key,
    WrappedMasterKeyData data,
  ) async {
    final pending = await _storage.read(key: _storageKeyTransition);
    if (pending != null) {
      final transition = jsonDecode(pending) as Map<String, dynamic>;
      if (transition['newKey'] != base64Encode(key)) {
        key.fillRange(0, key.length, 0);
        throw StateError(
          'Finish the previous vault sign-in before switching accounts.',
        );
      }
      _keyTransitionInProgress = true;
      try {
        await _resumeDeviceKeyTransition();
        _deviceKeyCommitment = null;
        _cachedMasterKey = Uint8List.fromList(key);
        _cachedWrappedData = data;
      } catch (_) {
        key.fillRange(0, key.length, 0);
        lock();
        rethrow;
      } finally {
        _keyTransitionInProgress = false;
      }
    }
    if (_deviceKeyCommitment != null &&
        _crypto.computeKeyAuthCommitment(key) != _deviceKeyCommitment) {
      if (migrateLocalVault == null) {
        key.fillRange(0, key.length, 0);
        throw StateError(
          'The cloud vault uses a different key from local assets.',
        );
      }
      _keyTransitionInProgress = true;
      try {
        // Keep both keys durably until every local ciphertext and the active
        // secure key records are committed. Never overwrite the only old key.
        final localKey = Uint8List.fromList(
          _cachedMasterKey ??
              base64Decode((await _storage.read(key: _storageKeyMasterKey))!),
        );
        try {
          await _storage.write(
            key: _storageKeyTransition,
            value: jsonEncode({
              'oldKey': base64Encode(localKey),
              'newKey': base64Encode(key),
              'wrappedKey': data.toJson(),
            }),
          );
        } finally {
          localKey.fillRange(0, localKey.length, 0);
        }
        await _resumeDeviceKeyTransition();
        _deviceKeyCommitment = null;
        _cachedMasterKey?.fillRange(0, _cachedMasterKey!.length, 0);
        _cachedMasterKey = Uint8List.fromList(key);
        _cachedWrappedData = data;
      } catch (_) {
        key.fillRange(0, key.length, 0);
        lock();
        _initialization = null;
        rethrow;
      } finally {
        _keyTransitionInProgress = false;
      }
    }
  }

  Future<void> _resumeDeviceKeyTransition() async {
    final saved = await _storage.read(key: _storageKeyTransition);
    if (saved == null) return;
    final migrate = migrateLocalVault;
    if (migrate == null) throw StateError('Local vault migration is required.');
    final transition = jsonDecode(saved) as Map<String, dynamic>;
    final oldKey = base64Decode(transition['oldKey'] as String);
    final newKey = base64Decode(transition['newKey'] as String);
    try {
      final data = WrappedMasterKeyData.fromJson(
        transition['wrappedKey'] as Map<String, dynamic>,
      );
      if (oldKey.length != 32 ||
          newKey.length != 32 ||
          (data.keyAuthCommitment != null &&
              data.keyAuthCommitment !=
                  _crypto.computeKeyAuthCommitment(newKey))) {
        throw StateError('Local vault migration key data is invalid.');
      }
      final revision = _lockRevision;
      await migrate(oldKey, newKey);
      if (revision != _lockRevision) {
        throw StateError('Notebook locked during sign-in. Please retry.');
      }
      await _storage.write(
        key: _storageKeyMasterKey,
        value: base64Encode(newKey),
      );
      await _storage.write(
        key: _storageKeyWrappedData,
        value: jsonEncode(data.toJson()),
      );
      if (revision != _lockRevision) {
        throw StateError('Notebook locked during sign-in. Please retry.');
      }
      await _storage.delete(key: _storageKeyTransition);
      if (revision != _lockRevision) {
        throw StateError('Notebook locked during sign-in. Please retry.');
      }
    } finally {
      oldKey.fillRange(0, oldKey.length, 0);
      newKey.fillRange(0, newKey.length, 0);
    }
  }

  @override
  Future<WrappedMasterKeyData> setupNewKeys({
    required String password,
    String? recoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  }) async {
    await initialize();
    await _localKeyInitialization;
    if (!_storageHealthy) throw StateError('Secure storage is unavailable.');
    final masterKey = _cachedMasterKey ?? await _crypto.generateMasterKey();

    // Password derivation & wrap
    final salt = _crypto.generateRandomBytes(16);
    final passwordKey = await _crypto.deriveKeyFromPassword(
      password: password,
      salt: salt,
      parameters: kdfParameters,
    );

    final wrappedEnvelope = await _crypto.wrapMasterKey(
      masterKeyBytes: masterKey,
      wrappingKey: passwordKey,
      keyVersion: 1,
    );

    // Optional recovery key wrap
    String? recoveryWrappedKey;
    String? recoveryNonce;
    String? recoverySalt;
    KdfParameters? recoveryParams;

    if (recoveryKey != null && recoveryKey.trim().isNotEmpty) {
      final recSalt = _crypto.generateRandomBytes(16);
      final recKey = await _crypto.deriveKeyFromRecoveryKey(
        recoveryKey: recoveryKey,
        salt: recSalt,
        parameters: kdfParameters,
      );
      final recEnvelope = await _crypto.wrapMasterKey(
        masterKeyBytes: masterKey,
        wrappingKey: recKey,
        keyVersion: 1,
      );
      recoveryWrappedKey = recEnvelope.ciphertext;
      recoveryNonce = recEnvelope.nonce;
      recoverySalt = base64Encode(recSalt);
      recoveryParams = kdfParameters;
    }

    final data = WrappedMasterKeyData(
      keyVersion: 1,
      wrappedMasterKey: wrappedEnvelope.ciphertext,
      wrappedNonce: wrappedEnvelope.nonce,
      kdfAlgorithm: 'argon2id',
      kdfSalt: base64Encode(salt),
      kdfParameters: kdfParameters,
      encryptionFormatVersion: 1,
      recoveryWrappedMasterKey: recoveryWrappedKey,
      recoveryNonce: recoveryNonce,
      recoverySalt: recoverySalt,
      recoveryParameters: recoveryParams,
      keyAuthCommitment: _crypto.computeKeyAuthCommitment(masterKey),
    );

    await _checkDeviceKey(masterKey, data);
    _explicitlyLocked = false;
    _cachedMasterKey = masterKey;
    try {
      await _storage.write(
        key: _storageKeyMasterKey,
        value: base64Encode(masterKey),
      );
    } catch (_) {}
    await storeWrappedKeyData(data);
    return data;
  }

  @override
  Future<void> unlockWithPassword({
    required String password,
    WrappedMasterKeyData? remoteWrappedKey,
  }) async {
    await initialize();
    await _localKeyInitialization;
    if (!_storageHealthy &&
        await _storage.read(key: _storageKeyTransition) == null) {
      throw StateError(
        'Secure storage is unavailable. Please restart and retry.',
      );
    }
    final data = remoteWrappedKey ?? _cachedWrappedData;
    if (data == null) {
      throw StateError('No wrapped key data found to unlock.');
    }

    final salt = base64Decode(data.kdfSalt);
    final passwordKey = await _crypto.deriveKeyFromPassword(
      password: password,
      salt: salt,
      parameters: data.kdfParameters,
    );

    final masterKey = await _crypto.unwrapMasterKey(
      wrappedMasterKeyBase64: data.wrappedMasterKey,
      nonceBase64: data.wrappedNonce,
      wrappingKey: passwordKey,
    );

    await _checkDeviceKey(masterKey, data);
    _explicitlyLocked = false;
    _cachedMasterKey = masterKey;
    try {
      await _storage.write(
        key: _storageKeyMasterKey,
        value: base64Encode(masterKey),
      );
    } catch (_) {}
    await storeWrappedKeyData(data);
  }

  @override
  Future<void> unlockWithRecoveryKey({
    required String recoveryKey,
    WrappedMasterKeyData? remoteWrappedKey,
  }) async {
    await initialize();
    await _localKeyInitialization;
    if (!_storageHealthy &&
        await _storage.read(key: _storageKeyTransition) == null) {
      throw StateError(
        'Secure storage is unavailable. Please restart and retry.',
      );
    }
    final data = remoteWrappedKey ?? _cachedWrappedData;
    if (data == null ||
        data.recoveryWrappedMasterKey == null ||
        data.recoveryNonce == null ||
        data.recoverySalt == null) {
      throw StateError('No recovery key data found for this account.');
    }

    final salt = base64Decode(data.recoverySalt!);
    final recKey = await _crypto.deriveKeyFromRecoveryKey(
      recoveryKey: recoveryKey,
      salt: salt,
      parameters: data.recoveryParameters ?? data.kdfParameters,
    );

    final masterKey = await _crypto.unwrapMasterKey(
      wrappedMasterKeyBase64: data.recoveryWrappedMasterKey!,
      nonceBase64: data.recoveryNonce!,
      wrappingKey: recKey,
    );

    await _checkDeviceKey(masterKey, data);
    _explicitlyLocked = false;
    _cachedMasterKey = masterKey;
    try {
      await _storage.write(
        key: _storageKeyMasterKey,
        value: base64Encode(masterKey),
      );
    } catch (_) {}
    await storeWrappedKeyData(data);
  }

  @override
  Future<WrappedMasterKeyData> changePassword({
    required String newPassword,
    String? newRecoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  }) async {
    if (!isUnlocked) {
      throw StateError('KeyManager must be unlocked to change password.');
    }

    final masterKey = _cachedMasterKey!;
    final salt = _crypto.generateRandomBytes(16);
    final passwordKey = await _crypto.deriveKeyFromPassword(
      password: newPassword,
      salt: salt,
      parameters: kdfParameters,
    );

    final wrappedEnvelope = await _crypto.wrapMasterKey(
      masterKeyBytes: masterKey,
      wrappingKey: passwordKey,
      keyVersion: (_cachedWrappedData?.keyVersion ?? 1) + 1,
    );

    String? recoveryWrappedKey = _cachedWrappedData?.recoveryWrappedMasterKey;
    String? recoveryNonce = _cachedWrappedData?.recoveryNonce;
    String? recoverySalt = _cachedWrappedData?.recoverySalt;
    KdfParameters? recoveryParams = _cachedWrappedData?.recoveryParameters;

    if (newRecoveryKey != null && newRecoveryKey.trim().isNotEmpty) {
      final recSalt = _crypto.generateRandomBytes(16);
      final recKey = await _crypto.deriveKeyFromRecoveryKey(
        recoveryKey: newRecoveryKey,
        salt: recSalt,
        parameters: kdfParameters,
      );
      final recEnvelope = await _crypto.wrapMasterKey(
        masterKeyBytes: masterKey,
        wrappingKey: recKey,
        keyVersion: wrappedEnvelope.keyVersion,
      );
      recoveryWrappedKey = recEnvelope.ciphertext;
      recoveryNonce = recEnvelope.nonce;
      recoverySalt = base64Encode(recSalt);
      recoveryParams = kdfParameters;
    }

    final updatedData = WrappedMasterKeyData(
      keyVersion: wrappedEnvelope.keyVersion,
      wrappedMasterKey: wrappedEnvelope.ciphertext,
      wrappedNonce: wrappedEnvelope.nonce,
      kdfAlgorithm: 'argon2id',
      kdfSalt: base64Encode(salt),
      kdfParameters: kdfParameters,
      encryptionFormatVersion: 1,
      recoveryWrappedMasterKey: recoveryWrappedKey,
      recoveryNonce: recoveryNonce,
      recoverySalt: recoverySalt,
      recoveryParameters: recoveryParams,
      keyAuthCommitment: _crypto.computeKeyAuthCommitment(masterKey),
    );

    await storeWrappedKeyData(updatedData);
    try {
      await _storage.write(
        key: _storageKeyMasterKey,
        value: base64Encode(masterKey),
      );
    } catch (_) {}
    return updatedData;
  }

  @override
  void lock() {
    _lockRevision++;
    _explicitlyLocked = true;
    AttachmentLocalStorage.purgeAllMemoryCache();
    if (_cachedMasterKey != null) {
      // Clear master key bytes in memory
      _cachedMasterKey!.fillRange(0, _cachedMasterKey!.length, 0);
      _cachedMasterKey = null;
    }
  }

  @override
  Future<void> clearLocalKeys() async {
    lock();
    for (final pending in [
      _initialization,
      _localKeyInitialization,
      _keyMigration,
    ]) {
      try {
        await pending;
      } catch (_) {}
    }
    _deviceKeyCommitment = null;
    _cachedWrappedData = null;
    try {
      await _storage.delete(key: _storageKeyWrappedData);
      await _storage.delete(key: _storageKeyMasterKey);
      await _storage.delete(key: _storageKeyTransition);
    } catch (_) {}
  }

  @override
  Future<WrappedMasterKeyData?> getStoredWrappedKeyData() async {
    if (_cachedWrappedData != null) return _cachedWrappedData;
    await initialize();
    return _cachedWrappedData;
  }

  @override
  Future<void> storeWrappedKeyData(WrappedMasterKeyData data) async {
    _cachedWrappedData = data;
    _deviceKeyCommitment = null;
    try {
      await _storage.write(
        key: _storageKeyWrappedData,
        value: jsonEncode(data.toJson()),
      );
    } catch (_) {}
  }
}
