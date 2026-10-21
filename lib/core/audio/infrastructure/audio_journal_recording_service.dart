import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../application/audio_duration_helper.dart';
import '../domain/audio_journal_models.dart';

/// Service managing the audio capture pipeline for journal voice memos.
///
/// Features:
/// - Explicit lifecycle state machine with pause/resume support.
/// - Exact elapsed time accumulation excluding paused intervals.
/// - Live decibel and normalized amplitude monitoring for waveform rendering.
/// - App-private temporary workspace with automatic stale session cleanup.
/// - Safe resource disposal and guard against concurrent sessions.
class AudioJournalRecordingService {
  AudioJournalRecordingService({
    AudioRecorder? recorder,
    AudioJournalConfig? config,
    this.customTempDirectory,
  })  : _recorderInstance = recorder,
        config = config ?? const AudioJournalConfig();

  final Directory? customTempDirectory;

  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  final AudioJournalConfig config;
  static const _uuid = Uuid();

  AudioJournalRecordingSession _session = const AudioJournalRecordingSession();
  AudioJournalRecordingSession get session => _session;

  final _sessionController =
      StreamController<AudioJournalRecordingSession>.broadcast();
  Stream<AudioJournalRecordingSession> get sessionStream =>
      _sessionController.stream;

  Timer? _tickerTimer;
  Timer? _maxDurationTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  DateTime? _segmentStartTime;
  Duration _accumulatedPastDuration = Duration.zero;
  final List<double> _liveAmplitudes = [];
  final List<double> _fullSessionAmplitudes = [];

  bool _isDisposed = false;

  void _emit(AudioJournalRecordingSession updated) {
    if (_isDisposed) return;
    _session = updated;
    _sessionController.add(_session);
  }

