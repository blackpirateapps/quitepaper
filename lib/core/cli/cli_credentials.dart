import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import '../crypto/crypto_service.dart';

/// Read-only access to the same Linux credentials used by the desktop app.
/// Never writes refreshed credentials over a concurrently running GUI session.
class CliCredentials {
  CliCredentials(this.directory, {this.useKeyring = true, this.passwordPrompt});

  final Directory directory;
  final bool useKeyring;
  final String Function()? passwordPrompt;
  Map<String, String>? _entries;
  Uint8List? _masterKey;

  Future<Map<String, String>> read() async {
    if (_entries != null) return _entries!;
    final entries = <String, String>{};
    if (useKeyring) {
      try {
        final process = await Process.start('secret-tool', [
          'lookup',
          'account',
          'com.blackpiratex.quietpaper.secureStorage',
        ]);
        final output = process.stdout.transform(utf8.decoder).join();
        final errors = process.stderr.drain<void>();
        final code = await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill();
            return -1;
          },
        );
        if (code == 0) {
          entries.addAll(
            Map<String, String>.from(jsonDecode(await output) as Map),
          );
        }
        await errors;
      } on ProcessException catch (_) {
        // secret-tool is optional when the app uses its encrypted fallback.
      } on FormatException catch (_) {
        // An unavailable/locked keyring can return an empty response.
      }
    }
    final store = File('${directory.path}/.secure_storage_fallback.enc');
    final salt = File('${directory.path}/.secure_storage_key');
    if (await store.exists() && await salt.exists()) {
      var machineId = '';
      for (final path in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
        final file = File(path);
        if (await file.exists()) {
          machineId = (await file.readAsString()).trim();
          if (machineId.isNotEmpty) break;
        }
      }
      final key = SecretKey(
        sha256.convert([
          ...await salt.readAsBytes(),
          ...utf8.encode(machineId),
          ...utf8.encode(Platform.environment['USER'] ?? ''),
        ]).bytes,
      );
      final algorithm = AesGcm.with256bits();
      final box = SecretBox.fromConcatenation(
        await store.readAsBytes(),
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength,
      );
      final decoded =
          jsonDecode(utf8.decode(await algorithm.decrypt(box, secretKey: key)))
              as Map;
      for (final entry in decoded.entries) {
        entries.putIfAbsent(entry.key.toString(), () => entry.value.toString());
      }
    }
    _entries = entries;
    return entries;
  }

  Future<Uint8List> masterKey() async {
    if (_masterKey != null) return _masterKey!;
    final entries = await read();
    final stored = entries['quietpaper_master_key_v1'];
    if (stored != null) {
      final bytes = base64Decode(stored);
      if (bytes.length != 32) {
        throw StateError('Invalid stored encryption key.');
      }
      return _masterKey = bytes;
    }
    final wrapped = entries['quietpaper_wrapped_master_key_v1'];
    if (wrapped == null) {
      throw StateError(
        'Encryption credentials unavailable. Unlock the Linux keyring '
        '(secret-tool is required for keyring access), or initialize this notebook in Quiet Paper.',
      );
    }
    final data = WrappedMasterKeyData.fromJson(
      jsonDecode(wrapped) as Map<String, dynamic>,
    );
    final password = (passwordPrompt ?? promptPassword)();
    final crypto = DefaultCryptoService();
    final wrappingKey = await crypto.deriveKeyFromPassword(
      password: password,
      salt: base64Decode(data.kdfSalt),
      parameters: data.kdfParameters,
    );
    return _masterKey = await crypto.unwrapMasterKey(
      wrappedMasterKeyBase64: data.wrappedMasterKey,
      nonceBase64: data.wrappedNonce,
      wrappingKey: wrappingKey,
    );
  }

  static String promptPassword() {
    if (!stdin.hasTerminal) {
      throw StateError(
        'Encryption keys are locked. Run interactively to enter your encryption password.',
      );
    }
    stderr.write('Encryption password: ');
    final echo = stdin.echoMode;
    try {
      stdin.echoMode = false;
      final password = stdin.readLineSync();
      if (password == null || password.isEmpty) {
        throw StateError('Unlock cancelled.');
      }
      return password;
    } finally {
      stdin.echoMode = echo;
      stderr.writeln();
    }
  }

  void clear() {
    _masterKey?.fillRange(0, _masterKey!.length, 0);
    _masterKey = null;
    _entries = null;
  }
}
