import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/settings/application/settings_provider.dart';
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

/// Notifier managing persisted user speech model preference.
class SpeechModelPreferenceNotifier extends StateNotifier<SpeechModelDescriptor> {
  SpeechModelPreferenceNotifier(this._prefs) : super(_loadModel(_prefs));

  final SharedPreferences? _prefs;
  static const String _key = 'quietpaper_speech_model_pref';

  static SpeechModelDescriptor _loadModel(SharedPreferences? prefs) {
    if (prefs == null) return SpeechModels.defaultModel;
    final id = prefs.getString(_key);
    return SpeechModels.fromId(id);
  }

  Future<void> setModel(SpeechModelDescriptor model) async {
    state = model;
    await _prefs?.setString(_key, model.id);
  }

  Future<void> setModelById(String modelId) async {
    final model = SpeechModels.fromId(modelId);
    state = model;
    await _prefs?.setString(_key, model.id);
  }
}

/// Provider for user's configured speech model preference.
final selectedSpeechModelProvider =
    StateNotifierProvider<SpeechModelPreferenceNotifier, SpeechModelDescriptor>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // In unit test contexts where sharedPreferencesProvider is uninitialized
  }
  return SpeechModelPreferenceNotifier(prefs);
});

final speechModelDescriptorProvider = Provider<SpeechModelDescriptor>((ref) {
  return ref.watch(selectedSpeechModelProvider);
});

final speechStorageServiceProvider = Provider<SpeechStorageService>((ref) {
  return SpeechStorageService();
});

final speechDownloaderProvider = Provider<SpeechDownloader>((ref) {
  final storage = ref.watch(speechStorageServiceProvider);
  return SpeechDownloader(storageService: storage);
});

/// SpeechModelManager for a specific model descriptor.
final speechModelManagerFamily =
    ChangeNotifierProvider.family<SpeechModelManager, SpeechModelDescriptor>((ref, descriptor) {
  final storage = ref.watch(speechStorageServiceProvider);
  final downloader = ref.watch(speechDownloaderProvider);
  return SpeechModelManager(
    descriptor: descriptor,
    storageService: storage,
    downloader: downloader,
  );
});

/// Default SpeechModelManager for the currently active/selected model descriptor.
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
