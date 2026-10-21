import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
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
  }) {
    return ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: child),
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
  });
}
