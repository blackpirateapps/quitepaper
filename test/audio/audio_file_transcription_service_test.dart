import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_file_transcription_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/speech/application/speech_model_manager.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/domain/speech_recognition_engine.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_downloader.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';

class FakeKeyManager implements KeyManager {
  FakeKeyManager({required this.masterKey, this.isUnlocked = true});

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
  void lock() => isUnlocked = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecognitionEngine implements SpeechRecognitionEngine {
  bool loaded = false;
  String? lastAudioPath;
  String? lastLang;
  String returnText = 'I am reflecting on today.';

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> initialize({required String modelPath}) async {
    loaded = true;
  }

  @override
  Future<String> transcribe({
    required String audioPath,
    String lang = 'en',
    void Function(int percent)? onProgress,
  }) async {
    lastAudioPath = audioPath;
    lastLang = lang;
    onProgress?.call(50);
    onProgress?.call(100);
    return returnText;
  }

  @override
  Future<void> dispose() async {
    loaded = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFileTranscriptionService Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late Directory transcriptionTempDir;
    late AttachmentLocalStorage storage;
    late FakeKeyManager keyManager;
    late AttachmentService attachmentService;
    late SpeechStorageService speechStorage;
    late SpeechModelManager speechModelManager;
    late FakeRecognitionEngine fakeEngine;
    late AudioFileTranscriptionService service;

    const descriptor = FutoEnglishSpeechModel();

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_transcribe_');
      transcriptionTempDir =
          await Directory.systemTemp.createTemp('qp_test_transcribe_work_');

      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = FakeKeyManager(masterKey: masterKey, isUnlocked: true);

      attachmentService = AttachmentService(
        database: database,
        keyManager: keyManager,
        crypto: AttachmentCrypto(cryptoService: cryptoService),
        storage: storage,
      );

      final speechDir = Directory('${tempDir.path}/speech');
      final speechAudioDir = Directory('${tempDir.path}/speech_audio');
      await speechDir.create(recursive: true);
      await speechAudioDir.create(recursive: true);

      speechStorage = SpeechStorageService(
        baseDirectory: speechDir,
        temporaryDirectory: speechAudioDir,
      );

      // Pre-install model with fast truncate
      final modelFile = await speechStorage.getModelFile(descriptor);
      final raf = await modelFile.open(mode: FileMode.write);
      await raf.truncate(descriptor.sizeBytes);
      await raf.close();

      final metadata = SpeechModelMetadata(
        modelId: descriptor.id,
        version: descriptor.version,
        filename: descriptor.filename,
        sizeBytes: descriptor.sizeBytes,
        sha256: descriptor.expectedSha256,
        installedAt: DateTime.now(),
      );
      await speechStorage.saveMetadata(metadata);

      speechModelManager = SpeechModelManager(
        descriptor: descriptor,
        storageService: speechStorage,
        downloader: SpeechDownloader(storageService: speechStorage),
      );

      fakeEngine = FakeRecognitionEngine();

      service = AudioFileTranscriptionService(
        attachmentService: attachmentService,
        speechModelManager: speechModelManager,
        speechEngine: fakeEngine,
        customTempDirectory: transcriptionTempDir,
      );
    });

    tearDown(() async {
      service.dispose();
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await transcriptionTempDir.exists()) {
        await transcriptionTempDir.delete(recursive: true);
      }
    });

    test('transcribes WAV audio attachment successfully', () async {
      // 1. Create a dummy WAV file
      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(Uint8List.fromList(List.filled(500, 42)));

      final imported = await attachmentService.importAudioRecording(
        file: audioFile,
        userTitle: 'Morning Reflection',
        noteId: 'note-1',
      );

      final result = await service.transcribeAttachment(
        attachmentId: imported.attachment.id,
      );

      expect(result, isNotNull);
      expect(result!.text, equals('I am reflecting on today.'));
      expect(result.language, equals('en'));
      expect(result.isEdited, isFalse);

      // Verify original attachment ciphertext is intact
      final reloaded = await database.getAttachment(imported.attachment.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.id, equals(imported.attachment.id));

      // Verify temporary files were deleted
      final remainingTempFiles = transcriptionTempDir.listSync();
      expect(remainingTempFiles, isEmpty);
    });

    test('fails safely if speech model is not installed', () async {
      // Create empty speech model manager with uninstalled model
      const uninstalledModel = FutoMultilingualSpeechModel244();
      final emptyManager = SpeechModelManager(
        descriptor: uninstalledModel,
        storageService: speechStorage,
        downloader: SpeechDownloader(storageService: speechStorage),
        autoCheck: false,
      );

      final serviceNoModel = AudioFileTranscriptionService(
        attachmentService: attachmentService,
        speechModelManager: emptyManager,
        speechEngine: fakeEngine,
        customTempDirectory: transcriptionTempDir,
      );

      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(Uint8List.fromList(List.filled(500, 42)));

      final imported = await attachmentService.importAudioRecording(
        file: audioFile,
        userTitle: 'Test Memo',
        noteId: 'note-1',
      );

      final result = await serviceNoModel.transcribeAttachment(
        attachmentId: imported.attachment.id,
      );

      expect(result, isNull);
      serviceNoModel.dispose();
    });

    test('deduplicates simultaneous in-flight requests for same attachment', () async {
      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(Uint8List.fromList(List.filled(500, 42)));

      final imported = await attachmentService.importAudioRecording(
        file: audioFile,
        userTitle: 'Concurrent Memo',
        noteId: 'note-1',
      );

      final future1 = service.transcribeAttachment(
        attachmentId: imported.attachment.id,
      );
      final future2 = service.transcribeAttachment(
        attachmentId: imported.attachment.id,
      );

      expect(identical(future1, future2), isTrue);

      final res1 = await future1;
      final res2 = await future2;
      expect(res1, equals(res2));
    });

    test('cancellation prevents saving and discards results safely', () async {
      final audioFile = File('${tempDir.path}/sample.wav');
      await audioFile.writeAsBytes(Uint8List.fromList(List.filled(500, 42)));

      final imported = await attachmentService.importAudioRecording(
        file: audioFile,
        userTitle: 'Cancelled Memo',
        noteId: 'note-1',
      );

      // Start transcription and cancel immediately
      final future = service.transcribeAttachment(
        attachmentId: imported.attachment.id,
      );
      service.cancelTranscription(imported.attachment.id);

      final result = await future;
      expect(result, isNull);

      // Original recording remains intact and playable
      final res = await attachmentService.resolveAsset(imported.attachment.id);
      expect(res.isAvailable, isTrue);
    });
  });
}
