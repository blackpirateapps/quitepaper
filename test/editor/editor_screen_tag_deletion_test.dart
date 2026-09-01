import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_tag_chip.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('EditorScreen Tag Deletion UI Integration', () {
    late AppDatabase db;
    late NotesRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createEditorApp(Note note, {bool initialPreview = false}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: EditorScreen(
            note: note,
            initialPreviewMode: initialPreview,
          ),
        ),
      );
    }

    testWidgets('clicking delete cross on tag chip deletes tag and prevents resurrection',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-ui-tags-1',
        title: 'Project Roadmap',
        content: 'Working on features #ideas #flutter for release',
        createdAt: now,
        updatedAt: now,
        tags: ['flutter', 'ideas'],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Verify both tag chips are rendered
      expect(find.text('#flutter'), findsOneWidget);
      expect(find.text('#ideas'), findsOneWidget);

      // Find the delete button (close icon) on the '#ideas' chip
      final ideasChip = find.ancestor(
        of: find.text('#ideas'),
        matching: find.byType(QuietTagChip),
      );
      expect(ideasChip, findsOneWidget);

      final closeIconOnIdeas = find.descendant(
        of: ideasChip,
        matching: find.byIcon(PhosphorIconsRegular.x),
      );
      expect(closeIconOnIdeas, findsOneWidget);

      // Tap delete cross on '#ideas'
      await tester.tap(closeIconOnIdeas);
      await tester.pumpAndSettle();

      // Verify '#ideas' chip is gone and '#flutter' remains
      expect(find.text('#ideas'), findsNothing);
      expect(find.text('#flutter'), findsOneWidget);

      // Wait for debouncer / autosave
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify '#ideas' does NOT resurrect at the end
      expect(find.text('#ideas'), findsNothing);
      expect(find.text('#flutter'), findsOneWidget);

      // Verify persistence in SQLite
      final updatedNote = await repository.getNoteById('note-ui-tags-1');
      expect(updatedNote!.tags, equals(['flutter']));
      expect(updatedNote.content, equals('Working on features #flutter for release'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('deleting last tag in preview mode removes tag bar cleanly',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-ui-tags-2',
        title: 'Solo Note',
        content: 'Markdown preview test with #solo tag',
        createdAt: now,
        updatedAt: now,
        tags: ['solo'],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialPreview: true));
      await tester.pumpAndSettle();

      expect(find.text('#solo'), findsOneWidget);

      final soloChip = find.ancestor(
        of: find.text('#solo'),
        matching: find.byType(QuietTagChip),
      );
      final closeIcon = find.descendant(
        of: soloChip,
        matching: find.byIcon(PhosphorIconsRegular.x),
      );

      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(find.text('#solo'), findsNothing);
      expect(find.byType(QuietTagChip), findsNothing);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      final updatedNote = await repository.getNoteById('note-ui-tags-2');
      expect(updatedNote!.tags, isEmpty);
      expect(updatedNote.content, equals('Markdown preview test with tag'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
