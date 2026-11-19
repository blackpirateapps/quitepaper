import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';

class _Storage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failRead = false, failWrite = false;
  Completer<void>? writeBarrier;
  Completer<void>? readBarrier;
  bool readStarted = false;
  int writes = 0;

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
    readStarted = true;
    await readBarrier?.future;
    if (failRead) throw StateError('Unavailable');
    return values[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

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
    writes++;
    await writeBarrier?.future;
    if (failWrite) throw StateError('Unavailable');
    if (value != null) values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const masterKeyName = 'quietpaper_master_key_v1';
  const wrappedKeyName = 'quietpaper_wrapped_master_key_v1';
  const kdf = KdfParameters(memory: 1024, iterations: 1, parallelism: 1);
  late _Storage storage;
  late SecureKeyManager keys;
  setUp(() {
    storage = _Storage();
    keys = SecureKeyManager(secureStorage: storage);
  });

  test(
    'concurrent offline requests persist one key and restart reuses it',
    () async {
      await Future.wait(List.generate(10, (_) => keys.ensureLocalKey()));
      final key = Uint8List.fromList(keys.getMasterKey());
      expect(storage.writes, 1);
      expect(keys.hasKeyData, isFalse);
      final restarted = SecureKeyManager(secureStorage: storage);
      await restarted.ensureLocalKey();
      expect(restarted.getMasterKey(), orderedEquals(key));
      expect(storage.writes, 1);
    },
  );

  test('cannot encrypt before successful secure storage persistence', () async {
    storage.failWrite = true;
    await expectLater(keys.ensureLocalKey(), throwsStateError);
    expect(keys.isUnlocked, isFalse);
    expect(storage.values, isEmpty);
    storage.failWrite = false;
    await keys.ensureLocalKey();
    expect(keys.isUnlocked, isTrue);
    expect(storage.values[masterKeyName], isNotNull);
  });

  test('unavailable or corrupt storage never replaces existing keys', () async {
    for (final corrupt in [false, true]) {
      storage = _Storage()..failRead = !corrupt;
      storage.values[wrappedKeyName] = 'invalid-json';
      keys = SecureKeyManager(secureStorage: storage);
      await expectLater(keys.ensureLocalKey(), throwsStateError);
      expect(keys.isUnlocked, isFalse);
      expect(storage.writes, 0);
      expect(storage.values[wrappedKeyName], 'invalid-json');
    }
  });

  test(
    'transient read failure can retry without replacing stored keys',
    () async {
      final persisted = base64Encode(List.generate(32, (i) => i));
      storage.values[masterKeyName] = persisted;
      storage.failRead = true;
      await expectLater(keys.ensureLocalKey(), throwsStateError);
      storage.failRead = false;
      await keys.ensureLocalKey();
      expect(keys.getMasterKey(), orderedEquals(base64Decode(persisted)));
      expect(storage.writes, 0);
    },
  );

  test('malformed master key is not replaced', () async {
    storage.values[masterKeyName] = base64Encode([1, 2]);
    await expectLater(keys.ensureLocalKey(), throwsStateError);
    expect(storage.writes, 0);
  });

  test(
    'local initialization cannot unlock an explicitly locked notebook',
    () async {
      await keys.ensureLocalKey();
      final persisted = storage.values[masterKeyName];
      keys.lock();
      await keys.ensureLocalKey();
      await keys.initialize();
      expect(keys.isUnlocked, isFalse);
      expect(storage.values[masterKeyName], persisted);
      expect(storage.writes, 1);
    },
  );

  test(
    'existing wrapped vault without a cached key is never regenerated',
    () async {
      await keys.setupNewKeys(password: 'password', kdfParameters: kdf);
      storage.values.remove(masterKeyName);
      final restarted = SecureKeyManager(secureStorage: storage);
      final writes = storage.writes;
      await restarted.ensureLocalKey();
      expect(restarted.hasKeyData, isTrue);
      expect(restarted.isUnlocked, isFalse);
      expect(storage.writes, writes);
    },
  );

  test(
    'lock during key persistence cannot expose a late unlocked key',
    () async {
      final barrier = Completer<void>();
      storage.writeBarrier = barrier;
      final pending = keys.ensureLocalKey();
      while (storage.writes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      keys.lock();
      barrier.complete();
      await pending;
      expect(keys.isUnlocked, isFalse);
      await keys.ensureLocalKey();
      expect(keys.isUnlocked, isFalse);
    },
  );

  test(
    'lock during startup prevents restoring a persisted key into memory',
    () async {
      storage.values[masterKeyName] = base64Encode(List.generate(32, (i) => i));
      final barrier = Completer<void>();
      storage.readBarrier = barrier;
      final pending = keys.initialize();
      expect(storage.readStarted, isTrue);
      keys.lock();
      barrier.complete();
      await pending;
      await keys.ensureLocalKey();
      expect(keys.isUnlocked, isFalse);
      expect(storage.writes, 0);
    },
  );

  test(
    'clear during local setup removes a late secure storage write',
    () async {
      final barrier = Completer<void>();
      storage.writeBarrier = barrier;
      final pending = keys.ensureLocalKey();
      while (storage.writes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final clearing = keys.clearLocalKeys();
      barrier.complete();
      await Future.wait([pending, clearing]);
      expect(keys.isUnlocked, isFalse);
      expect(storage.values, isEmpty);
    },
  );

  test(
    'new cloud setup wraps the local key without rotating encrypted assets',
    () async {
      await keys.ensureLocalKey();
      final localKey = Uint8List.fromList(keys.getMasterKey());
      await keys.setupNewKeys(password: 'password', kdfParameters: kdf);
      keys.lock();
      await keys.unlockWithPassword(password: 'password');
      expect(keys.getMasterKey(), orderedEquals(localKey));
    },
  );

  test('different cloud vault cannot overwrite a device-only key', () async {
    final other = SecureKeyManager(secureStorage: _Storage());
    final remote = await other.setupNewKeys(
      password: 'remote-password',
      recoveryKey: 'recovery',
      kdfParameters: kdf,
    );
    await keys.ensureLocalKey();
    final localKey = Uint8List.fromList(keys.getMasterKey());
    final persisted = storage.values[masterKeyName];
    await expectLater(
      keys.unlockWithPassword(
        password: 'remote-password',
        remoteWrappedKey: remote,
      ),
      throwsStateError,
    );
    await expectLater(
      keys.unlockWithRecoveryKey(
        recoveryKey: 'recovery',
        remoteWrappedKey: remote,
      ),
      throwsStateError,
    );
    expect(keys.getMasterKey(), orderedEquals(localKey));
    expect(storage.values[masterKeyName], persisted);
    expect(storage.values[wrappedKeyName], isNull);
  });
}
