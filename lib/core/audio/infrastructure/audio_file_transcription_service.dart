import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../../attachments/attachment_service.dart';
import '../../speech/application/speech_model_manager.dart';
import '../../speech/domain/speech_recognition_engine.dart';
import '../domain/audio_transcript_models.dart';

/// Service responsible for preparing and transcribing saved audio attachments on-device.
class AudioFileTranscriptionService {
  AudioFileTranscriptionService({
    required this.attachmentService,
    required this.speechModelManager,
    required this.speechEngine,
    Directory? customTempDirectory,
  }) : _customTempDir = customTempDirectory;

  final AttachmentService attachmentService;
  final SpeechModelManager speechModelManager;
  final SpeechRecognitionEngine speechEngine;
  final Directory? _customTempDir;

  static const _uuid = Uuid();

  /// Currently running jobs keyed by attachment ID to prevent duplicate requests.
  final Map<String, Future<AudioTranscriptData?>> _activeJobs = {};

  /// Cancelled job identifiers.
  final Set<String> _cancelledJobs = {};

  /// Progress stream controller.
  final _progressControllers =
      <String, StreamController<AudioTranscriptionJobState>>{};

  /// Returns a progress stream for a specific attachment transcription job.
  Stream<AudioTranscriptionJobState> watchJob(String attachmentId) {
    return _progressControllers
        .putIfAbsent(
          attachmentId,
          () => StreamController<AudioTranscriptionJobState>.broadcast(),
        )
        .stream;
  }

