import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';
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

  group('Database & NotesRepository Tests', () {
    test('create and retrieve note with auto-detected tags', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Project Ideas',
        content: 'Writing notes with #ideas and #flutter tag in markdown.',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      await repository.saveNote(note);

      final fetched = await repository.getNoteById('note-1');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Project Ideas');
      expect(fetched.content, contains('#ideas'));
      expect(fetched.tags, containsAll(['ideas', 'flutter']));
    });

    test('update note content and sync tags correctly', () async {
      final now = DateTime.now();
      final note1 = Note(
        id: 'note-2',
        title: 'Draft',
        content: 'Content with #draft',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note1);
      var fetched = await repository.getNoteById('note-2');
      expect(fetched!.tags, ['draft']);

      // Update to new tags
      final note2 = note1.copyWith(
        title: 'Final',
        content: 'Updated content with #published and #v1',
        updatedAt: now.add(const Duration(seconds: 1)),
      );

      await repository.saveNote(note2);
      fetched = await repository.getNoteById('note-2');
      expect(fetched!.title, 'Final');
      expect(fetched.tags, containsAll(['published', 'v1']));
      expect(fetched.tags, isNot(contains('draft')));
    });

    test('pinning orders notes first', () async {
      final t1 = DateTime(2026, 1, 1, 10, 0);
      final t2 = DateTime(2026, 1, 1, 11, 0);

      await repository.saveNote(Note(
        id: 'n1',
        title: 'Unpinned Recent',
        content: 'body',
        createdAt: t2,
        updatedAt: t2,
        isPinned: false,
      ));

      await repository.saveNote(Note(
        id: 'n2',
        title: 'Pinned Older',
        content: 'body',
        createdAt: t1,
        updatedAt: t1,
        isPinned: true,
      ));

      final notes = await repository.watchNotes().first;
      expect(notes.length, 2);
      expect(notes.first.id, 'n2'); // Pinned comes first
      expect(notes.last.id, 'n1');

      // Toggle pin
      await repository.setPinned('n2', false);
      final unpinnedNotes = await repository.watchNotes().first;
      expect(unpinnedNotes.first.id, 'n1'); // More recent comes first now
    });

    test('search notes by title, content, or tag', () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 's1',
        title: 'Architectural Decisions',
        content: 'We decided on SQLite',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.saveNote(Note(
        id: 's2',
        title: 'Shopping list',
        content: 'Apples, oranges #groceries',
        createdAt: now,
        updatedAt: now,
      ));

      // Title search
      final searchTitle =
          await repository.watchNotes(searchQuery: 'architect').first;
      expect(searchTitle.length, 1);
      expect(searchTitle.first.id, 's1');

      // Content search
      final searchContent =
          await repository.watchNotes(searchQuery: 'apples').first;
      expect(searchContent.length, 1);
      expect(searchContent.first.id, 's2');

      // Tag search
      final searchTag =
          await repository.watchNotes(searchQuery: 'groceries').first;
      expect(searchTag.length, 1);
      expect(searchTag.first.id, 's2');
    });

    test('filter notes by tag', () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 't1',
        title: 'Note One',
        content: 'Tag #travel',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.saveNote(Note(
        id: 't2',
        title: 'Note Two',
        content: 'Tag #work',
        createdAt: now,
        updatedAt: now,
      ));

      final travelNotes =
          await repository.watchNotes(filterTag: 'travel').first;
      expect(travelNotes.length, 1);
      expect(travelNotes.first.id, 't1');

      final workNotes = await repository.watchNotes(filterTag: 'work').first;
      expect(workNotes.length, 1);
      expect(workNotes.first.id, 't2');
    });

    test('delete note removes note and cleans up tags', () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 'del-1',
        title: 'To be deleted',
        content: 'Has unique #customtag',
        createdAt: now,
        updatedAt: now,
      ));

      var tags = await repository.getAllTagNames();
      expect(tags, contains('customtag'));

      await repository.deletePermanently('del-1');

      final fetched = await repository.getNoteById('del-1');
      expect(fetched, isNull);

      tags = await repository.getAllTagNames();
      expect(tags, isNot(contains('customtag')));
    });
  });

  group('Archive & Lifecycle Invariant Tests', () {
    test('Active -> Archive -> absent from All Notes, present in Archive',
        () async {
      final now = DateTime.now();
      final note = Note(
        id: 'arch-1',
        title: 'To Archive',
        content: 'Archived note body',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);

      var activeNotes = await repository.watchNotes(isArchived: false).first;
      var archivedNotes = await repository.watchNotes(isArchived: true).first;
      expect(activeNotes.map((n) => n.id), contains('arch-1'));
      expect(archivedNotes, isEmpty);

      // Archive
      await repository.archiveNote('arch-1');

      activeNotes = await repository.watchNotes(isArchived: false).first;
      archivedNotes = await repository.watchNotes(isArchived: true).first;
      expect(activeNotes.map((n) => n.id), isNot(contains('arch-1')));
      expect(archivedNotes.map((n) => n.id), contains('arch-1'));

      final fetched = await repository.getNoteById('arch-1');
      expect(fetched!.isArchived, isTrue);
      expect(fetched.isTrashed, isFalse);
    });

    test('Archive -> Unarchive -> present in All Notes, absent from Archive',
        () async {
      final now = DateTime.now();
      final note = Note(
        id: 'arch-2',
        title: 'Archived then unarchived',
        content: 'Body',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      );

      await repository.saveNote(note);

      var archivedNotes = await repository.watchNotes(isArchived: true).first;
      expect(archivedNotes.map((n) => n.id), contains('arch-2'));

      // Unarchive
      await repository.unarchiveNote('arch-2');

      var activeNotes = await repository.watchNotes(isArchived: false).first;
      archivedNotes = await repository.watchNotes(isArchived: true).first;
      expect(activeNotes.map((n) => n.id), contains('arch-2'));
      expect(archivedNotes, isEmpty);

      final fetched = await repository.getNoteById('arch-2');
      expect(fetched!.isArchived, isFalse);
      expect(fetched.isTrashed, isFalse);
    });

    test('Pinned -> Archive -> absent from Pinned view and active notes',
        () async {
      final now = DateTime.now();
      final note = Note(
        id: 'pin-arch',
        title: 'Pinned Note',
        content: 'Pinned content',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
      );

      await repository.saveNote(note);

      var pinnedNotes = await repository.watchNotes(isPinned: true).first;
      expect(pinnedNotes.map((n) => n.id), contains('pin-arch'));

      // Archive it
      await repository.archiveNote('pin-arch');

      pinnedNotes = await repository.watchNotes(isPinned: true).first;
      var activeNotes = await repository.watchNotes(isArchived: false).first;
      var archivedNotes = await repository.watchNotes(isArchived: true).first;

      expect(pinnedNotes, isEmpty);
      expect(activeNotes, isEmpty);
      expect(archivedNotes.map((n) => n.id), contains('pin-arch'));
    });
  });

  group('Critical Trash Tests (Section 64)', () {
    test('Test 1: Create -> Trash -> Read Trash -> note exists', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'trash-1',
        title: 'Trash Test 1',
        content: 'To be trashed',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);
      await repository.trashNote('trash-1');

      final active = await repository.watchNotes(isTrashed: false).first;
      final trashed = await repository.watchNotes(isTrashed: true).first;

      expect(active.map((n) => n.id), isNot(contains('trash-1')));
      expect(trashed.map((n) => n.id), contains('trash-1'));
      expect(trashed.first.deletedAt, isNotNull);
    });

    test('Test 2: Create -> Trash -> Note remains in Trash indefinitely (no auto-delete)',
        () async {
      final now = DateTime.now().subtract(const Duration(days: 45));
      final note = Note(
        id: 'trash-2',
        title: 'Trash Test 2 - 45 days old',
        content: 'Should not be auto-deleted',
        createdAt: now,
        updatedAt: now,
        isTrashed: true,
        deletedAt: now,
      );

      await repository.saveNote(note);

      // Verify it stays in Trash regardless of age
      final trashed = await repository.watchNotes(isTrashed: true).first;
      expect(trashed.map((n) => n.id), contains('trash-2'));
    });

    test('Test 3: Create -> Trash -> Restore -> appears in All Notes', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'trash-3',
        title: 'Trash Test 3',
        content: 'Restoring to active',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);
      await repository.trashNote('trash-3');

      var trashed = await repository.watchNotes(isTrashed: true).first;
      expect(trashed.map((n) => n.id), contains('trash-3'));

      // Restore
      await repository.restoreFromTrash('trash-3');

      final active = await repository.watchNotes(isTrashed: false).first;
      trashed = await repository.watchNotes(isTrashed: true).first;

      expect(active.map((n) => n.id), contains('trash-3'));
      expect(trashed, isEmpty);

      final fetched = await repository.getNoteById('trash-3');
      expect(fetched!.isTrashed, isFalse);
      expect(fetched.deletedAt, isNull);
    });

    test('Test 4: Create -> Trash -> Delete Permanently -> note no longer exists',
        () async {
      final now = DateTime.now();
      final note = Note(
        id: 'trash-4',
        title: 'Trash Test 4',
        content: 'Hard deletion',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);
      await repository.trashNote('trash-4');
      await repository.deletePermanently('trash-4');

      final active = await repository.watchNotes(isTrashed: false).first;
      final trashed = await repository.watchNotes(isTrashed: true).first;
      final fetched = await repository.getNoteById('trash-4');

      expect(active, isEmpty);
      expect(trashed, isEmpty);
      expect(fetched, isNull);
    });

    test('Test 5: Empty Trash permanently removes all trashed notes', () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 't-active',
        title: 'Active note',
        content: 'Keep this',
        createdAt: now,
        updatedAt: now,
      ));
      await repository.saveNote(Note(
        id: 't-del-1',
        title: 'Trash 1',
        content: 'Delete',
        createdAt: now,
        updatedAt: now,
        isTrashed: true,
      ));
      await repository.saveNote(Note(
        id: 't-del-2',
        title: 'Trash 2',
        content: 'Delete',
        createdAt: now,
        updatedAt: now,
        isTrashed: true,
      ));

      var trashedCount = await repository.watchTrashedNotesCount().first;
      expect(trashedCount, 2);

      await repository.emptyTrash();

      trashedCount = await repository.watchTrashedNotesCount().first;
      expect(trashedCount, 0);

      final active = await repository.watchNotes().first;
      expect(active.length, 1);
      expect(active.first.id, 't-active');
    });
  });

  group('Reactive Counts & Batch Operations Tests', () {
    test('counts stream updates dynamically on lifecycle changes', () async {
      final now = DateTime.now();

      final activeCountStream = repository.watchActiveNotesCount();
      final pinnedCountStream = repository.watchPinnedNotesCount();
      final archivedCountStream = repository.watchArchivedNotesCount();
      final trashedCountStream = repository.watchTrashedNotesCount();

      expect(await activeCountStream.first, 0);

      // Create active note
      await repository.saveNote(Note(
        id: 'c1',
        title: 'Count 1',
        content: 'Active',
        createdAt: now,
        updatedAt: now,
      ));
      expect(await activeCountStream.first, 1);

      // Pin it
      await repository.setPinned('c1', true);
      expect(await pinnedCountStream.first, 1);

      // Archive it
      await repository.archiveNote('c1');
      expect(await activeCountStream.first, 0);
      expect(await pinnedCountStream.first, 0);
      expect(await archivedCountStream.first, 1);

      // Trash it
      await repository.trashNote('c1');
      expect(await archivedCountStream.first, 0);
      expect(await trashedCountStream.first, 1);

      // Restore it
      await repository.restoreFromTrash('c1');
      expect(await trashedCountStream.first, 0);
      expect(await activeCountStream.first, 1);

      // Hard delete
      await repository.deletePermanently('c1');
      expect(await activeCountStream.first, 0);
    });

    test('batch lifecycle operations work correctly', () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 'b1',
        title: 'Batch 1',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      ));
      await repository.saveNote(Note(
        id: 'b2',
        title: 'Batch 2',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      ));

      // Batch archive
      await repository.archiveNotes(['b1', 'b2']);
      expect(await repository.watchArchivedNotesCount().first, 2);
      expect(await repository.watchActiveNotesCount().first, 0);

      // Batch unarchive
      await repository.unarchiveNotes(['b1', 'b2']);
      expect(await repository.watchArchivedNotesCount().first, 0);
      expect(await repository.watchActiveNotesCount().first, 2);

      // Batch trash
      await repository.trashNotes(['b1', 'b2']);
      expect(await repository.watchTrashedNotesCount().first, 2);
      expect(await repository.watchActiveNotesCount().first, 0);

      // Batch restore
      await repository.restoreNotes(['b1', 'b2']);
      expect(await repository.watchTrashedNotesCount().first, 0);
      expect(await repository.watchActiveNotesCount().first, 2);

      // Batch delete permanently
      await repository.deletePermanentlyBatch(['b1', 'b2']);
      expect(await repository.watchActiveNotesCount().first, 0);
    });

    test('tag counts only include active notes and exclude trashed/archived',
        () async {
      final now = DateTime.now();
      await repository.saveNote(Note(
        id: 'tag-active',
        title: 'Tag Active',
        content: 'Note with #quiet',
        createdAt: now,
        updatedAt: now,
      ));
      await repository.saveNote(Note(
        id: 'tag-archived',
        title: 'Tag Archived',
        content: 'Note with #quiet',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      ));
      await repository.saveNote(Note(
        id: 'tag-trashed',
        title: 'Tag Trashed',
        content: 'Note with #quiet',
        createdAt: now,
        updatedAt: now,
        isTrashed: true,
      ));

      final tagsWithCount = await repository.watchTags().first;
      expect(tagsWithCount.length, 1);
      expect(tagsWithCount.first.tag.name, 'quiet');
      expect(tagsWithCount.first.noteCount, 1); // Only the active note
    });
  });

  group('TagParser Unit Tests', () {
    test('extracts multiple tags including nested ones', () {
      const text = '''
# Heading 1 (not a tag)
Here is #ideas and #flutter/android and #work-2026.
Ignore `#inline_code_tag` and ```#code_block```.
''';

      final tags = TagParser.extractTags(text);
      expect(tags, containsAll(['ideas', 'flutter/android', 'work-2026']));
      expect(tags, isNot(contains('Heading')));
      expect(tags, isNot(contains('inline_code_tag')));
      expect(tags, isNot(contains('code_block')));
    });

    test('normalizes and validates tags properly', () {
      expect(TagParser.normalizeTag('#Flutter'), 'flutter');
      expect(TagParser.normalizeTag('##DESIGN'), 'design');
      expect(TagParser.isValidTag('valid-tag'), isTrue);
      expect(TagParser.isValidTag('valid/nested'), isTrue);
      expect(TagParser.isValidTag('123'), isFalse);
      expect(TagParser.isValidTag('-invalid'), isFalse);
      expect(TagParser.isValidTag(''), isFalse);
    });
  });
}
