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
    test(
      'batch additions normalize, deduplicate and persist together once',
      () async {
        final now = DateTime.now();
        final note = Note(
          id: 'batch-tags',
          title: 'Batch',
          content: '',
          createdAt: now,
          updatedAt: now,
          tags: ['existing'],
        );
        await repository.saveNote(note);
        final counting = CountingTagRepository(db);
        final additions = <List<String>>[];
        final notifier = EditorNotifier(
          initialNote: note,
          repository: counting,
          onTagsAdded: additions.add,
        );
        addTearDown(notifier.dispose);

        notifier.addTags([
          '#Work/Project',
          'ideas',
          'work/project',
          'existing',
          '???',
        ]);
        await notifier.saveNow();
        expect(counting.saves, 1);
        expect(
          (await repository.getNoteById(note.id))!.tags,
          unorderedEquals(['existing', 'work/project', 'ideas']),
        );
        expect(additions, [
          ['work/project', 'ideas'],
        ]);
        notifier.addTags(['ideas', '#EXISTING']);
        await notifier.saveNow();
        expect(counting.saves, 1);
        expect(additions, hasLength(1));
      },
    );

    test(
      'inline additions report use only after successful persistence',
      () async {
        final now = DateTime.now();
        final note = Note(
          id: 'inline-recency',
          title: 'Inline',
          content: '',
          createdAt: now,
          updatedAt: now,
        );
        await repository.saveNote(note);
        final counting = CountingTagRepository(db)..failSaves = true;
        final additions = <List<String>>[];
        final notifier = EditorNotifier(
          initialNote: note,
          repository: counting,
          onTagsAdded: additions.add,
        );
        addTearDown(notifier.dispose);
        notifier.updateContent('Working on #work/project ');
        await notifier.saveNow();
        expect(additions, isEmpty);
        counting.failSaves = false;
        await notifier.saveNow();
        expect(additions, [
          ['work/project'],
        ]);
        notifier.updateTitle('Renamed title');
        await notifier.saveNow();
        expect(additions, hasLength(1));
      },
    );

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

    test('typing in-progress #tag without space or enter does not add tag on saveNow()', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-5',
        title: 'Draft Note',
        content: 'Starting note',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: const [],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      expect(notifier.state.note.tags, isEmpty);

      // User is in the middle of typing '#journal/daily' (no space or newline yet)
      notifier.updateContent('Starting note #journal/daily');
      await notifier.saveNow();

      // Tag should NOT be added yet
      expect(notifier.state.note.tags, isEmpty);
      var saved = await repository.getNoteById('note-tag-5');
      expect(saved!.tags, isEmpty);

      // User presses space after the tag
      notifier.updateContent('Starting note #journal/daily ');
      await notifier.saveNow();

      // Tag is now created and saved
      expect(notifier.state.note.tags, equals(['journal/daily']));
      saved = await repository.getNoteById('note-tag-5');
      expect(saved!.tags, equals(['journal/daily']));
    });

    test('pressing enter (newline) after #tag creates the tag on saveNow()', () async {
      final now = DateTime.now();
      final initialNote = Note(
        id: 'note-tag-6',
        title: 'Draft Note 2',
        content: '',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: const [],
      );

      await repository.saveNote(initialNote);

      final notifier = EditorNotifier(
        initialNote: initialNote,
        repository: repository,
      );

      // In-progress typing: no newline
      notifier.updateContent('Working on #ideas');
      await notifier.saveNow();
      expect(notifier.state.note.tags, isEmpty);

      // User presses Enter (newline)
      notifier.updateContent('Working on #ideas\nNext line');
      await notifier.saveNow();
      expect(notifier.state.note.tags, equals(['ideas']));
    });
  });
}

class CountingTagRepository extends DriftNotesRepository {
  CountingTagRepository(super.db);
  int saves = 0;
  bool failSaves = false;

  @override
  Future<void> saveNote(Note note, {bool preserveEmptyTags = false}) async {
    saves++;
    if (failSaves) throw StateError('test save failure');
    await super.saveNote(note, preserveEmptyTags: preserveEmptyTags);
  }
}