  void _emit(String attachmentId, AudioTranscriptionJobState state) {
    final controller = _progressControllers[attachmentId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  /// App-private temporary directory for audio transcription.
  Future<Directory> getTranscriptionTempDirectory() async {
    if (_customTempDir != null) {
      if (!await _customTempDir.exists()) {
        await _customTempDir.create(recursive: true);
      }
      return _customTempDir;
    }
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'audio_transcription'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Whether a job for [attachmentId] is currently running.
  bool isJobActive(String attachmentId) => _activeJobs.containsKey(attachmentId);

  /// Transcribes an existing encrypted audio recording attachment.
  ///
  /// Guarantees:
  /// 1. Original audio attachment is never mutated or re-encoded.
  /// 2. Audio is processed 100% locally on-device.
  /// 3. Temporary decrypted and converted files are deleted in a [finally] block.
  /// 4. Cancellation discards the result safely.
  Future<AudioTranscriptData?> transcribeAttachment({
    required String attachmentId,
    String? preferredLanguage,
    void Function(AudioTranscriptionJobState state)? onStateChange,
  }) {
    if (_activeJobs.containsKey(attachmentId)) {
      debugPrint('[AudioTranscription] Job for $attachmentId already active.');
      return _activeJobs[attachmentId]!;
    }

    _cancelledJobs.remove(attachmentId);

    late final Future<AudioTranscriptData?> future;
    future = _runTranscriptionPipeline(
      attachmentId: attachmentId,
      preferredLanguage: preferredLanguage,
      onStateChange: onStateChange,
    ).whenComplete(() {
      _activeJobs.remove(attachmentId);
    });

    _activeJobs[attachmentId] = future;
    return future;
  }

  Future<AudioTranscriptData?> _runTranscriptionPipeline({
    required String attachmentId,
    String? preferredLanguage,
    void Function(AudioTranscriptionJobState state)? onStateChange,
  }) async {
    void updateState(AudioTranscriptionJobState state) {
      _emit(attachmentId, state);
      onStateChange?.call(state);
    }

    File? decryptedTempFile;
    File? convertedWavFile;

    try {
      // 1. Check Model Installation
      updateState(const AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.checkingModel,
        stageLabel: 'Checking speech model…',
      ));

      if (_isCancelled(attachmentId)) return null;

      final modelStatus = await speechModelManager.checkStatus();
      if (!modelStatus.isInstalled || modelStatus.modelPath == null) {
        updateState(const AudioTranscriptionJobState(
          status: AudioTranscriptionStatus.failed,
          errorMessage: 'Speech model is not installed. Please download the speech model in Settings.',
        ));
        return null;
      }

      // Ensure speech engine is initialized with the installed model
      if (!speechEngine.isLoaded) {
        await speechEngine.initialize(modelPath: modelStatus.modelPath!);
      }

      if (_isCancelled(attachmentId)) return null;

      // 2. Prepare Audio (Decrypt from vault into ephemeral private storage)
      updateState(const AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.preparingAudio,
        stageLabel: 'Preparing audio…',
      ));

      final resolution = await attachmentService.resolveAsset(attachmentId);
      if (!resolution.isAvailable || resolution.data == null) {
        updateState(AudioTranscriptionJobState(
          status: AudioTranscriptionStatus.failed,
          errorMessage: resolution.errorMessage ?? 'Audio recording could not be decrypted.',
        ));
        return null;
      }

      if (_isCancelled(attachmentId)) return null;

      final tempDir = await getTranscriptionTempDirectory();
      final entity = await attachmentService.database.getAttachment(attachmentId);
      final isWav = entity?.fileName.toLowerCase().endsWith('.wav') == true ||
          entity?.mimeType.contains('wav') == true;

      final rawExt = isWav ? 'wav' : 'm4a';
      final tempRawPath = p.join(tempDir.path, 'decrypted_${_uuid.v4()}.$rawExt');
      decryptedTempFile = File(tempRawPath);
      await decryptedTempFile.writeAsBytes(resolution.data!);

      if (_isCancelled(attachmentId)) return null;

      // 3. Audio format check / conversion to 16kHz mono WAV if necessary
      File targetAudioForEngine = decryptedTempFile;

      if (!isWav) {
        final convertedPath = p.join(tempDir.path, 'converted_${_uuid.v4()}.wav');
        convertedWavFile = File(convertedPath);

        try {
          final converter = WhisperAudioConvert(
            audioInput: decryptedTempFile,
            audioOutput: convertedWavFile,
          );
          final res = await converter.convert();
          if (res != null && await res.exists() && await res.length() > 100) {
            targetAudioForEngine = res;
          } else {
            // Conversion failed or produced empty output
            throw StateError('Audio format conversion to 16kHz WAV failed.');
          }
        } catch (e) {
          debugPrint('[AudioTranscription] Audio conversion failed: $e');
          updateState(AudioTranscriptionJobState(
            status: AudioTranscriptionStatus.failed,
            errorMessage: 'Could not convert audio recording for transcription: $e',
          ));
          return null;
        }
      }

      if (_isCancelled(attachmentId)) return null;

      // 4. Run Whisper Transcription on device
      updateState(const AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.transcribing,
        stageLabel: 'Transcribing on device…',
      ));

      final effectiveLang = preferredLanguage ?? speechModelManager.descriptor.languageCode;

      final rawTranscript = await speechEngine.transcribe(
        audioPath: targetAudioForEngine.path,
        lang: effectiveLang,
        onProgress: (percent) {
          if (!_isCancelled(attachmentId)) {
            updateState(AudioTranscriptionJobState(
              status: AudioTranscriptionStatus.transcribing,
              stageLabel: 'Transcribing on device…',
              progressPercent: percent,
            ));
          }
        },
      );

      if (_isCancelled(attachmentId)) return null;

      final cleanTranscript = rawTranscript.trim();
      if (cleanTranscript.isEmpty) {
        updateState(const AudioTranscriptionJobState(
          status: AudioTranscriptionStatus.failed,
          errorMessage: 'No recognizable speech was found in this recording.',
        ));
        return null;
      }

      // 5. Saving Transcript
      updateState(const AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.savingTranscript,
        stageLabel: 'Saving transcript…',
      ));

      final result = AudioTranscriptData(
        text: cleanTranscript,
        language: effectiveLang,
        isEdited: false,
        timestamp: DateTime.now(),
        engine: speechModelManager.descriptor.name,
      );

      updateState(AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.available,
        stageLabel: 'Completed',
        transcriptData: result,
      ));

      return result;
    } catch (e) {
      debugPrint('[AudioTranscription] Pipeline error for $attachmentId: $e');
      updateState(AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.failed,
        errorMessage: 'Transcription failed: $e',
      ));
      return null;
    } finally {
      // 6. Mandatory cleanup of ephemeral decrypted and converted files
      try {
        if (decryptedTempFile != null && await decryptedTempFile.exists()) {
          await decryptedTempFile.delete();
        }
      } catch (_) {}
      try {
        if (convertedWavFile != null && await convertedWavFile.exists()) {
          await convertedWavFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Cancels an in-flight transcription request for [attachmentId].
  void cancelTranscription(String attachmentId) {
    if (_activeJobs.containsKey(attachmentId)) {
      _cancelledJobs.add(attachmentId);
      _emit(
        attachmentId,
        const AudioTranscriptionJobState(
          status: AudioTranscriptionStatus.cancelled,
          stageLabel: 'Cancelled',
        ),
      );
    }
  }

  bool _isCancelled(String attachmentId) => _cancelledJobs.contains(attachmentId);

  /// Disposes active stream controllers and clears jobs.
  void dispose() {
    _cancelledJobs.addAll(_activeJobs.keys);
    _activeJobs.clear();
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
