import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Desktop File Drop and Drag Overlay Tests', () {
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

    Widget createEditorApp(Note note) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: EditorScreen(note: note),
        ),
      );
    }

    testWidgets('EditorScreen contains DropTarget at root for desktop file drops', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-drop-1',
        title: 'Drop Target Test',
        content: 'Initial text',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      final dropTargetFinder = find.byType(DropTarget);
      expect(dropTargetFinder, findsOneWidget);

      final dropTarget = tester.widget<DropTarget>(dropTargetFinder);
      expect(dropTarget.onDragEntered, isNotNull);
      expect(dropTarget.onDragExited, isNotNull);
      expect(dropTarget.onDragDone, isNotNull);

      // Clean up timer callbacks
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('DropTarget onDragEntered displays visual drop overlay and onDragExited dismisses it', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'test-note-drop-2',
        title: 'Drop Overlay Test',
        content: 'Body content',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Before dragging over, drop target overlay is not visible
      expect(find.text('Drop file to insert into note'), findsNothing);
      expect(find.byIcon(Icons.file_upload_outlined), findsNothing);

      // Simulate dragging entered
      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(DropEventDetails(
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ));
      await tester.pump();

      // Overlay should now be visible with icon and prompt text
      expect(find.text('Drop files to attach to note'), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);

      // Simulate dragging exited
      dropTarget.onDragExited?.call(DropEventDetails(
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ));
      await tester.pump();

      // Overlay should be gone
      expect(find.text('Drop file to insert into note'), findsNothing);
      expect(find.byIcon(Icons.file_upload_outlined), findsNothing);

      // Clean up timer callbacks
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    });

    test('URI list and rawText path extraction resolves Linux Nautilus and Dolphin file formats', () {
      // Nautilus RFC 2483 URI list format
      const nautilusRaw = 'file:///home/dog/Documents/project%20diagram.png\r\nfile:///home/dog/Notes/report.pdf\r\n';
      final resolvedPaths = <String>[];

      final lines = nautilusRaw.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty);
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('file://')) {
          try {
            final uri = Uri.parse(trimmed);
            resolvedPaths.add(uri.toFilePath());
          } catch (_) {
            var path = trimmed.replaceFirst('file://', '');
            resolvedPaths.add(Uri.decodeComponent(path));
          }
        } else if (trimmed.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(trimmed)) {
          resolvedPaths.add(trimmed);
        }
      }

      expect(resolvedPaths, [
        '/home/dog/Documents/project diagram.png',
        '/home/dog/Notes/report.pdf',
      ]);
    });
  });
}
