/// Abstract interface for offline speech recognition inference engines.
abstract class SpeechRecognitionEngine {
  /// Whether the native engine is currently initialized and resident in memory.
  bool get isLoaded;

  /// Load and initialize the native speech model from local storage.
  Future<void> initialize({required String modelPath});

  /// Transcribe a local 16kHz WAV audio file to text.
  Future<String> transcribe({
    required String audioPath,
    String lang = 'en',
    void Function(int percent)? onProgress,
  });

  /// Release native model memory and resources.
  Future<void> dispose();
}
