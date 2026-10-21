import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/attachment_provider.dart';
import '../../speech/application/speech_provider.dart';
import '../domain/audio_transcript_models.dart';
import '../infrastructure/audio_file_transcription_service.dart';

/// Provider for the singleton [AudioFileTranscriptionService].
final audioFileTranscriptionServiceProvider =
    Provider<AudioFileTranscriptionService>((ref) {
  final attachmentService = ref.watch(attachmentServiceProvider);
  final modelManager = ref.watch(speechModelManagerProvider);
  final engine = ref.watch(speechRecognitionEngineProvider);

  final service = AudioFileTranscriptionService(
    attachmentService: attachmentService,
    speechModelManager: modelManager,
    speechEngine: engine,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for tracking live transcription job status of a specific attachment.
final audioTranscriptionJobStateProvider = StreamProvider.autoDispose
    .family<AudioTranscriptionJobState, String>((ref, attachmentId) {
  final service = ref.watch(audioFileTranscriptionServiceProvider);
  return service.watchJob(attachmentId);
});
