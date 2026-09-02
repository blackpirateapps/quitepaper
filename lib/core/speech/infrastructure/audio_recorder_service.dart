import 'dart:async';
import 'dart:io';
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

  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Check whether microphone permission is granted.
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission explicitly.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
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

  /// Dispose recorder resources.
  Future<void> dispose() async {
    _timer?.cancel();
    _maxDurationTimer?.cancel();
    await _recorderInstance?.dispose();
    await _durationController.close();
  }
}
