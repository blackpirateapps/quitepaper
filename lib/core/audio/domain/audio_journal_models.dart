import 'dart:io';
import 'package:flutter/foundation.dart';

/// Explicit lifecycle states for an audio journaling recording session.
enum AudioJournalStatus {
  idle,
  requestingPermission,
  preparing,
  recording,
  paused,
  finalizing,
  encrypting,
  saving,
  completed,
  failed,
  cancelled,
}

/// Immutable state representation of an active or recent audio recording session.
@immutable
class AudioJournalRecordingSession {
  const AudioJournalRecordingSession({
    this.status = AudioJournalStatus.idle,
    this.elapsedDuration = Duration.zero,
    this.currentDecibels = -160.0,
    this.liveAmplitudes = const [],
    this.sessionAmplitudes = const [],
    this.activeNoteId,
    this.workingFile,
    this.recordingStartTime,
    this.errorMessage,
    this.capturedNodeId,
    this.capturedCaretOffset,
  });

  /// Current state in the recording lifecycle state machine.
  final AudioJournalStatus status;

  /// Elapsed captured audio time (excluding paused duration).
  final Duration elapsedDuration;

  /// Instantaneous decibel level from the recording hardware (-160 to 0).
  final double currentDecibels;

  /// Live normalized amplitude values (0.0 to 1.0) for real-time waveform visualization.
  final List<double> liveAmplitudes;

  /// Complete normalized amplitude values across the entire recording session.
  final List<double> sessionAmplitudes;

  /// The note ID where the recording was started.
  final String? activeNoteId;

  /// The local temporary file receiving the raw encoded audio container.
  final File? workingFile;

  /// Timestamp when the recording session officially started.
  final DateTime? recordingStartTime;

  /// Error description if [status] == [AudioJournalStatus.failed].
  final String? errorMessage;

  /// Captured Super Editor node ID at recording initiation for stable cursor anchoring.
  final String? capturedNodeId;

  /// Captured text offset within node or plain-text document.
  final int? capturedCaretOffset;

  bool get isIdle => status == AudioJournalStatus.idle;
  bool get isRecording => status == AudioJournalStatus.recording;
  bool get isPaused => status == AudioJournalStatus.paused;
  bool get isBusy =>
      status == AudioJournalStatus.requestingPermission ||
      status == AudioJournalStatus.preparing ||
      status == AudioJournalStatus.finalizing ||
      status == AudioJournalStatus.encrypting ||
      status == AudioJournalStatus.saving;
  bool get isFinalizing =>
      status == AudioJournalStatus.finalizing ||
      status == AudioJournalStatus.encrypting ||
      status == AudioJournalStatus.saving;
  bool get isActive => isRecording || isPaused || isBusy;
  bool get hasFailed => status == AudioJournalStatus.failed;

  AudioJournalRecordingSession copyWith({
    AudioJournalStatus? status,
    Duration? elapsedDuration,
    double? currentDecibels,
    List<double>? liveAmplitudes,
    List<double>? sessionAmplitudes,
    String? activeNoteId,
    File? workingFile,
    DateTime? recordingStartTime,
    String? errorMessage,
    String? capturedNodeId,
    int? capturedCaretOffset,
  }) {
    return AudioJournalRecordingSession(
      status: status ?? this.status,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      currentDecibels: currentDecibels ?? this.currentDecibels,
      liveAmplitudes: liveAmplitudes ?? this.liveAmplitudes,
      sessionAmplitudes: sessionAmplitudes ?? this.sessionAmplitudes,
      activeNoteId: activeNoteId ?? this.activeNoteId,
      workingFile: workingFile ?? this.workingFile,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
      errorMessage: errorMessage ?? this.errorMessage,
      capturedNodeId: capturedNodeId ?? this.capturedNodeId,
      capturedCaretOffset: capturedCaretOffset ?? this.capturedCaretOffset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioJournalRecordingSession &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          elapsedDuration == other.elapsedDuration &&
          currentDecibels == other.currentDecibels &&
          listEquals(liveAmplitudes, other.liveAmplitudes) &&
          activeNoteId == other.activeNoteId &&
          workingFile?.path == other.workingFile?.path &&
          recordingStartTime == other.recordingStartTime &&
          errorMessage == other.errorMessage &&
          capturedNodeId == other.capturedNodeId &&
          capturedCaretOffset == other.capturedCaretOffset;

  @override
  int get hashCode => Object.hash(
        status,
        elapsedDuration,
        currentDecibels,
        Object.hashAll(liveAmplitudes),
        activeNoteId,
        workingFile?.path,
        recordingStartTime,
        errorMessage,
        capturedNodeId,
        capturedCaretOffset,
      );
}

/// Configuration settings for audio journal capture.
class AudioJournalConfig {
  const AudioJournalConfig({
    this.maxDuration = const Duration(minutes: 60),
    this.maxSizeBytes = 10 * 1024 * 1024, // 10 MB default (matches attachment limits)
    this.sampleRate = 44100,
    this.bitRate = 128000,
    this.numChannels = 1,
  });

  /// Maximum recording duration before auto-finalizing safely.
  final Duration maxDuration;

  /// Maximum permitted file size before safety stop.
  final int maxSizeBytes;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Target encoding bit rate in bps.
  final int bitRate;

  /// Audio channels (1 = mono, ideal for voice recordings).
  final int numChannels;
}
