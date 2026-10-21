import 'package:flutter/foundation.dart';

/// Processing lifecycle states for audio transcription.
enum AudioTranscriptionStatus {
  idle,
  checkingModel,
  preparingAudio,
  transcribing,
  savingTranscript,
  available,
  failed,
  cancelled,
}

/// Immutable record of a recognized or edited audio transcript.
@immutable
class AudioTranscriptData {
  const AudioTranscriptData({
    required this.text,
    this.language = 'en',
    this.isEdited = false,
    this.timestamp,
    this.engine = 'whisper_ggml',
  });

  /// The recognized or user-edited text of the audio memo.
  final String text;

  /// ISO language code of the recognition result (e.g. 'en', 'auto').
  final String language;

  /// Whether the transcript was modified by the user after generation.
  final bool isEdited;

  /// Timestamp when the transcript was originally generated or last updated.
  final DateTime? timestamp;

  /// Name of the speech engine that produced the original transcript.
  final String engine;

  bool get isEmpty => text.trim().isEmpty;
  bool get isNotEmpty => text.trim().isNotEmpty;

  AudioTranscriptData copyWith({
    String? text,
    String? language,
    bool? isEdited,
    DateTime? timestamp,
    String? engine,
  }) {
    return AudioTranscriptData(
      text: text ?? this.text,
      language: language ?? this.language,
      isEdited: isEdited ?? this.isEdited,
      timestamp: timestamp ?? this.timestamp,
      engine: engine ?? this.engine,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language,
        'isEdited': isEdited,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
        'engine': engine,
      };

  factory AudioTranscriptData.fromJson(Map<String, dynamic> json) {
    return AudioTranscriptData(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      isEdited: json['isEdited'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
      engine: json['engine'] as String? ?? 'whisper_ggml',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTranscriptData &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          language == other.language &&
          isEdited == other.isEdited &&
          timestamp == other.timestamp &&
          engine == other.engine;

  @override
  int get hashCode => Object.hash(text, language, isEdited, timestamp, engine);

  @override
  String toString() =>
      'AudioTranscriptData(language: $language, isEdited: $isEdited, len: ${text.length})';
}

/// Active job progress state for in-flight transcription.
@immutable
class AudioTranscriptionJobState {
  const AudioTranscriptionJobState({
    this.status = AudioTranscriptionStatus.idle,
    this.stageLabel = '',
    this.progressPercent,
    this.errorMessage,
    this.transcriptData,
  });

  final AudioTranscriptionStatus status;
  final String stageLabel;
  final int? progressPercent;
  final String? errorMessage;
  final AudioTranscriptData? transcriptData;

  bool get isIdle => status == AudioTranscriptionStatus.idle;
  bool get isBusy =>
      status == AudioTranscriptionStatus.checkingModel ||
      status == AudioTranscriptionStatus.preparingAudio ||
      status == AudioTranscriptionStatus.transcribing ||
      status == AudioTranscriptionStatus.savingTranscript;
  bool get isTranscribing => status == AudioTranscriptionStatus.transcribing;
  bool get isCompleted => status == AudioTranscriptionStatus.available;
  bool get hasFailed => status == AudioTranscriptionStatus.failed;
  bool get isCancelled => status == AudioTranscriptionStatus.cancelled;

  AudioTranscriptionJobState copyWith({
    AudioTranscriptionStatus? status,
    String? stageLabel,
    int? progressPercent,
    String? errorMessage,
    AudioTranscriptData? transcriptData,
    bool clearError = false,
  }) {
    return AudioTranscriptionJobState(
      status: status ?? this.status,
      stageLabel: stageLabel ?? this.stageLabel,
      progressPercent: progressPercent ?? this.progressPercent,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      transcriptData: transcriptData ?? this.transcriptData,
    );
  }
}
