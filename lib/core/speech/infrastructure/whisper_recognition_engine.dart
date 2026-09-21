import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../domain/speech_recognition_engine.dart';
import 'audio_recorder_service.dart';

typedef _WReqNative = Pointer<Utf8> Function(Pointer<Utf8> body);

class WhisperRecognitionEngine implements SpeechRecognitionEngine {
  WhisperRecognitionEngine();

  String? _loadedModelPath;
  bool _isLoaded = false;
  Completer<void>? _initCompleter;
  static File? _warmupWavFile;

  @override
  bool get isLoaded => _isLoaded;

  /// Optimal CPU thread count for neural speech inference on mobile / desktop.
  /// Caps at 4 threads to target the primary performance cluster on big.LITTLE
  /// architectures and avoid thread synchronization stalls on efficiency cores.
  static int get optimalThreadCount {
    try {
      return math.max(1, math.min(4, Platform.numberOfProcessors));
    } catch (_) {
      return 4;
    }
  }

  static DynamicLibrary? _tryOpenLib() {
    try {
      if (Platform.isAndroid) {
        return DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isWindows) {
        return DynamicLibrary.open('whisper_ggml.dll');
      } else if (Platform.isLinux) {
        return DynamicLibrary.open('libwhisper_ggml.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        return DynamicLibrary.process();
      }
    } catch (e) {
      debugPrint('WhisperRecognitionEngine: could not open native library directly: $e');
    }
    return null;
  }

  /// Whether the native whisper dynamic library is linkable in the current environment.
  static bool get isNativeLibraryAvailable => _tryOpenLib() != null;

  /// Low-level native request bypassing FFmpegKit completely.
  /// Dr. Wav reads the 16 kHz 16-bit mono WAV natively in C++ in milliseconds.
  static Future<Map<String, dynamic>> _callNativeRequest(
    Map<String, dynamic> requestPayload,
  ) async {
    final lib = _tryOpenLib();
    if (lib == null) {
      throw UnsupportedError('Native whisper library is not directly linkable on this platform.');
    }

    return compute((Map<String, dynamic> payload) {
      final nativeLib = _tryOpenLib();
      if (nativeLib == null) {
        throw UnsupportedError('Native whisper library could not be opened in isolate.');
      }

      final Pointer<Utf8> data = json.encode(payload).toNativeUtf8();
      try {
        final requestFn = nativeLib.lookupFunction<_WReqNative, _WReqNative>('request');
        final Pointer<Utf8> res = requestFn(data);

        final Map<String, dynamic> result =
            json.decode(res.toDartString()) as Map<String, dynamic>;

        malloc.free(res);
        return result;
      } finally {
        malloc.free(data);
      }
    }, requestPayload);
  }

  /// Create a minimal 16 kHz mono silence WAV to warm up the model and park it
  /// in native RAM before recording begins.
  static Future<File> _getOrCreateWarmupWav() async {
    if (_warmupWavFile != null && await _warmupWavFile!.exists()) {
      return _warmupWavFile!;
    }
    final tempDir = await Directory.systemTemp.createTemp('whisper_warm_');
    final file = File('${tempDir.path}/warmup.wav');
    // 100 samples of silence (200 bytes of PCM16)
    final pcmSilence = Uint8List(200);
    final wavBytes = AudioRecorderService.buildWavBytes(pcmSilence, 16000, 1, 16);
    await file.writeAsBytes(wavBytes);
    _warmupWavFile = file;
    return file;
  }

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

      // Eagerly prewarm model into native memory (g_model_cache)
      try {
        final warmupFile = await _getOrCreateWarmupWav();
        final threadCount = optimalThreadCount;
        await _callNativeRequest({
          '@type': 'getTextFromWavFile',
          'threads': threadCount,
          'is_verbose': false,
          'is_translate': false,
          'language': 'en',
          'is_special_tokens': false,
          'is_no_timestamps': true,
          'model': modelPath,
          'audio': warmupFile.path,
          'split_on_word': false,
          'diarize': false,
          'keep_model_loaded': true,
        });
      } catch (e) {
        debugPrint('WhisperRecognitionEngine prewarm skipped ($e)');
      }

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

    final threadCount = optimalThreadCount;

    try {
      // 1. Direct FFI Execution (Zero FFmpegKit overhead)
      final response = await _callNativeRequest({
        '@type': 'getTextFromWavFile',
        'threads': threadCount,
        'is_verbose': false,
        'is_translate': false,
        'language': lang,
        'is_special_tokens': false,
        'is_no_timestamps': true,
        'model': _loadedModelPath!,
        'audio': audioPath,
        'split_on_word': false,
        'diarize': false,
        'keep_model_loaded': true,
      });

      if (response['@type'] == 'error') {
        throw Exception(response['message'] ?? 'Native transcription failed');
      }

      final rawText = (response['text'] as String? ?? '').trim();
      return rawText;
    } catch (e) {
      debugPrint('Whisper direct FFI error ($e); falling back to package transcribe.');
      // 2. Package transcribe fallback
      const whisper = Whisper(model: WhisperModel.tiny);
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: lang,
          threads: threadCount,
          isTranslate: false,
          isNoTimestamps: true,
          splitOnWord: false,
          isRealtime: true,
          keepModelLoaded: true,
        ),
        modelPath: _loadedModelPath!,
        onProgress: onProgress,
      );
      return response.text.trim();
    }
  }

  @override
  Future<void> dispose() async {
    if (_isLoaded) {
      try {
        await _callNativeRequest({'@type': 'releaseModel'});
      } catch (_) {
        try {
          const whisper = Whisper(model: WhisperModel.tiny);
          await whisper.releaseModel();
        } catch (_) {}
      }
      _isLoaded = false;
      _loadedModelPath = null;
    }
  }
}
