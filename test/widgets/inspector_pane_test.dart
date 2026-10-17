import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/attachments/presentation/attachment_details_sheet.dart';
import 'package:quitepaper/core/attachments/presentation/attachment_file_info_sheet.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_editorial_dialog.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/editor/presentation/widgets/editor_inspector_pane.dart';
import 'package:quitepaper/features/editor/presentation/widgets/version_history_sheet.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: ThemeData(
          platform: platform,
          extensions: const [
            AppColors.light,
          ],
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  AttachmentEntity createSampleEntity() {
    final now = DateTime.now();
    return AttachmentEntity(
      id: 'test-att-1',
      fileName: 'document.pdf',
      kind: 'file',
      createdAt: now,
      updatedAt: now,
      mimeType: 'application/pdf',
      byteSize: 1024,
      sha256: 'abcdef1234567890abcdef',
      encryptionKeyVersion: 1,
      isDirty: false,
      isDeleted: false,
      serverRevision: 0,
      uploadState: 'local_only',
      ocrState: 'not_requested',
      ocrLanguage: 'en',
    );
  }

  Note createSampleNote() {
    final now = DateTime.now();
    return Note(
      id: 'test-note-1',
      title: 'Sample Note',
      content: 'Hello inspector world',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Phase 5: Multi-Pane Right Inspector Pane Tests', () {
    testWidgets('EditorInspectorPane remains empty when inspector is closed', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: const Row(
            children: [
              Expanded(child: Text('Main Editor Body')),
              EditorInspectorPane(),
            ],
          ),
        ),
      );

      expect(find.text('Main Editor Body'), findsOneWidget);
      expect(find.byType(VersionHistorySheet), findsNothing);
      expect(find.byType(AttachmentDetailsSheet), findsNothing);
      expect(find.byType(AttachmentFileInfoSheet), findsNothing);
    });

    testWidgets('VersionHistorySheet docks into EditorInspectorPane on widescreen and closes via header button', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = createSampleNote();

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      VersionHistorySheet.show(
                        ctx,
                        note: note,
                        currentTitle: note.title,
                        currentContent: note.content,
                        currentTags: note.tags,
                        onRestoreVersion: (_) async {},
                      );
                    },
                    child: const Text('Open Version History'),
                  ),
                ),
                const EditorInspectorPane(),
              ],
            ),
          ),
        ),
      );

      // Initially closed
      expect(find.byType(VersionHistorySheet), findsNothing);

      // Open version history
      await tester.tap(find.text('Open Version History'));
      await tester.pumpAndSettle();

      // Docks in inspector pane without opening a modal route
      expect(find.byType(VersionHistorySheet), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Version History'), findsOneWidget);

      // Find and tap close button
      final closeButton = find.byType(QuietIconButton);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Inspector pane closed
      expect(find.byType(VersionHistorySheet), findsNothing);
    });

    testWidgets('AttachmentFileInfoSheet docks into EditorInspectorPane on widescreen desktop', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final entity = createSampleEntity();

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      AttachmentFileInfoSheet.show(ctx, entity: entity);
                    },
                    child: const Text('Open File Info'),
                  ),
                ),
                const EditorInspectorPane(),
              ],
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('Open File Info'));
      await tester.pumpAndSettle();

      // Docks into inspector pane
      expect(find.byType(AttachmentFileInfoSheet), findsOneWidget);
      expect(find.text('document.pdf'), findsAtLeastNWidgets(1));
      expect(find.text('File Name'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsNothing);

      // Close inspector
      final closeButton = find.byType(QuietIconButton);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentFileInfoSheet), findsNothing);
    });

    testWidgets('AttachmentFileInfoSheet falls back to centered dialog on narrow desktop (< 1100dp)', (tester) async {
      // Narrow desktop viewport
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final entity = createSampleEntity();

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  AttachmentFileInfoSheet.show(ctx, entity: entity);
                },
                child: const Text('Open File Info'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open File Info'));
      await tester.pumpAndSettle();

      // Renders inside QuietEditorialDialogCard
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.text('document.pdf'), findsAtLeastNWidgets(1));

      // Closes with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(QuietEditorialDialogCard), findsNothing);
    });

    testWidgets('AttachmentFileInfoSheet opens BottomSheet on Android platform', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  AttachmentFileInfoSheet.show(ctx, entity: createSampleEntity());
                },
                child: const Text('Open Mobile Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Mobile Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('document.pdf'), findsAtLeastNWidgets(1));
    });
  });
}
