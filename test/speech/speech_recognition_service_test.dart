import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/speech/application/speech_model_manager.dart';
import 'package:quitepaper/core/speech/application/speech_recognition_service.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/domain/speech_recognition_engine.dart';
import 'package:quitepaper/core/speech/domain/speech_session_state.dart';
import 'package:quitepaper/core/speech/infrastructure/audio_recorder_service.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_downloader.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';

class FakeSpeechRecognitionEngine implements SpeechRecognitionEngine {
  bool _isLoaded = false;
  String? lastAudioPath;
  String? lastLang;
  String returnedTranscript = 'Transcribed speech text';

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> initialize({required String modelPath}) async {
    _isLoaded = true;
  }

  @override
  Future<String> transcribe({
    required String audioPath,
    String lang = 'en',
    void Function(int percent)? onProgress,
  }) async {
    lastAudioPath = audioPath;
    lastLang = lang;
    return returnedTranscript;
  }

  @override
  Future<void> dispose() async {
    _isLoaded = false;
  }
}

class FakeAudioRecorderService extends AudioRecorderService {
  FakeAudioRecorderService({required super.storageService});

  bool permissionGranted = true;
  bool isRec = false;
  File? generatedAudioFile;

  @override
  bool get isRecording => isRec;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<File> startRecording({void Function()? onMaxDurationReached}) async {
    isRec = true;
    final tempDir = await storageService.getAudioTempDirectory();
    final file = File('${tempDir.path}/test_speech.wav');
    await file.writeAsString('RIFF dummy wav data');
    generatedAudioFile = file;
    return file;
  }

  @override
  Future<File?> stopRecording() async {
    isRec = false;
    return generatedAudioFile;
  }

  @override
  Future<void> cancelRecording() async {
    isRec = false;
    await deleteCurrentRecording();
  }

  @override
  Future<void> deleteCurrentRecording() async {
    if (generatedAudioFile != null && await generatedAudioFile!.exists()) {
      await generatedAudioFile!.delete();
    }
    generatedAudioFile = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory audioDir;
  late SpeechStorageService storageService;
  late FakeSpeechRecognitionEngine fakeEngine;
  late FakeAudioRecorderService fakeRecorder;
  late SpeechModelManager modelManager;
  late SpeechRecognitionService service;
  const descriptor = FutoEnglishSpeechModel();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech_service_test_');
    audioDir = await Directory.systemTemp.createTemp('speech_audio_test_');

    storageService = SpeechStorageService(
      baseDirectory: tempDir,
      temporaryDirectory: audioDir,
    );

    // Pre-install model
    final modelFile = await storageService.getModelFile(descriptor);
    final dummyBytes = List<int>.filled(descriptor.sizeBytes, 0);
    await modelFile.writeAsBytes(dummyBytes);
    final metadata = SpeechModelMetadata(
      modelId: descriptor.id,
      version: descriptor.version,
      filename: descriptor.filename,
      sizeBytes: descriptor.sizeBytes,
      sha256: descriptor.expectedSha256,
      installedAt: DateTime.now(),
    );
    await storageService.saveMetadata(metadata);

    fakeEngine = FakeSpeechRecognitionEngine();
    fakeRecorder = FakeAudioRecorderService(storageService: storageService);
    final downloader = SpeechDownloader(storageService: storageService);
    modelManager = SpeechModelManager(
      descriptor: descriptor,
      storageService: storageService,
      downloader: downloader,
    );

    service = SpeechRecognitionService(
      modelManager: modelManager,
      recorderService: fakeRecorder,
      recognitionEngine: fakeEngine,
      storageService: storageService,
    );
  });

  tearDown(() async {
    service.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await audioDir.exists()) {
      await audioDir.delete(recursive: true);
    }
  });

  test('full recording and transcription flow', () async {
    expect(service.session.isIdle, isTrue);

    final started = await service.startListening();
    expect(started, isTrue);
    expect(service.session.isRecording, isTrue);

    final transcript = await service.stopListeningAndTranscribe();
    expect(transcript, equals('Transcribed speech text'));
    expect(service.session.isIdle, isTrue);

    // Verify temp audio file was deleted after transcription
    expect(fakeRecorder.generatedAudioFile, isNull);
  });

  test('cancelListening discards audio and resets session to idle', () async {
    await service.startListening();
    expect(service.session.isRecording, isTrue);

    await service.cancelListening();
    expect(service.session.isIdle, isTrue);
    expect(fakeRecorder.generatedAudioFile, isNull);
  });

  test('handles permission denial cleanly without recording', () async {
    fakeRecorder.permissionGranted = false;

    final started = await service.startListening();
    expect(started, isFalse);
    expect(service.session.state, equals(SpeechSessionState.error));
    expect(service.session.errorMessage,
        contains('Microphone access is required'));

    // Retry after permission is granted should recover and start listening
    fakeRecorder.permissionGranted = true;
    final retried = await service.startListening();
    expect(retried, isTrue);
    expect(service.session.isRecording, isTrue);
    expect(service.session.errorMessage, isNull);
  });

  test('multilingual model automatically passes lang: auto to engine', () async {
    const multiDescriptor = FutoMultilingualSpeechModel244();
    final multiModelFile = await storageService.getModelFile(multiDescriptor);
    final dummyBytes = List<int>.filled(multiDescriptor.sizeBytes, 0);
    await multiModelFile.writeAsBytes(dummyBytes);
    final metadata = SpeechModelMetadata(
      modelId: multiDescriptor.id,
      version: multiDescriptor.version,
      filename: multiDescriptor.filename,
      sizeBytes: multiDescriptor.sizeBytes,
      sha256: multiDescriptor.expectedSha256,
      installedAt: DateTime.now(),
    );
    await storageService.saveMetadata(metadata);

    final multiManager = SpeechModelManager(
      descriptor: multiDescriptor,
      storageService: storageService,
      downloader: SpeechDownloader(storageService: storageService),
    );

    final multiService = SpeechRecognitionService(
      modelManager: multiManager,
      recorderService: fakeRecorder,
      recognitionEngine: fakeEngine,
      storageService: storageService,
    );
    addTearDown(multiService.dispose);

    await multiService.startListening();
    expect(multiService.session.isRecording, isTrue);

    await multiService.stopListeningAndTranscribe();
    expect(fakeEngine.lastLang, equals('auto'));
  });
}
