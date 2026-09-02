import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/speech_recognition_engine.dart';
import '../domain/speech_session_state.dart';
import '../infrastructure/audio_recorder_service.dart';
import '../infrastructure/speech_storage_service.dart';
import 'speech_model_manager.dart';

class SpeechRecognitionService extends ChangeNotifier {
  SpeechRecognitionService({
    required this.modelManager,
    required this.recorderService,
    required this.recognitionEngine,
    required this.storageService,
  }) {
    _durationSubscription = recorderService.durationStream.listen((duration) {
      if (_session.isRecording) {
        _session = _session.copyWith(recordingDuration: duration);
        notifyListeners();
      }
    });
  }

  final SpeechModelManager modelManager;
  final AudioRecorderService recorderService;
  final SpeechRecognitionEngine recognitionEngine;
  final SpeechStorageService storageService;

  StreamSubscription<Duration>? _durationSubscription;

  SpeechSession _session = SpeechSession.initial;
  SpeechSession get session => _session;

  /// Starts recording speech for transcription.
  /// Returns `true` if recording started, `false` otherwise.
  Future<bool> startListening({
    void Function()? onMaxDurationReached,
  }) async {
    // Clear any previous error before starting
    if (_session.state == SpeechSessionState.error) {
      _session = const SpeechSession(state: SpeechSessionState.idle);
      notifyListeners();
    }

    if (_session.isBusy) {
      return false;
    }

    try {
      // 1. Verify model is installed
      _session = _session.copyWith(state: SpeechSessionState.checkingModel);
      notifyListeners();

      final status = await modelManager.checkStatus();
      if (!status.isInstalled) {
        _session = const SpeechSession(state: SpeechSessionState.idle);
        notifyListeners();
        return false;
      }

      // 2. Check & Request permission
      _session = _session.copyWith(state: SpeechSessionState.requestingPermission);
      notifyListeners();

      final hasPerm = await recorderService.hasPermission();
      if (!hasPerm) {
        final granted = await recorderService.requestPermission();
        if (!granted) {
          _session = const SpeechSession(
            state: SpeechSessionState.error,
            errorMessage: 'Microphone access is required for dictation.',
          );
          notifyListeners();
          return false;
        }
      }

      // 3. Load engine if needed
      if (status.modelPath != null) {
        _session = _session.copyWith(state: SpeechSessionState.loadingEngine);
        notifyListeners();
        try {
          await recognitionEngine
              .initialize(modelPath: status.modelPath!)
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          _session = const SpeechSession(
            state: SpeechSessionState.error,
            errorMessage:
                'Offline speech recognition couldn\'t be started.\n\nThe speech model may be unavailable or incompatible with this device.',
          );
          notifyListeners();
          return false;
        }
      }

      // 4. Start recording
      await recorderService.startRecording(
        onMaxDurationReached: () {
          if (_session.isRecording) {
            onMaxDurationReached?.call();
          }
        },
      ).timeout(const Duration(seconds: 10));

      _session = const SpeechSession(
        state: SpeechSessionState.recording,
        recordingDuration: Duration.zero,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _session = SpeechSession(
        state: SpeechSessionState.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Stops recording, executes transcription, and returns the transcribed text.
  /// The temporary audio recording is deleted after transcription.
  Future<String?> stopListeningAndTranscribe({
    String? lang,
    void Function(int percent)? onProgress,
  }) async {
    if (!_session.isRecording) {
      return null;
    }

    _session = _session.copyWith(state: SpeechSessionState.transcribing);
    notifyListeners();

    try {
      final audioFile = await recorderService.stopRecording();
      if (audioFile == null || !await audioFile.exists()) {
        _session = const SpeechSession(state: SpeechSessionState.idle);
        notifyListeners();
        return null;
      }

      final effectiveLang = lang ?? modelManager.descriptor.languageCode;
      final transcript = await recognitionEngine.transcribe(
        audioPath: audioFile.path,
        lang: effectiveLang,
        onProgress: onProgress,
      );

      // Clean up audio file immediately
      await recorderService.deleteCurrentRecording();

      _session = const SpeechSession(state: SpeechSessionState.idle);
      notifyListeners();

      return transcript.trim();
    } catch (e) {
      await recorderService.deleteCurrentRecording();
      _session = const SpeechSession(
        state: SpeechSessionState.error,
        errorMessage: 'The speech could not be transcribed.\n\nYour note was not changed.',
      );
      notifyListeners();
      return null;
    }
  }

  /// Cancels active recording and discards the audio file without transcribing.
  Future<void> cancelListening() async {
    await recorderService.cancelRecording();
    _session = const SpeechSession(state: SpeechSessionState.idle);
    notifyListeners();
  }

  /// Resets any error state back to idle.
  void clearError() {
    if (_session.state == SpeechSessionState.error) {
      _session = const SpeechSession(state: SpeechSessionState.idle);
      notifyListeners();
    }
  }

  /// Release native model memory and clean temporary audio.
  Future<void> releaseEngine() async {
    await recognitionEngine.dispose();
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    recorderService.dispose();
    recognitionEngine.dispose();
    storageService.cleanOrphanedAudioFiles();
    super.dispose();
  }
}
