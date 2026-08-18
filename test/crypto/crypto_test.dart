import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';

void main() {
  group('CryptoService Unit Tests', () {
    late DefaultCryptoService crypto;

    setUp(() {
      crypto = DefaultCryptoService();
    });

    test('Generates 32-byte secure random Master Key', () async {
      final masterKey = await crypto.generateMasterKey();
      expect(masterKey.length, 32);

      final secondKey = await crypto.generateMasterKey();
      expect(secondKey.length, 32);
      expect(masterKey, isNot(equals(secondKey)));
    });

    test('Wraps and unwraps Master Key with Argon2id derived key', () async {
      final masterKey = await crypto.generateMasterKey();
      final salt = crypto.generateRandomBytes(16);
      const password = 'QuietPaper-Master-Password-!@#123';

      final wrappingKey = await crypto.deriveKeyFromPassword(
        password: password,
        salt: salt,
        parameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );

      final envelope = await crypto.wrapMasterKey(
        masterKeyBytes: masterKey,
        wrappingKey: wrappingKey,
        keyVersion: 1,
      );

      expect(envelope.version, 1);
      expect(envelope.algorithm, 'xchacha20-poly1305');
      expect(envelope.ciphertext.isNotEmpty, true);
      expect(envelope.nonce.isNotEmpty, true);

      // Successfully unwrap
      final unwrapped = await crypto.unwrapMasterKey(
        wrappedMasterKeyBase64: envelope.ciphertext,
        nonceBase64: envelope.nonce,
        wrappingKey: wrappingKey,
      );
      expect(unwrapped, equals(masterKey));
    });

    test('Unwrapping with wrong password throws DecryptionException / MacValidationException', () async {
      final masterKey = await crypto.generateMasterKey();
      final salt = crypto.generateRandomBytes(16);

      final rightWrappingKey = await crypto.deriveKeyFromPassword(
        password: 'correct-password',
        salt: salt,
        parameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );

      final wrongWrappingKey = await crypto.deriveKeyFromPassword(
        password: 'wrong-password',
        salt: salt,
        parameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );

      final envelope = await crypto.wrapMasterKey(
        masterKeyBytes: masterKey,
        wrappingKey: rightWrappingKey,
      );

      expect(
        () async => await crypto.unwrapMasterKey(
          wrappedMasterKeyBase64: envelope.ciphertext,
          nonceBase64: envelope.nonce,
          wrappingKey: wrongWrappingKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Encrypts and decrypts note with authenticated associated data', () async {
      final masterKey = await crypto.generateMasterKey();
      const noteId = 'note-uuid-12345';
      const plaintext = NotePlaintext(
        title: 'Project Quantum',
        body: 'Top secret architectural details.\nNever transmit plaintext.',
        tags: ['secret', 'architecture', 'v1'],
      );

      final envelope = await crypto.encryptNote(
        plaintext: plaintext,
        masterKeyBytes: masterKey,
        noteId: noteId,
      );

      expect(envelope.version, 1);
      expect(envelope.ciphertext.isNotEmpty, true);
      expect(envelope.nonce.isNotEmpty, true);

      // Decrypt successfully
      final decrypted = await crypto.decryptNote(
        envelope: envelope,
        masterKeyBytes: masterKey,
        noteId: noteId,
      );

      expect(decrypted.title, 'Project Quantum');
      expect(decrypted.body, 'Top secret architectural details.\nNever transmit plaintext.');
      expect(decrypted.tags, ['secret', 'architecture', 'v1']);
    });

    test('Decryption fails if noteId in associated data does not match', () async {
      final masterKey = await crypto.generateMasterKey();
      const originalNoteId = 'note-uuid-original';
      const attackerNoteId = 'note-uuid-swapped';

      const plaintext = NotePlaintext(
        title: 'Secret',
        body: 'Body',
        tags: ['tag'],
      );

      final envelope = await crypto.encryptNote(
        plaintext: plaintext,
        masterKeyBytes: masterKey,
        noteId: originalNoteId,
      );

      expect(
        () async => await crypto.decryptNote(
          envelope: envelope,
          masterKeyBytes: masterKey,
          noteId: attackerNoteId,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Decryption fails if ciphertext is tampered', () async {
      final masterKey = await crypto.generateMasterKey();
      const noteId = 'note-123';
      const plaintext = NotePlaintext(
        title: 'Secret',
        body: 'Body',
        tags: [],
      );

      final envelope = await crypto.encryptNote(
        plaintext: plaintext,
        masterKeyBytes: masterKey,
        noteId: noteId,
      );

      final rawCipher = base64Decode(envelope.ciphertext);
      rawCipher[0] ^= 0xFF; // flip bits

      final tamperedEnvelope = EncryptedEnvelope(
        version: envelope.version,
        algorithm: envelope.algorithm,
        keyVersion: envelope.keyVersion,
        nonce: envelope.nonce,
        ciphertext: base64Encode(rawCipher),
      );

      expect(
        () async => await crypto.decryptNote(
          envelope: tamperedEnvelope,
          masterKeyBytes: masterKey,
          noteId: noteId,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Recovery key generation, wrapping, unwrapping and normalization', () async {
      final recKey = crypto.generateRecoveryKey();
      expect(recKey.startsWith('qp-'), true);

      final normalized = crypto.normalizeRecoveryKey(recKey);
      expect(normalized.length, 64); // 32 hex bytes = 64 characters

      final masterKey = await crypto.generateMasterKey();
      final salt = crypto.generateRandomBytes(16);

      final recoveryWrappingKey = await crypto.deriveKeyFromRecoveryKey(
        recoveryKey: recKey,
        salt: salt,
        parameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );

      final envelope = await crypto.wrapMasterKey(
        masterKeyBytes: masterKey,
        wrappingKey: recoveryWrappingKey,
      );

      final unwrapped = await crypto.unwrapMasterKey(
        wrappedMasterKeyBase64: envelope.ciphertext,
        nonceBase64: envelope.nonce,
        wrappingKey: recoveryWrappingKey,
      );

      expect(unwrapped, equals(masterKey));
    });
  });

  group('KeyManager & Password Rotation Tests', () {
    late SecureKeyManager keyManager;
    late Map<String, String> mockSecureStore;

    setUp(() {
      mockSecureStore = {};
      FlutterSecureStorage.setMockInitialValues(mockSecureStore);
      keyManager = SecureKeyManager();
    });

    test('setupNewKeys, lock, and unlockWithPassword flow', () async {
      const password = 'my-super-secret-password-1';
      final wrappedData = await keyManager.setupNewKeys(
        password: password,
        kdfParameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
      );

      expect(keyManager.isUnlocked, true);
      final originalMasterKey = Uint8List.fromList(keyManager.getMasterKey());

      // Lock
      keyManager.lock();
      expect(keyManager.isUnlocked, false);
      expect(() => keyManager.getMasterKey(), throwsStateError);

      // Unlock
      await keyManager.unlockWithPassword(
        password: password,
        remoteWrappedKey: wrappedData,
      );
      expect(keyManager.isUnlocked, true);
      expect(keyManager.getMasterKey(), equals(originalMasterKey));
    });

    test('changePassword re-wraps master key and preserves note decryptability', () async {
      const oldPassword = 'old-password-123';
      const newPassword = 'new-password-456';
      const kdf = KdfParameters(memory: 1024, iterations: 1, parallelism: 1);

      await keyManager.setupNewKeys(
        password: oldPassword,
        kdfParameters: kdf,
      );

      final masterKey = Uint8List.fromList(keyManager.getMasterKey());
      final crypto = DefaultCryptoService();

      // Encrypt note with current master key
      const note = NotePlaintext(
        title: 'Preserved note',
        body: 'This must still decrypt after password change!',
        tags: ['persist'],
      );
      final envelope = await crypto.encryptNote(
        plaintext: note,
        masterKeyBytes: masterKey,
        noteId: 'note-preserve-1',
      );

      // Change encryption password
      final newWrappedData = await keyManager.changePassword(
        newPassword: newPassword,
        kdfParameters: kdf,
      );

      expect(newWrappedData.keyVersion, 2);

      // Lock and unlock with NEW password
      keyManager.lock();
      expect(keyManager.isUnlocked, false);

      await keyManager.unlockWithPassword(
        password: newPassword,
        remoteWrappedKey: newWrappedData,
      );
      expect(keyManager.isUnlocked, true);
      expect(keyManager.getMasterKey(), equals(masterKey));

      // Decrypt note ciphertext using master key from unlocked new password
      final decrypted = await crypto.decryptNote(
        envelope: envelope,
        masterKeyBytes: keyManager.getMasterKey(),
        noteId: 'note-preserve-1',
      );
      expect(decrypted.title, 'Preserved note');
      expect(decrypted.body, 'This must still decrypt after password change!');
    });

    test('Recovery key unlocks master key and allows setting new password', () async {
      const originalPassword = 'forgotten-password';
      const kdf = KdfParameters(memory: 1024, iterations: 1, parallelism: 1);

      final crypto = DefaultCryptoService();
      final recoveryKey = crypto.generateRecoveryKey();

      final wrappedData = await keyManager.setupNewKeys(
        password: originalPassword,
        recoveryKey: recoveryKey,
        kdfParameters: kdf,
      );

      final originalMasterKey = Uint8List.fromList(keyManager.getMasterKey());

      // User forgot password -> lock
      keyManager.lock();

      // Unlock using recovery key
      await keyManager.unlockWithRecoveryKey(
        recoveryKey: recoveryKey,
        remoteWrappedKey: wrappedData,
      );
      expect(keyManager.isUnlocked, true);
      expect(keyManager.getMasterKey(), equals(originalMasterKey));

      // Set new password
      const newPassword = 'recovered-new-password';
      final updatedData = await keyManager.changePassword(
        newPassword: newPassword,
        kdfParameters: kdf,
      );

      keyManager.lock();

      // Unlock with new password
      await keyManager.unlockWithPassword(
        password: newPassword,
        remoteWrappedKey: updatedData,
      );
      expect(keyManager.isUnlocked, true);
      expect(keyManager.getMasterKey(), equals(originalMasterKey));
    });
  });
}
