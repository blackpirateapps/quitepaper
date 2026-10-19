import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import 'app_storage_path_resolver.dart';

/// Resilient implementation of [FlutterSecureStorage] that seamlessly falls
/// back to an encrypted, device-bound local store when the platform's secret
/// service (e.g. KDE Wallet or GNOME Keyring on Linux) is disabled or locked.
class QuietSecureStorage extends FlutterSecureStorage {
  const QuietSecureStorage({
    super.iOptions,
    super.aOptions = const AndroidOptions(encryptedSharedPreferences: true),
    super.lOptions,
    super.wOptions,
    super.webOptions,
    super.mOptions,
  });

  @visibleForTesting
  static Directory? customDirectory;

  static bool? _isPlatformStorageAvailable;
  static Map<String, String>? _fallbackCache;
  static Future<void> _lock = Future.value();

  @visibleForTesting
  static void resetForTesting() {
    _fallbackCache = null;
    _isPlatformStorageAvailable = null;
    customDirectory = null;
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
    if (value == null) {
      await delete(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
      return;
    }

    if (_isPlatformStorageAvailable != false) {
      try {
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
        _isPlatformStorageAvailable = true;
        // If platform storage succeeded, clean up any previous fallback entry
        await _removeFallbackKey(key);
        return;
      } catch (e) {
        _isPlatformStorageAvailable = false;
        debugPrint(
          '[QuietSecureStorage] Platform secure storage write failed for key "$key": $e. '
          'Persisting to encrypted fallback storage.',
        );
      }
    }

    await _writeFallbackKey(key, value);
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
    if (_isPlatformStorageAvailable != false) {
      try {
        final val = await super.read(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
        _isPlatformStorageAvailable = true;
        if (val != null) {
          return val;
        }
      } catch (e) {
        _isPlatformStorageAvailable = false;
        debugPrint(
          '[QuietSecureStorage] Platform secure storage read failed for key "$key": $e. '
          'Checking encrypted fallback storage.',
        );
      }
    }

    return _readFallbackKey(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_isPlatformStorageAvailable != false) {
      try {
        final exists = await super.containsKey(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
        _isPlatformStorageAvailable = true;
        if (exists) return true;
      } catch (_) {
        _isPlatformStorageAvailable = false;
      }
    }

    return _containsFallbackKey(key);
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
    if (_isPlatformStorageAvailable != false) {
      try {
        await super.delete(
          key: key,
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
      } catch (_) {
        _isPlatformStorageAvailable = false;
      }
    }

    await _removeFallbackKey(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_isPlatformStorageAvailable != false) {
      try {
        await super.deleteAll(
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
      } catch (_) {
        _isPlatformStorageAvailable = false;
      }
    }

    await _clearFallback();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final results = <String, String>{};
    if (_isPlatformStorageAvailable != false) {
      try {
        final platformEntries = await super.readAll(
          iOptions: iOptions,
          aOptions: aOptions,
          lOptions: lOptions,
          webOptions: webOptions,
          mOptions: mOptions,
          wOptions: wOptions,
        );
        _isPlatformStorageAvailable = true;
        results.addAll(platformEntries);
      } catch (_) {
        _isPlatformStorageAvailable = false;
      }
    }

    final fallbackEntries = await _getAllFallback();
    for (final entry in fallbackEntries.entries) {
      results.putIfAbsent(entry.key, () => entry.value);
    }

    return results;
  }

  static Future<Directory> _resolveDirectory() async {
    if (customDirectory != null) return customDirectory!;
    try {
      return await AppStoragePathResolver.getDataDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<SecretKey> _getOrCreateEncryptionKey(Directory dir) async {
    final keyFile = File(p.join(dir.path, '.secure_storage_key'));
    Uint8List rawSalt;
    if (await keyFile.exists()) {
      try {
        final readBytes = await keyFile.readAsBytes();
        if (readBytes.length == 32) {
          rawSalt = readBytes;
        } else {
          rawSalt = _generateRandomBytes(32);
          await keyFile.writeAsBytes(rawSalt, flush: true);
        }
      } catch (_) {
        rawSalt = _generateRandomBytes(32);
      }
    } else {
      rawSalt = _generateRandomBytes(32);
      try {
        await keyFile.writeAsBytes(rawSalt, flush: true);
        if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
          await Process.run('chmod', ['600', keyFile.path]);
        }
      } catch (_) {}
    }

    String machineId = '';
    if (!kIsWeb && Platform.isLinux) {
      for (final candidate in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
        final f = File(candidate);
        if (f.existsSync()) {
          try {
            machineId = f.readAsStringSync().trim();
            if (machineId.isNotEmpty) break;
          } catch (_) {}
        }
      }
    }
    final user = !kIsWeb ? (Platform.environment['USER'] ?? '') : '';
    final combined = sha256.convert([...rawSalt, ...utf8.encode(machineId), ...utf8.encode(user)]).bytes;
    return SecretKey(combined);
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  static Future<Map<String, String>> _loadFallbackCache() async {
    if (_fallbackCache != null) return _fallbackCache!;
    final dir = await _resolveDirectory();
    final fallbackFile = File(p.join(dir.path, '.secure_storage_fallback.enc'));
    if (!await fallbackFile.exists()) {
      _fallbackCache = <String, String>{};
      return _fallbackCache!;
    }

    try {
      final cipherBytes = await fallbackFile.readAsBytes();
      if (cipherBytes.isEmpty) {
        _fallbackCache = <String, String>{};
        return _fallbackCache!;
      }

      final key = await _getOrCreateEncryptionKey(dir);
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox.fromConcatenation(
        cipherBytes,
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength,
      );
      final decrypted = await algorithm.decrypt(secretBox, secretKey: key);
      final decodedJson = jsonDecode(utf8.decode(decrypted));
      if (decodedJson is Map) {
        _fallbackCache = decodedJson.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      } else {
        _fallbackCache = <String, String>{};
      }
    } catch (e) {
      debugPrint('[QuietSecureStorage] Failed to decrypt fallback store ($e). Initializing empty.');
      _fallbackCache = <String, String>{};
    }

    return _fallbackCache!;
  }

  static Future<void> _persistFallbackCache() async {
    final cache = _fallbackCache ?? <String, String>{};
    final dir = await _resolveDirectory();
    final fallbackFile = File(p.join(dir.path, '.secure_storage_fallback.enc'));
    final tempFile = File(p.join(dir.path, '.secure_storage_fallback.enc.tmp'));

    try {
      final key = await _getOrCreateEncryptionKey(dir);
      final algorithm = AesGcm.with256bits();
      final plaintext = utf8.encode(jsonEncode(cache));
      final secretBox = await algorithm.encrypt(plaintext, secretKey: key);
      final encryptedBytes = secretBox.concatenation();

      await tempFile.writeAsBytes(encryptedBytes, flush: true);
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
        await Process.run('chmod', ['600', tempFile.path]);
      }
      await tempFile.rename(fallbackFile.path);
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
        await Process.run('chmod', ['600', fallbackFile.path]);
      }
    } catch (e) {
      debugPrint('[QuietSecureStorage] Failed to persist fallback store: $e');
    }
  }

  static Future<void> _writeFallbackKey(String key, String value) async {
    await _enqueue(() async {
      final cache = await _loadFallbackCache();
      cache[key] = value;
      await _persistFallbackCache();
    });
  }

  static Future<String?> _readFallbackKey(String key) async {
    return _enqueue(() async {
      final cache = await _loadFallbackCache();
      return cache[key];
    });
  }

  static Future<bool> _containsFallbackKey(String key) async {
    return _enqueue(() async {
      final cache = await _loadFallbackCache();
      return cache.containsKey(key);
    });
  }

  static Future<void> _removeFallbackKey(String key) async {
    await _enqueue(() async {
      final cache = await _loadFallbackCache();
      if (cache.containsKey(key)) {
        cache.remove(key);
        await _persistFallbackCache();
      }
    });
  }

  static Future<void> _clearFallback() async {
    await _enqueue(() async {
      final cache = await _loadFallbackCache();
      cache.clear();
      await _persistFallbackCache();
    });
  }

  static Future<Map<String, String>> _getAllFallback() async {
    return _enqueue(() async {
      final cache = await _loadFallbackCache();
      return Map<String, String>.from(cache);
    });
  }

  static Future<T> _enqueue<T>(Future<T> Function() action) async {
    final prev = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await prev;
      return await action();
    } finally {
      completer.complete();
    }
  }
}
