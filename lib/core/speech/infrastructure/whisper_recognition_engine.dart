import 'dart:async';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../domain/speech_recognition_engine.dart';

class WhisperRecognitionEngine implements SpeechRecognitionEngine {
  WhisperRecognitionEngine();

  String? _loadedModelPath;
  bool _isLoaded = false;
  Completer<void>? _initCompleter;

  @override
  bool get isLoaded => _isLoaded;

  @override
  Future<void> initialize({required String modelPath}) async {
    if (_isLoaded && _loadedModelPath == modelPath) {
      return;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      _loadedModelPath = modelPath;
      _isLoaded = true;
      _initCompleter!.complete();
    } catch (e) {
      _isLoaded = false;
      _loadedModelPath = null;
      _initCompleter!.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  @override
  Future<String> transcribe({
    required String audioPath,
    String lang = 'en',
    void Function(int percent)? onProgress,
  }) async {
    if (_loadedModelPath == null) {
      throw StateError('WhisperRecognitionEngine is not initialized with a model.');
    }

    const whisper = Whisper(model: WhisperModel.tiny);
    final response = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: lang,
        isTranslate: false,
        isNoTimestamps: true,
        splitOnWord: false,
        isRealtime: true,
        keepModelLoaded: true,
      ),
      modelPath: _loadedModelPath!,
      onProgress: onProgress,
    );

    final rawText = response.text.trim();
    return rawText;
  }

  @override
  Future<void> dispose() async {
    if (_isLoaded) {
      try {
        const whisper = Whisper(model: WhisperModel.tiny);
        await whisper.releaseModel();
      } catch (_) {}
      _isLoaded = false;
      _loadedModelPath = null;
    }
  }
}
