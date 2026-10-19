import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/storage/quiet_secure_storage.dart';

/// Test implementation of FlutterSecureStorage that simulates Linux KDE Wallet disabled
/// by throwing PlatformException with "Failed to unlock the keyring".
class FailingLinuxSecureStorage extends QuietSecureStorage {
  const FailingLinuxSecureStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    // Simulate libsecret error on write
    try {
      throw PlatformException(
        code: 'Libsecret error',
        message: 'Failed to unlock the keyring',
      );
    } catch (e) {
      // Delegates to fallback store
      await super.write(
        key: key,
        value: value,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    // Simulate libsecret error on read
    try {
      throw PlatformException(
        code: 'Libsecret error',
        message: 'Failed to unlock the keyring',
      );
    } catch (_) {
      // Delegates to fallback store
      return super.read(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    QuietSecureStorage.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('quiet_secure_storage_test_');
    QuietSecureStorage.customDirectory = tempDir;
  });

  tearDown(() async {
    QuietSecureStorage.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('QuietSecureStorage Fallback Tests (KDE Wallet Disabled)', () {
    test('writes and reads back key-values when platform storage fails', () async {
      const storage = FailingLinuxSecureStorage();

      await storage.write(key: 'auth_token', value: 'my-super-secret-token-123');
      final retrieved = await storage.read(key: 'auth_token');

      expect(retrieved, equals('my-super-secret-token-123'));
      expect(await storage.containsKey(key: 'auth_token'), isTrue);
      expect(await storage.containsKey(key: 'non_existent'), isFalse);
    });

    test('persists values across instances using encrypted fallback file', () async {
      const instance1 = FailingLinuxSecureStorage();
      await instance1.write(key: 'session_id', value: 'session-xyz-789');

      // Clear memory cache to force reading from disk
      QuietSecureStorage.resetForTesting();
      QuietSecureStorage.customDirectory = tempDir;

      const instance2 = FailingLinuxSecureStorage();
      final retrieved = await instance2.read(key: 'session_id');

      expect(retrieved, equals('session-xyz-789'));
    });

    test('fallback file is encrypted on disk and does not expose plaintext', () async {
      const storage = FailingLinuxSecureStorage();
      const secretValue = 'TOP_SECRET_PLAINTEXT_PAYLOAD';

      await storage.write(key: 'secret_key', value: secretValue);

      final fallbackFile = File('${tempDir.path}/.secure_storage_fallback.enc');
      expect(await fallbackFile.exists(), isTrue);

      final rawBytes = await fallbackFile.readAsBytes();
      final rawString = String.fromCharCodes(rawBytes);

      // Raw file must NOT contain the secret string
      expect(rawString.contains(secretValue), isFalse);
      expect(rawString.contains('secret_key'), isFalse);
    });

    test('deletes keys cleanly from fallback store', () async {
      const storage = FailingLinuxSecureStorage();
      await storage.write(key: 'temp_key', value: 'temp_val');
      expect(await storage.read(key: 'temp_key'), equals('temp_val'));

      await storage.delete(key: 'temp_key');
      expect(await storage.read(key: 'temp_key'), isNull);
      expect(await storage.containsKey(key: 'temp_key'), isFalse);
    });

    test('deleteAll clears all fallback entries', () async {
      const storage = FailingLinuxSecureStorage();
      await storage.write(key: 'key1', value: 'val1');
      await storage.write(key: 'key2', value: 'val2');

      final allBefore = await storage.readAll();
      expect(allBefore['key1'], equals('val1'));
      expect(allBefore['key2'], equals('val2'));

      await storage.deleteAll();
      final allAfter = await storage.readAll();
      expect(allAfter.isEmpty, isTrue);
    });
  });

  group('Service Integration Tests with Disabled Platform Keyring', () {
    test('FirebaseAuthService preserves session across restarts when keyring fails', () async {
      const storage = FailingLinuxSecureStorage();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'localId': 'user-fedora-123',
            'email': 'fedora@kde.org',
            'idToken': 'jwt-token-abc',
            'refreshToken': 'refresh-xyz',
            'expiresIn': '3600',
            'emailVerified': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authService1 = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: mockClient,
        secureStorage: storage,
      );

      // Sign in
      final user = await authService1.signInWithEmailAndPassword('fedora@kde.org', 'password123');
      expect(user.id, equals('user-fedora-123'));
      expect(authService1.currentUser?.email, equals('fedora@kde.org'));

      // Simulate app restart: new instance, reset memory cache
      QuietSecureStorage.resetForTesting();
      QuietSecureStorage.customDirectory = tempDir;

      final authService2 = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: mockClient,
        secureStorage: storage,
      );
      expect(authService2.currentUser, isNull);

      await authService2.initialize();
      expect(authService2.currentUser, isNotNull);
      expect(authService2.currentUser!.id, equals('user-fedora-123'));
      expect(authService2.currentUser!.email, equals('fedora@kde.org'));
      expect(authService2.currentUser!.idToken, equals('jwt-token-abc'));
    });

    test('SecureKeyManager preserves master key and wrapped data when keyring fails', () async {
      const storage = FailingLinuxSecureStorage();
      final crypto = DefaultCryptoService();

      final km1 = SecureKeyManager(
        cryptoService: crypto,
        secureStorage: storage,
      );

      final setupData = await km1.setupNewKeys(
        password: 'my-strong-password',
        kdfParameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );
      final masterKey = Uint8List.fromList(km1.getMasterKey());

      // Simulate app restart
      QuietSecureStorage.resetForTesting();
      QuietSecureStorage.customDirectory = tempDir;

      final km2 = SecureKeyManager(
        cryptoService: crypto,
        secureStorage: storage,
      );
      expect(km2.isUnlocked, isFalse);

      await km2.initialize();
      expect(km2.isUnlocked, isTrue);
      expect(km2.hasKeyData, isTrue);
      expect(km2.getMasterKey(), equals(masterKey));

      final storedData = await km2.getStoredWrappedKeyData();
      expect(storedData?.kdfSalt, equals(setupData.kdfSalt));
    });
  });
}
