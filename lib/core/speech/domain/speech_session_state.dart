/// States of an active speech dictation session in the editor.
enum SpeechSessionState {
  idle,
  checkingModel,
  requestingPermission,
  downloadingModel,
  loadingEngine,
  recording,
  transcribing,
  error,
}

/// Rich active session state representation.
class SpeechSession {
  const SpeechSession({
    this.state = SpeechSessionState.idle,
    this.recordingDuration = Duration.zero,
    this.errorMessage,
  });

  final SpeechSessionState state;
  final Duration recordingDuration;
  final String? errorMessage;

  bool get isIdle => state == SpeechSessionState.idle;
  bool get isRecording => state == SpeechSessionState.recording;
  bool get isTranscribing => state == SpeechSessionState.transcribing;
  bool get isDownloading => state == SpeechSessionState.downloadingModel;
  bool get isLoading => state == SpeechSessionState.loadingEngine;
  bool get isBusy => state != SpeechSessionState.idle && state != SpeechSessionState.error;

  SpeechSession copyWith({
    SpeechSessionState? state,
    Duration? recordingDuration,
    String? errorMessage,
  }) {
    return SpeechSession(
      state: state ?? this.state,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static const SpeechSession initial = SpeechSession();
}
