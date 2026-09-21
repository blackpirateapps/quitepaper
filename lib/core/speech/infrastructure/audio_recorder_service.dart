import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'speech_storage_service.dart';

class AudioRecorderService {
  AudioRecorderService({
    AudioRecorder? recorder,
    required this.storageService,
    this.maxDuration = const Duration(seconds: 60),
  }) : _recorderInstance = recorder;

  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  final SpeechStorageService storageService;
  final Duration maxDuration;
  final _uuid = const Uuid();

  Timer? _timer;
  Timer? _maxDurationTimer;
  File? _currentAudioFile;
  DateTime? _recordingStartTime;
  StreamSubscription<Uint8List>? _streamSubscription;
  StreamController<Uint8List>? _streamController;
  final List<int> _bufferedPcmBytes = [];

  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Check whether microphone permission is granted.
  Future<bool> hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Request microphone permission explicitly.
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) return true;
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Start recording audio into a temporary WAV file.
  Future<File> startRecording({
    void Function()? onMaxDurationReached,
  }) async {
    if (_isRecording) {
      throw StateError('Audio recording is already in progress.');
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      final requested = await requestPermission();
      if (!requested) {
        throw StateError('Microphone permission denied.');
      }
    }

    final tempDir = await storageService.getAudioTempDirectory();
    final filename = 'speech_temp_${_uuid.v4()}.wav';
    final targetFile = File(p.join(tempDir.path, filename));
    _currentAudioFile = targetFile;

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );

    await _recorder.start(config, path: targetFile.path);
    _isRecording = true;
    _recordingStartTime = DateTime.now();

    _timer?.cancel();
    _durationController.add(Duration.zero);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_recordingStartTime != null && _isRecording) {
        final elapsed = DateTime.now().difference(_recordingStartTime!);
        _durationController.add(elapsed);
      }
    });

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxDuration, () {
      if (_isRecording) {
        onMaxDurationReached?.call();
      }
    });

    return targetFile;
  }

  /// Start streaming recording audio as raw 16 kHz mono little-endian PCM16
  /// bytes for real-time transcription, simultaneously assembling a WAV file
  /// for fallback execution.
  Future<Stream<Uint8List>> startStreaming({
    void Function()? onMaxDurationReached,
  }) async {
    if (_isRecording) {
      throw StateError('Audio recording is already in progress.');
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      final requested = await requestPermission();
      if (!requested) {
        throw StateError('Microphone permission denied.');
      }
    }

    final tempDir = await storageService.getAudioTempDirectory();
    final filename = 'speech_temp_${_uuid.v4()}.wav';
    final targetFile = File(p.join(tempDir.path, filename));
    _currentAudioFile = targetFile;
    _bufferedPcmBytes.clear();

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    final rawStream = await _recorder.startStream(config);
    _isRecording = true;
    _recordingStartTime = DateTime.now();

    _timer?.cancel();
    _durationController.add(Duration.zero);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_recordingStartTime != null && _isRecording) {
        final elapsed = DateTime.now().difference(_recordingStartTime!);
        _durationController.add(elapsed);
      }
    });

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxDuration, () {
      if (_isRecording) {
        onMaxDurationReached?.call();
      }
    });

    _streamSubscription?.cancel();
    _streamController = StreamController<Uint8List>.broadcast();

    _streamSubscription = rawStream.listen(
      (chunk) {
        _bufferedPcmBytes.addAll(chunk);
        if (_streamController != null && !_streamController!.isClosed) {
          _streamController!.add(chunk);
        }
      },
      onError: (e) {
        if (_streamController != null && !_streamController!.isClosed) {
          _streamController!.addError(e);
        }
      },
      onDone: () async {
        if (_streamController != null && !_streamController!.isClosed) {
          await _streamController!.close();
        }
      },
      cancelOnError: true,
    );

    return _streamController!.stream;
  }

  /// Stops recording and returns the recorded temporary WAV file.
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    _timer?.cancel();
    _timer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    final path = await _recorder.stop();
    _isRecording = false;
    _recordingStartTime = null;

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_streamController != null && !_streamController!.isClosed) {
      await _streamController!.close();
    }
    _streamController = null;

    // If streaming mode was active, write the buffered PCM into the destination WAV
    if (_bufferedPcmBytes.isNotEmpty && _currentAudioFile != null) {
      try {
        final wavBytes = buildWavBytes(_bufferedPcmBytes, 16000, 1, 16);
        await _currentAudioFile!.writeAsBytes(wavBytes);
        _bufferedPcmBytes.clear();
      } catch (_) {}
    }

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        _currentAudioFile = file;
        return file;
      }
    }
    return _currentAudioFile;
  }

  /// Cancels recording and immediately deletes the temporary audio file.
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_streamController != null && !_streamController!.isClosed) {
      await _streamController!.close();
    }
    _streamController = null;
    _bufferedPcmBytes.clear();

    if (_isRecording) {
      try {
        await _recorder.stop();
      } catch (_) {}
      _isRecording = false;
      _recordingStartTime = null;
    }

    await deleteCurrentRecording();
  }

  /// Deletes the current temporary recording file.
  Future<void> deleteCurrentRecording() async {
    if (_currentAudioFile != null) {
      try {
        if (await _currentAudioFile!.exists()) {
          await _currentAudioFile!.delete();
        }
      } catch (_) {}
      _currentAudioFile = null;
    }
  }

  /// Construct standard RIFF 16-bit PCM WAV bytes from raw PCM audio samples.
  static Uint8List buildWavBytes(
    List<int> pcmData,
    int sampleRate,
    int channels,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final chunkSize = 36 + dataSize;

    final header = ByteData(44);
    // "RIFF"
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, chunkSize, Endian.little);
    // "WAVE"
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // "fmt "
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // AudioFormat (PCM = 1)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, 44 + dataSize, pcmData);
    return out;
  }

  /// Dispose recorder resources.
  Future<void> dispose() async {
    _timer?.cancel();
    _maxDurationTimer?.cancel();
    await _streamSubscription?.cancel();
    if (_streamController != null && !_streamController!.isClosed) {
      await _streamController!.close();
    }
    await _recorderInstance?.dispose();
    await _durationController.close();
  }
}
