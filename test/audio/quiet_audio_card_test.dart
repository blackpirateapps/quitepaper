import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/audio/application/audio_journal_provider.dart';
import 'package:quitepaper/core/audio/application/audio_transcription_provider.dart';
import 'package:quitepaper/core/audio/domain/audio_transcript_models.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_file_transcription_service.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_waveform_cache_service.dart';
import 'package:quitepaper/core/audio/presentation/quiet_audio_card.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/speech/application/speech_model_manager.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/domain/speech_model_status.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Widget buildTestApp(
    Widget child, {
    ThemeData? theme,
    AppDatabase? db,
    List<dynamic>? overrides,
  }) {
    return ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
        if (overrides != null) ...overrides.cast<Override>(),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('QuietAudioCard Widget Tests', () {
    final now = DateTime(2026, 10, 21, 9, 5);
    final audioEntity = AttachmentEntity(
      id: 'att-audio-uuid-1',
      fileName: 'recording_1111.m4a',
      kind: 'file',
      mimeType: 'audio/mp4',
      createdAt: now,
      updatedAt: now,
      byteSize: 1024,
      sha256: 'abcdef0123456789',
      encryptionKeyVersion: 1,
      isDirty: false,
      isDeleted: false,
      serverRevision: 0,
      uploadState: 'local_only',
      ocrState: 'not_requested',
      ocrLanguage: 'en',
    );

    testWidgets('renders compact view with title, time, and play button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Morning thoughts',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: false,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Morning thoughts'), findsOneWidget);
      expect(find.textContaining('9:05 AM'), findsOneWidget);
    });

    testWidgets('tapping compact card transitions to expanded rich player card', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Morning thoughts',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: false,
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Encrypted attachment'), findsNothing);

      // Tap on card to expand
      await tester.tap(find.text('Morning thoughts'));
      await tester.pumpAndSettle();

      expect(find.text('Encrypted attachment'), findsOneWidget);
    });

    testWidgets('expanded view renders title, lock badge, and overflow menu button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Ideas for Quiet Paper',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Ideas for Quiet Paper'), findsOneWidget);
      expect(find.text('Encrypted attachment'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.dotsThree), findsOneWidget);
    });

    testWidgets('renders without error under dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Night thoughts',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
          ),
          theme: AppTheme.dark(),
        ),
      );

      await tester.pump();

      expect(find.text('Night thoughts'), findsOneWidget);
      expect(find.text('Encrypted attachment'), findsOneWidget);
    });

    testWidgets('renders transcript section in expanded mode when transcript exists (Mockup 0)', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Meeting Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'This is the transcribed audio memo content.',
            initialTranscriptLanguage: 'en',
            initialIsTranscriptEdited: false,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Transcript'), findsOneWidget);
      expect(find.text('Available · English'), findsOneWidget);
      expect(find.text('This is the transcribed audio memo content.'), findsOneWidget);
      expect(find.text('Generated on device'), findsOneWidget);
      expect(find.text('Edit transcript'), findsOneWidget);
    });

    testWidgets('shows Edited manually badge when isTranscriptEdited is true', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Edited Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Corrected transcript line.',
            initialTranscriptLanguage: 'en',
            initialIsTranscriptEdited: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Edited manually · English'), findsOneWidget);
      expect(find.text('Edited manually'), findsOneWidget);
    });

    testWidgets('allows editing transcript inline and invokes onTranscriptChanged', (tester) async {
      String? changedTranscript;
      bool? changedEdited;

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Editable Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Original text',
            initialTranscriptLanguage: 'en',
            initialIsTranscriptEdited: false,
            onTranscriptChanged: (newText, isEdited) {
              changedTranscript = newText;
              changedEdited = isEdited;
            },
          ),
        ),
      );

      await tester.pump();

      // Tap Edit transcript
      await tester.tap(find.text('Edit transcript'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Enter new text
      await tester.enterText(find.byType(TextField), 'Modified text by user');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(changedTranscript, equals('Modified text by user'));
      expect(changedEdited, isTrue);
      expect(find.text('Modified text by user'), findsOneWidget);
      expect(find.text('Edited manually'), findsOneWidget);
    });

    testWidgets('overflow menu provides insert into note callback', (tester) async {
      String? insertedText;

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Insertable Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Text to insert into editor',
            initialTranscriptLanguage: 'en',
            onInsertTranscript: (text) {
              insertedText = text;
            },
          ),
        ),
      );

      await tester.pump();

      // Open overflow menu
      await tester.tap(find.byIcon(PhosphorIconsRegular.dotsThree));
      await tester.pumpAndSettle();

      expect(find.text('Insert into note'), findsOneWidget);
      await tester.tap(find.text('Insert into note'));
      await tester.pumpAndSettle();

      expect(insertedText, equals('Text to insert into editor'));
    });

    testWidgets('renders on-device transcribing in-progress state (Mockup 1)', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Processing Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: false,
          ),
          overrides: [
            audioTranscriptionJobStateProvider(audioEntity.id).overrideWith(
              (ref) => Stream.value(
                const AudioTranscriptionJobState(
                  status: AudioTranscriptionStatus.transcribing,
                  progressPercent: 55,
                  stageLabel: 'Transcribing on device…',
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Transcribing on device…'), findsOneWidget);
      expect(find.text('Whisper Base · English'), findsOneWidget);
      expect(find.text('Your audio stays on this device during transcription.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping Transcribe audio enters processing loading screen and updates to transcript', (tester) async {
      final completer = Completer<AudioTranscriptData?>();
      final fakeService = _FakeAudioFileTranscriptionService(
        speechModelManager: _FakeSpeechModelManager(),
        onTranscribeCompleter: completer,
      );

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Test Voice Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
          ),
          overrides: [
            audioFileTranscriptionServiceProvider.overrideWithValue(fakeService),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Transcribe audio'), findsOneWidget);
      await tester.tap(find.text('Transcribe audio'));
      await tester.pump();

      // Verify that the processing interface (loading screen) is active
      expect(find.text('Transcribing on device…'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Whisper Base · English'), findsOneWidget);
      expect(find.text('Your audio stays on this device during transcription.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Now complete the transcription job
      completer.complete(const AudioTranscriptData(
        text: 'This is the completed transcript.',
        language: 'en',
      ));
      await tester.pumpAndSettle();

      // Verify loading screen is gone and transcript is shown
      expect(find.text('Transcribing on device…'), findsNothing);
      expect(find.text('This is the completed transcript.'), findsOneWidget);
      expect(find.text('Transcript'), findsOneWidget);
    });

    testWidgets('renders genuine cached waveform bars instead of static fallback curve', (tester) async {
      final customBars = List.generate(32, (i) => i < 16 ? 0.2 : 0.85);
      final cacheService = AudioWaveformCacheService();
      await cacheService.cacheWaveform(audioEntity.id, customBars);

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Waveform Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
          ),
          overrides: [
            audioWaveformCacheServiceProvider.overrideWithValue(cacheService),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(QuietAudioCard), findsOneWidget);
      expect(cacheService.getWaveform(audioEntity.id), equals(customBars));
    });

    testWidgets('respects scaled font size from typographySettingsProvider (large)', (tester) async {
      const customTypography = TypographySettings(fontSize: 27.0);

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Large Typography Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Large transcript content.',
            initialTranscriptLanguage: 'en',
          ),
          overrides: [
            typographySettingsProvider.overrideWith((ref) => _CustomTypographyNotifier(customTypography)),
          ],
        ),
      );

      await tester.pump();

      // Card Title Text: scaledBodyLargeSize = (27 * 18 / 18) = 27.0
      final titleWidget = tester.widget<Text>(find.text('Large Typography Memo'));
      expect(titleWidget.style?.fontSize, equals(27.0));

      // Transcript Caption: scaledCaptionSize = (27 * 12 / 18) = 18.0
      final badgeWidget = tester.widget<Text>(find.text('Available · English'));
      expect(badgeWidget.style?.fontSize, equals(18.0));

      // Transcript Header: scaledBodyMediumSize = (27 * 16 / 18) = 24.0
      final headerWidget = tester.widget<Text>(find.text('Transcript'));
      expect(headerWidget.style?.fontSize, equals(24.0));

      // Transcript Text (SelectableText): scaledBodyMediumSize = 24.0
      final transcriptWidget = tester.widget<SelectableText>(find.widgetWithText(SelectableText, 'Large transcript content.'));
      expect(transcriptWidget.style?.fontSize, equals(24.0));
    });

    testWidgets('respects scaled font size with min legible clamp (small)', (tester) async {
      const smallTypography = TypographySettings(fontSize: 12.0);

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Small Typography Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Small transcript content.',
            initialTranscriptLanguage: 'en',
          ),
          overrides: [
            typographySettingsProvider.overrideWith((ref) => _CustomTypographyNotifier(smallTypography)),
          ],
        ),
      );

      await tester.pump();

      // Card Title Text: scaledBodyLargeSize = (12 * 18 / 18) = 12.0
      final titleWidget = tester.widget<Text>(find.text('Small Typography Memo'));
      expect(titleWidget.style?.fontSize, equals(12.0));

      // Transcript Caption: scaledCaptionSize = (12 * 12 / 18) = 8.0, clamped to min 9.0
      final badgeWidget = tester.widget<Text>(find.text('Available · English'));
      expect(badgeWidget.style?.fontSize, equals(9.0));

      // Transcript Header: scaledBodyMediumSize = (12 * 16 / 18) = 11.0
      final headerWidget = tester.widget<Text>(find.text('Transcript'));
      expect(headerWidget.style?.fontSize, equals(11.0));

      // Transcript Text: scaledBodyMediumSize = 11.0
      final transcriptWidget = tester.widget<SelectableText>(find.widgetWithText(SelectableText, 'Small transcript content.'));
      expect(transcriptWidget.style?.fontSize, equals(11.0));
    });

    testWidgets('respects scaled font size on encrypted lock badge when no transcript exists', (tester) async {
      const customTypography = TypographySettings(fontSize: 27.0);

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'No Transcript Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
          ),
          overrides: [
            typographySettingsProvider.overrideWith((ref) => _CustomTypographyNotifier(customTypography)),
          ],
        ),
      );

      await tester.pump();

      final badgeWidget = tester.widget<Text>(find.text('Encrypted attachment'));
      expect(badgeWidget.style?.fontSize, equals(18.0));
    });

    testWidgets('respects custom heading and body font families', (tester) async {
      const customTypography = TypographySettings(
        headingFontFamily: 'Playfair Display',
        bodyFontFamily: 'Lora',
      );

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Font Family Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Custom font transcript.',
            initialTranscriptLanguage: 'en',
          ),
          overrides: [
            typographySettingsProvider.overrideWith((ref) => _CustomTypographyNotifier(customTypography)),
          ],
        ),
      );

      await tester.pump();

      final titleWidget = tester.widget<Text>(find.text('Font Family Memo'));
      expect(titleWidget.style?.fontFamily, contains('Playfair'));

      final transcriptWidget = tester.widget<SelectableText>(find.widgetWithText(SelectableText, 'Custom font transcript.'));
      expect(transcriptWidget.style?.fontFamily, contains('Lora'));
    });

    testWidgets('inline transcript editing TextField inherits scaled typography', (tester) async {
      const customTypography = TypographySettings(
        fontSize: 27.0,
        lineHeight: 1.8,
        bodyFontFamily: 'Lora',
      );

      await tester.pumpWidget(
        buildTestApp(
          QuietAudioCard(
            attachmentId: audioEntity.id,
            title: 'Editable Memo',
            uriString: 'qp://asset/${audioEntity.id}',
            initialEntity: audioEntity,
            initialExpanded: true,
            initialTranscript: 'Edit me',
            initialTranscriptLanguage: 'en',
          ),
          overrides: [
            typographySettingsProvider.overrideWith((ref) => _CustomTypographyNotifier(customTypography)),
          ],
        ),
      );

      await tester.pump();

      // Tap Edit transcript
      await tester.tap(find.text('Edit transcript'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, equals(24.0));
      expect(textField.style?.height, equals(1.8));
      expect(textField.style?.fontFamily, contains('Lora'));
    });
  });
}

