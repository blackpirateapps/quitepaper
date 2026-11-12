import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_credentials.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('qp-credentials-test-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<void> store(Map<String, String> entries) async {
    final salt = List<int>.filled(32, 7);
    await File('${root.path}/.secure_storage_key').writeAsBytes(salt);
    final machine = (await File('/etc/machine-id').readAsString()).trim();
    final key = SecretKey(
      sha256.convert([
        ...salt,
        ...utf8.encode(machine),
        ...utf8.encode(Platform.environment['USER'] ?? ''),
      ]).bytes,
    );
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(entries)),
      secretKey: key,
    );
    await File(
      '${root.path}/.secure_storage_fallback.enc',
    ).writeAsBytes(box.concatenation());
  }

  test('reads desktop encrypted fallback without modifying it', () async {
    final master = Uint8List.fromList(List<int>.filled(32, 8));
    await store({'quietpaper_master_key_v1': base64Encode(master)});
    final before = await File(
      '${root.path}/.secure_storage_fallback.enc',
    ).readAsBytes();
    final credentials = CliCredentials(root, useKeyring: false);
    expect(await credentials.masterKey(), master);
    credentials.clear();
    expect(
      await File('${root.path}/.secure_storage_fallback.enc').readAsBytes(),
      before,
    );
  });
  test(
    'password unwrap is compatible and rejects incorrect passwords',
    () async {
      final crypto = DefaultCryptoService();
      final master = Uint8List.fromList(List<int>.filled(32, 9));
      final salt = Uint8List.fromList(List<int>.filled(16, 4));
      const parameters = KdfParameters(memory: 32, iterations: 1);
      final key = await crypto.deriveKeyFromPassword(
        password: 'correct',
        salt: salt,
        parameters: parameters,
      );
      final envelope = await crypto.wrapMasterKey(
        masterKeyBytes: master,
        wrappingKey: key,
      );
      final wrapped = WrappedMasterKeyData(
        keyVersion: 1,
        wrappedMasterKey: envelope.ciphertext,
        wrappedNonce: envelope.nonce,
        kdfAlgorithm: 'argon2id',
        kdfSalt: base64Encode(salt),
        kdfParameters: parameters,
        encryptionFormatVersion: 1,
      );
      await store({
        'quietpaper_wrapped_master_key_v1': jsonEncode(wrapped.toJson()),
      });
      final credentials = CliCredentials(
        root,
        useKeyring: false,
        passwordPrompt: () => 'correct',
      );
      expect(await credentials.masterKey(), master);
      await expectLater(
        CliCredentials(
          root,
          useKeyring: false,
          passwordPrompt: () => 'wrong',
        ).masterKey(),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
}
