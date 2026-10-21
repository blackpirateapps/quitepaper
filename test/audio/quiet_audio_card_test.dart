import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/audio/application/audio_transcription_provider.dart';
import 'package:quitepaper/core/audio/domain/audio_transcript_models.dart';
import 'package:quitepaper/core/audio/presentation/quiet_audio_card.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
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
      expect(find.text('Encrypted attachment · Available offline'), findsNothing);

      // Tap on card to expand
      await tester.tap(find.text('Morning thoughts'));
      await tester.pumpAndSettle();

      expect(find.text('Encrypted attachment · Available offline'), findsOneWidget);
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
      expect(find.text('Encrypted attachment · Available offline'), findsOneWidget);
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
      expect(find.text('Encrypted attachment · Available offline'), findsOneWidget);
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
  });
}
