import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/attachments/attachment_type_resolver.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Attachment & Crypto Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late AttachmentLocalStorage storage;
    late MockKeyManager keyManager;
    late AttachmentService attachmentService;
    late AttachmentCrypto attachmentCrypto;
    late CryptoService cryptoService;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_audio_att_');
      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);
      attachmentCrypto = AttachmentCrypto(cryptoService: cryptoService);

      attachmentService = AttachmentService(
        database: database,
        keyManager: keyManager,
        crypto: attachmentCrypto,
        storage: storage,
      );
    });

    tearDown(() async {
      await database.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('importAudioRecording encrypts audio with QPA1 and keeps user title private', () async {
      final sampleAudio = Uint8List.fromList(List<int>.generate(512, (i) => (i * 7) % 256));
      final tempAudioFile = File('${tempDir.path}/temp_sample.m4a');
      await tempAudioFile.writeAsBytes(sampleAudio);

      const userTitle = 'Morning Reflection: Thoughts on Architecture';
      final result = await attachmentService.importAudioRecording(
        file: tempAudioFile,
        userTitle: userTitle,
        noteId: 'note-journal-1',
      );

      final entity = result.attachment;

      // 1. Technical neutral name in DB/metadata
      expect(entity.fileName, startsWith('recording_'));
      expect(entity.fileName, endsWith('.m4a'));
      expect(entity.mimeType, equals('audio/mp4'));
      expect(entity.kind, equals('file'));
      expect(entity.ocrState, equals('not_requested')); // Audio never triggers OCR

      // 2. Markdown snippet contains the user-facing title
      expect(result.markdownSnippet, equals('[$userTitle](qp://asset/${entity.id})'));

      // 3. Stored file on disk is encrypted with QPA1 magic bytes
      final hasFile = await storage.hasEncryptedFile(attachmentId: entity.id);
      expect(hasFile, isTrue);
      final encryptedBytes = await storage.readEncryptedBytes(attachmentId: entity.id);
      expect(encryptedBytes, isNotNull);
      expect(encryptedBytes!.length, greaterThan(sampleAudio.length));
      expect(encryptedBytes.sublist(0, 4), equals(AttachmentCrypto.magicBytes));

      // 4. Decrypted cache reproduces original audio bytes
      final decrypted = attachmentService.getDecryptedCache(entity.id);
      expect(decrypted, equals(sampleAudio));
    });

    test('importAudioRecording with WAV file produces audio/wav MIME type', () async {
      final sampleAudio = Uint8List.fromList(List<int>.generate(256, (i) => i % 256));
      final tempAudioFile = File('${tempDir.path}/temp_sample.wav');
      await tempAudioFile.writeAsBytes(sampleAudio);

      final result = await attachmentService.importAudioRecording(
        file: tempAudioFile,
        userTitle: 'Interview Memo',
      );

      expect(result.attachment.mimeType, equals('audio/wav'));
      expect(result.attachment.fileName, endsWith('.wav'));
    });

    test('Tampered audio ciphertext throws AttachmentDecryptionException', () async {
      final sampleAudio = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final encrypted = await attachmentCrypto.encryptAttachment(
        plaintextBytes: sampleAudio,
        masterKeyBytes: keyManager.masterKey,
        attachmentId: 'att-audio-tamper',
      );

      // Tamper ciphertext payload
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => attachmentCrypto.decryptAttachment(
          encryptedEnvelopeBytes: tampered,
          masterKeyBytes: keyManager.masterKey,
          attachmentId: 'att-audio-tamper',
        ),
        throwsA(isA<AttachmentDecryptionException>()),
      );
    });

    test('AttachmentTypeResolver correctly identifies audio files and MIME types', () {
      expect(AttachmentTypeResolver.isAudio('audio/mp4', 'recording_123.m4a'), isTrue);
      expect(AttachmentTypeResolver.isAudio('audio/wav', 'voice.wav'), isTrue);
      expect(AttachmentTypeResolver.isAudio('audio/aac', 'memo.aac'), isTrue);
      expect(AttachmentTypeResolver.isAudio('audio/mpeg', 'song.mp3'), isTrue);
      expect(AttachmentTypeResolver.isAudio(null, 'memo.m4a'), isTrue);
      expect(AttachmentTypeResolver.isAudio(null, 'memo.wav'), isTrue);
      expect(AttachmentTypeResolver.isAudio(null, 'memo.aac'), isTrue);
      expect(AttachmentTypeResolver.isAudio(null, 'memo.mp3'), isTrue);
      expect(AttachmentTypeResolver.isAudio(null, 'memo.flac'), isTrue);

      expect(AttachmentTypeResolver.isAudio('image/png', 'photo.png'), isFalse);
      expect(AttachmentTypeResolver.isAudio('application/pdf', 'doc.pdf'), isFalse);
      expect(AttachmentTypeResolver.isAudio(null, 'file.txt'), isFalse);
    });
  });
}
