import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/speech_model.dart';
import '../domain/speech_model_status.dart';
import '../domain/speech_recognition_engine.dart';
import '../domain/speech_session_state.dart';
import '../infrastructure/audio_recorder_service.dart';
import '../infrastructure/speech_downloader.dart';
import '../infrastructure/speech_storage_service.dart';
import '../infrastructure/whisper_recognition_engine.dart';
import 'speech_model_manager.dart';
import 'speech_recognition_service.dart';

final speechModelDescriptorProvider = Provider<SpeechModelDescriptor>((ref) {
  return const FutoEnglishSpeechModel();
});

final speechStorageServiceProvider = Provider<SpeechStorageService>((ref) {
  return SpeechStorageService();
});

final speechDownloaderProvider = Provider<SpeechDownloader>((ref) {
  final storage = ref.watch(speechStorageServiceProvider);
  return SpeechDownloader(storageService: storage);
});

final speechModelManagerProvider =
    ChangeNotifierProvider<SpeechModelManager>((ref) {
  final descriptor = ref.watch(speechModelDescriptorProvider);
  final storage = ref.watch(speechStorageServiceProvider);
  final downloader = ref.watch(speechDownloaderProvider);
  return SpeechModelManager(
    descriptor: descriptor,
    storageService: storage,
    downloader: downloader,
  );
});

final speechModelStatusProvider = Provider<SpeechModelStatus>((ref) {
  final manager = ref.watch(speechModelManagerProvider);
  return manager.status;
});

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final storage = ref.watch(speechStorageServiceProvider);
  return AudioRecorderService(storageService: storage);
});

final speechRecognitionEngineProvider =
    Provider<SpeechRecognitionEngine>((ref) {
  return WhisperRecognitionEngine();
});

final speechRecognitionServiceProvider =
    ChangeNotifierProvider<SpeechRecognitionService>((ref) {
  final modelManager = ref.read(speechModelManagerProvider);
  final recorder = ref.watch(audioRecorderServiceProvider);
  final engine = ref.watch(speechRecognitionEngineProvider);
  final storage = ref.watch(speechStorageServiceProvider);

  return SpeechRecognitionService(
    modelManager: modelManager,
    recorderService: recorder,
    recognitionEngine: engine,
    storageService: storage,
  );
});

final speechSessionProvider = Provider<SpeechSession>((ref) {
  final service = ref.watch(speechRecognitionServiceProvider);
  return service.session;
});
