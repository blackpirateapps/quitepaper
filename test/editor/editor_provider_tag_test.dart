import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('EditorNotifier Tag Deletion & Persistence', () {
    test('removing tag updates state, removes hashtag from content, and does not resurrect on saveNow()', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-1',
        title: 'Meeting Notes',
        content: 'Discussing roadmap with team #planning #q3',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['planning', 'q3'],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      // Verify initial tags
      expect(notifier.state.note.tags, equals(['planning', 'q3']));

      // Remove tag 'planning'
      notifier.removeTag('planning');

      // Verify tag is removed from state immediately
      expect(notifier.state.note.tags, equals(['q3']));

      // Verify #planning is removed from note content
      expect(notifier.state.note.content, equals('Discussing roadmap with team #q3'));

      // Trigger saveNow() and verify 'planning' does not resurrect at the end
      await notifier.saveNow();
      expect(notifier.state.note.tags, equals(['q3']));

      // Verify database state
      final savedNote = await repository.getNoteById('note-tag-1');
      expect(savedNote, isNotNull);
      expect(savedNote!.tags, equals(['q3']));
      expect(savedNote.content, equals('Discussing roadmap with team #q3'));
    });

    test('removing tag present in title removes it from title and does not resurrect', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-2',
        title: 'Project #urgent discussion',
        content: 'Body text without tags',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['urgent'],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      expect(notifier.state.note.tags, equals(['urgent']));

      // Remove 'urgent'
      notifier.removeTag('urgent');

      expect(notifier.state.note.tags, isEmpty);
      expect(notifier.state.note.title, equals('Project discussion'));

      await notifier.saveNow();
      expect(notifier.state.note.tags, isEmpty);

      final savedNote = await repository.getNoteById('note-tag-2');
      expect(savedNote!.tags, isEmpty);
      expect(savedNote.title, equals('Project discussion'));
    });

    test('removing solitary/last tag saves note with empty tags list in repository', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-3',
        title: 'Solo Tag Note',
        content: 'Some notes #solo',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['solo'],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      expect(notifier.state.note.tags, equals(['solo']));

      notifier.removeTag('solo');
      expect(notifier.state.note.tags, isEmpty);
      expect(notifier.state.note.content, equals('Some notes'));

      await notifier.saveNow();

      final savedNote = await repository.getNoteById('note-tag-3');
      expect(savedNote!.tags, isEmpty);
    });

    test('removing explicit metadata tag not present in content works seamlessly', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-4',
        title: 'Explicit Tag Note',
        content: 'No hashtags typed in text',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['imported_tag', 'extra_tag'],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      expect(notifier.state.note.tags, equals(['imported_tag', 'extra_tag']));

      notifier.removeTag('imported_tag');
      expect(notifier.state.note.tags, equals(['extra_tag']));
      expect(notifier.state.note.content, equals('No hashtags typed in text'));

      await notifier.saveNow();

      final savedNote = await repository.getNoteById('note-tag-4');
      expect(savedNote!.tags, equals(['extra_tag']));
    });
  });
}
