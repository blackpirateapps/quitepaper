import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../domain/speech_recognition_engine.dart';
import '../domain/speech_session_state.dart';
import '../infrastructure/audio_recorder_service.dart';
import '../infrastructure/speech_storage_service.dart';
import '../infrastructure/whisper_recognition_engine.dart';
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
  WhisperLiveSession? _activeLiveSession;
  StreamSubscription<Uint8List>? _pcmFeedSubscription;
  StreamSubscription<String>? _livePartialsSubscription;

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

      // 4. Start recording with real-time streaming pipeline (if native whisper library is available)
      if (status.modelPath != null && WhisperRecognitionEngine.isNativeLibraryAvailable) {
        try {
          final pcmStream = await recorderService.startStreaming(
            onMaxDurationReached: () {
              if (_session.isRecording) {
                onMaxDurationReached?.call();
              }
            },
          ).timeout(const Duration(seconds: 10));

          final effectiveLang = modelManager.descriptor.languageCode;
          _activeLiveSession = await startWhisperLiveSession(
            modelPath: status.modelPath!,
            lang: effectiveLang,
            keepModelLoaded: true,
            threads: WhisperRecognitionEngine.optimalThreadCount,
          );

          _livePartialsSubscription = _activeLiveSession!.partials.listen((partial) {
            if (_session.isRecording) {
              _session = _session.copyWith(partialTranscript: partial);
              notifyListeners();
            }
          });

          _pcmFeedSubscription = pcmStream.listen(
            _activeLiveSession!.feed,
            onError: (e) {
              debugPrint('SpeechRecognitionService: PCM stream feed error: $e');
            },
          );
        } catch (streamError) {
          debugPrint(
            'SpeechRecognitionService: streaming setup fallback ($streamError)',
          );
          await _cleanupActiveLiveSession();
          if (!recorderService.isRecording) {
            await recorderService.startRecording(
              onMaxDurationReached: () {
                if (_session.isRecording) {
                  onMaxDurationReached?.call();
                }
              },
            ).timeout(const Duration(seconds: 10));
          }
        }
      } else {
        // Standard audio recording (native library unavailable or non-live fallback)
        await recorderService.startRecording(
          onMaxDurationReached: () {
            if (_session.isRecording) {
              onMaxDurationReached?.call();
            }
          },
        ).timeout(const Duration(seconds: 10));
      }

      _session = const SpeechSession(
        state: SpeechSessionState.recording,
        recordingDuration: Duration.zero,
      );
      notifyListeners();
      return true;
    } catch (e) {
      await _cleanupActiveLiveSession();
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
      String? transcript;

      // 1. If live streaming session was active, stop and retrieve live transcript
      if (_activeLiveSession != null) {
        try {
          await _pcmFeedSubscription?.cancel();
          _pcmFeedSubscription = null;
          await _livePartialsSubscription?.cancel();
          _livePartialsSubscription = null;

          transcript = await _activeLiveSession!.stop();
        } catch (e) {
          debugPrint('SpeechRecognitionService: live session stop error ($e)');
        } finally {
          _activeLiveSession = null;
        }
      }

      // 2. Stop audio recorder
      final audioFile = await recorderService.stopRecording();

      // 3. Fallback to batch direct FFI engine if live transcript was empty
      if (transcript == null || transcript.trim().isEmpty) {
        if (audioFile != null && await audioFile.exists()) {
          final effectiveLang = lang ?? modelManager.descriptor.languageCode;
          transcript = await recognitionEngine.transcribe(
            audioPath: audioFile.path,
            lang: effectiveLang,
            onProgress: onProgress,
          );
        }
      }

      // Clean up audio file immediately
      await recorderService.deleteCurrentRecording();

      _session = const SpeechSession(state: SpeechSessionState.idle);
      notifyListeners();

      return transcript?.trim();
    } catch (e) {
      await _cleanupActiveLiveSession();
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
    await _cleanupActiveLiveSession();
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
    await _cleanupActiveLiveSession();
    await recognitionEngine.dispose();
  }

  Future<void> _cleanupActiveLiveSession() async {
    await _pcmFeedSubscription?.cancel();
    _pcmFeedSubscription = null;
    await _livePartialsSubscription?.cancel();
    _livePartialsSubscription = null;
    if (_activeLiveSession != null) {
      try {
        await _activeLiveSession!.stop();
      } catch (_) {}
      _activeLiveSession = null;
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _cleanupActiveLiveSession();
    recorderService.dispose();
    recognitionEngine.dispose();
    storageService.cleanOrphanedAudioFiles();
    super.dispose();
  }
}