  /// Check whether microphone permission is granted.
  Future<bool> hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
    } catch (_) {}
    try {
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
    } catch (_) {}
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Returns the app-private temporary directory for audio recordings.
  Future<Directory> getAudioTempDirectory() async {
    if (customTempDirectory != null) {
      if (!await customTempDirectory!.exists()) {
        await customTempDirectory!.create(recursive: true);
      }
      return customTempDirectory!;
    }
    final tempBase = await getTemporaryDirectory();
    final dir = Directory(p.join(tempBase.path, 'audio_journal'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cleans up any orphaned temporary recording files on startup.
  Future<void> cleanupStaleRecordings({Duration maxAge = const Duration(hours: 24)}) async {
    try {
      final dir = await getAudioTempDirectory();
      if (!await dir.exists()) return;
      final now = DateTime.now();
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioJournal] Cleanup stale recordings failed: $e');
    }
  }

  /// Starts a new recording session.
  ///
  /// Throws [StateError] if another recording session is already active.
  Future<File> startRecording({
    String? noteId,
    String? capturedNodeId,
    int? capturedCaretOffset,
    void Function()? onMaxDurationReached,
  }) async {
    if (_session.isActive) {
      throw StateError('An audio recording session is already active.');
    }

    _emit(_session.copyWith(
      status: AudioJournalStatus.requestingPermission,
      activeNoteId: noteId,
      capturedNodeId: capturedNodeId,
      capturedCaretOffset: capturedCaretOffset,
    ));

    final granted = await hasPermission();
    if (!granted) {
      final requested = await requestPermission();
      if (!requested) {
        _emit(_session.copyWith(
          status: AudioJournalStatus.failed,
          errorMessage: 'Microphone permission denied.',
        ));
        throw StateError('Microphone permission denied.');
      }
    }

    _emit(_session.copyWith(status: AudioJournalStatus.preparing));

    final tempDir = await getAudioTempDirectory();
    final filename = 'voice_memo_${_uuid.v4()}.m4a';
    final targetFile = File(p.join(tempDir.path, filename));

    _accumulatedPastDuration = Duration.zero;
    _liveAmplitudes.clear();

    const recordConfig = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      bitRate: 128000,
      numChannels: 1,
    );

    try {
      await _recorder.start(recordConfig, path: targetFile.path);
    } catch (e) {
      // If AAC fails on unusual desktop platform, fallback to WAV
      debugPrint('[AudioJournal] AAC encoder failed ($e), falling back to WAV...');
      const fallbackConfig = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      );
      final wavFile = File(p.join(tempDir.path, 'voice_memo_${_uuid.v4()}.wav'));
      await _recorder.start(fallbackConfig, path: wavFile.path);
      return _initActiveRecording(wavFile, onMaxDurationReached);
    }

    return _initActiveRecording(targetFile, onMaxDurationReached);
  }

  File _initActiveRecording(File targetFile, void Function()? onMaxDurationReached) {
    final now = DateTime.now();
    _segmentStartTime = now;
    _fullSessionAmplitudes.clear();

    _emit(_session.copyWith(
      status: AudioJournalStatus.recording,
      workingFile: targetFile,
      recordingStartTime: now,
      elapsedDuration: Duration.zero,
      liveAmplitudes: const [],
      sessionAmplitudes: const [],
      errorMessage: null,
    ));

    _startTicker();
    _startAmplitudeMonitoring();

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(config.maxDuration, () {
      if (_session.isRecording || _session.isPaused) {
        onMaxDurationReached?.call();
      }
    });

    return targetFile;
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_session.status == AudioJournalStatus.recording && _segmentStartTime != null) {
        final currentSegment = DateTime.now().difference(_segmentStartTime!);
        final totalElapsed = _accumulatedPastDuration + currentSegment;

        _emit(_session.copyWith(
          elapsedDuration: totalElapsed,
          liveAmplitudes: List.unmodifiable(_liveAmplitudes),
        ));

        // Safety check file size if workingFile exists
        final file = _session.workingFile;
        if (file != null && file.existsSync()) {
          try {
            if (file.lengthSync() > config.maxSizeBytes) {
              stopRecording();
            }
          } catch (_) {}
        }
      }
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    try {
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((amp) {
        if (_session.status == AudioJournalStatus.recording) {
          final currentDb = amp.current;
          // Normalize from [-60dB..0dB] to [0.0..1.0]
          final norm = ((currentDb + 60.0) / 60.0).clamp(0.0, 1.0);
          final smoothed = (math.pow(norm, 1.3) * 0.8 + 0.15).toDouble().clamp(0.15, 0.95);

          if (_liveAmplitudes.length > 120) {
            _liveAmplitudes.removeAt(0);
          }
          _liveAmplitudes.add(smoothed);
          _fullSessionAmplitudes.add(smoothed);

          _emit(_session.copyWith(
            currentDecibels: currentDb,
            liveAmplitudes: List.unmodifiable(_liveAmplitudes),
            sessionAmplitudes: List.unmodifiable(_fullSessionAmplitudes),
          ));
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Pauses the active recording session.
  Future<void> pauseRecording() async {
    if (_session.status != AudioJournalStatus.recording) return;

    if (_segmentStartTime != null) {
      _accumulatedPastDuration += DateTime.now().difference(_segmentStartTime!);
      _segmentStartTime = null;
    }

    try {
      await _recorder.pause();
    } catch (e) {
      debugPrint('[AudioJournal] Pause error: $e');
    }

    _emit(_session.copyWith(
      status: AudioJournalStatus.paused,
      elapsedDuration: _accumulatedPastDuration,
    ));
  }

  /// Resumes a paused recording session.
  Future<void> resumeRecording() async {
    if (_session.status != AudioJournalStatus.paused) return;

    _segmentStartTime = DateTime.now();

    try {
      await _recorder.resume();
    } catch (e) {
      debugPrint('[AudioJournal] Resume error: $e');
    }

    _emit(_session.copyWith(
      status: AudioJournalStatus.recording,
    ));
  }

  /// Finalizes the recording and returns the completed audio [File].
  ///
  /// Returns `null` if no recording was in progress, or if the recording is empty.
  Future<File?> stopRecording() async {
    if (!_session.isActive) return null;

    _emit(_session.copyWith(status: AudioJournalStatus.finalizing));

    _tickerTimer?.cancel();
    _tickerTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (_segmentStartTime != null) {
      _accumulatedPastDuration += DateTime.now().difference(_segmentStartTime!);
      _segmentStartTime = null;
    }

    String? outputPath;
    try {
      outputPath = await _recorder.stop();
    } catch (e) {
      debugPrint('[AudioJournal] Recorder stop error: $e');
    }

    File? resultFile = _session.workingFile;
    if (outputPath != null) {
      final f = File(outputPath);
      if (await f.exists()) {
        resultFile = f;
      }
    }

    // Validate finalized audio file
    if (resultFile == null || !await resultFile.exists() || await resultFile.length() < 100) {
      _emit(_session.copyWith(
        status: AudioJournalStatus.failed,
        errorMessage: 'Recording was empty or could not be finalized.',
      ));
      if (resultFile != null && await resultFile.exists()) {
        try {
          await resultFile.delete();
        } catch (_) {}
      }
      return null;
    }

    _emit(_session.copyWith(
      status: AudioJournalStatus.completed,
      elapsedDuration: _accumulatedPastDuration,
      workingFile: resultFile,
      sessionAmplitudes: List.unmodifiable(_fullSessionAmplitudes),
    ));

    return resultFile;
  }

  /// Returns a normalized downsampled [count]-bar waveform representing the entire recorded session.
  List<double> getRecordedWaveform({int count = 32}) {
    if (_fullSessionAmplitudes.isEmpty) return const [];
    return AudioDurationHelper.downsampleAmplitudes(_fullSessionAmplitudes, count);
  }

  /// Cancels the recording session and immediately deletes the temporary audio file.
  Future<void> cancelRecording() async {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _segmentStartTime = null;

    try {
      await _recorder.cancel();
    } catch (_) {}

    final file = _session.workingFile;
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    _emit(const AudioJournalRecordingSession(
      status: AudioJournalStatus.cancelled,
    ));
  }

  /// Resets session state back to idle.
  void reset() {
    _emit(const AudioJournalRecordingSession(
      status: AudioJournalStatus.idle,
    ));
  }

  /// Releases recorder and stream controller resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      await _recorder.dispose();
    } catch (_) {}
    await _sessionController.close();
  }
}