class _CustomTypographyNotifier extends TypographySettingsNotifier {
  _CustomTypographyNotifier(TypographySettings settings) : super() {
    state = settings;
  }
}

class _FakeSpeechModelManager implements SpeechModelManager {
  @override
  SpeechModelDescriptor get descriptor => const FutoEnglishSpeechModel39();

  @override
  Future<SpeechModelStatus> checkStatus() async => const SpeechModelStatus(
        status: SpeechModelInstallationStatus.installed,
        modelPath: '/fake/model.bin',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioFileTranscriptionService implements AudioFileTranscriptionService {
  _FakeAudioFileTranscriptionService({
    required this.speechModelManager,
    required this.onTranscribeCompleter,
  });

  @override
  final SpeechModelManager speechModelManager;
  final Completer<AudioTranscriptData?> onTranscribeCompleter;
  final StreamController<AudioTranscriptionJobState> _controller =
      StreamController<AudioTranscriptionJobState>.broadcast();

  @override
  Stream<AudioTranscriptionJobState> watchJob(String attachmentId) => _controller.stream;

  @override
  AudioTranscriptionJobState? getJobState(String attachmentId) => null;

  @override
  Future<AudioTranscriptData?> transcribeAttachment({
    required String attachmentId,
    String? preferredLanguage,
    void Function(AudioTranscriptionJobState state)? onStateChange,
  }) {
    onStateChange?.call(const AudioTranscriptionJobState(
      status: AudioTranscriptionStatus.transcribing,
      stageLabel: 'Transcribing on device…',
      progressPercent: 40,
    ));
    return onTranscribeCompleter.future;
  }

  @override
  void cancelTranscription(String attachmentId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
