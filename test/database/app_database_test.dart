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
      final searchTitle = await repository.watchNotes(searchQuery: 'architect').first;
      expect(searchTitle.length, 1);
      expect(searchTitle.first.id, 's1');

      // Content search
      final searchContent = await repository.watchNotes(searchQuery: 'apples').first;
      expect(searchContent.length, 1);
      expect(searchContent.first.id, 's2');

      // Tag search
      final searchTag = await repository.watchNotes(searchQuery: 'groceries').first;
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

      final travelNotes = await repository.watchNotes(filterTag: 'travel').first;
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

      await repository.deleteNote('del-1');

      final fetched = await repository.getNoteById('del-1');
      expect(fetched, isNull);

      tags = await repository.getAllTagNames();
      expect(tags, isNot(contains('customtag')));
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
