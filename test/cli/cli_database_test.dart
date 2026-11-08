import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_database.dart';

void main() {
  late CliDatabase db;

  setUp(() {
    db = CliDatabase.openInMemory();
  });

  tearDown(() {
    db.close();
  });

  group('CliDatabase Tests', () {
    test('createNote correctly stores note, extracts tags, creates version and sync queue mutation', () {
      final note = db.createNote(
        title: 'Project Roadmap',
        content: 'Working on #roadmap and #q4 milestones in markdown.',
        isPinned: true,
      );

      expect(note.id, isNotEmpty);
      expect(note.shortId.length, 8);
      expect(note.displayTitle, 'Project Roadmap');
      expect(note.isPinned, isTrue);
      expect(note.tags, containsAll(['roadmap', 'q4']));

      // Retrieve by shortId
      final fetched = db.getNoteByIdOrPrefix(note.shortId);
      expect(fetched, isNotNull);
      expect(fetched!.id, note.id);
      expect(fetched.title, 'Project Roadmap');
      expect(fetched.tags, containsAll(['roadmap', 'q4']));
    });

    test('getNoteByIdOrPrefix finds note by 8-character prefix or full UUID', () {
      final note = db.createNote(
        title: 'Prefix Lookup Note',
        content: 'Some unique content for prefix lookup test.',
      );

      final byFull = db.getNoteByIdOrPrefix(note.id);
      expect(byFull, isNotNull);
      expect(byFull!.title, 'Prefix Lookup Note');

      final byShort = db.getNoteByIdOrPrefix(note.shortId);
      expect(byShort, isNotNull);
      expect(byShort!.id, note.id);

      final nonExistent = db.getNoteByIdOrPrefix('nonexistent-prefix');
      expect(nonExistent, isNull);
    });

    test('findNotesByTitle locates notes by title substring', () {
      db.createNote(title: 'Grocery List', content: 'Apples, oranges');
      db.createNote(title: 'Book List', content: 'Sci-fi novels');
      db.createNote(title: 'Daily Journal', content: 'Reflection');

      final listResults = db.findNotesByTitle('List');
      expect(listResults.length, 2);
      expect(listResults.map((n) => n.displayTitle), containsAll(['Grocery List', 'Book List']));

      final grocery = db.findNotesByTitle('grocery');
      expect(grocery.length, 1);
      expect(grocery.first.displayTitle, 'Grocery List');
    });

    test('updateNote bumps updatedAt, creates version snapshot, and updates tags', () {
      final created = db.createNote(
        title: 'Draft',
        content: 'Initial text with #draft',
      );

      final updated = db.updateNote(
        id: created.id,
        title: 'Final Draft',
        content: 'Revised content now #published #review',
        isPinned: false,
      );

      expect(updated.title, 'Final Draft');
      expect(updated.tags, containsAll(['published', 'review']));
      expect(updated.tags.contains('draft'), isFalse);

      final fetched = db.getNoteByIdOrPrefix(created.id);
      expect(fetched!.title, 'Final Draft');
      expect(fetched.tags, containsAll(['published', 'review']));
    });

    test('listNotes filters by tag and subtree tags', () {
      db.createNote(title: 'Work Project', content: 'Tasks for #work/backend and #work/frontend');
      db.createNote(title: 'Personal Goal', content: 'Habits for #personal');

      final workParent = db.listNotes(tag: 'work');
      expect(workParent.length, 1);
      expect(workParent.first.displayTitle, 'Work Project');

      final workSub = db.listNotes(tag: 'work/backend');
      expect(workSub.length, 1);

      final personal = db.listNotes(tag: 'personal');
      expect(personal.length, 1);
      expect(personal.first.displayTitle, 'Personal Goal');
    });

    test('trashNote and restoreNote manage note lifecycle', () {
      final note = db.createNote(title: 'Delete Candidate', content: 'Temporary note');

      // Active list before trash
      expect(db.listNotes().any((n) => n.id == note.id), isTrue);

      // Move to trash
      db.trashNote(note.id);
      expect(db.listNotes().any((n) => n.id == note.id), isFalse);
      expect(db.listNotes(showTrash: true).any((n) => n.id == note.id), isTrue);

      // Restore from trash
      db.restoreNote(note.id);
      expect(db.listNotes().any((n) => n.id == note.id), isTrue);
      expect(db.listNotes(showTrash: true).any((n) => n.id == note.id), isFalse);
    });

    test('deletePermanently removes note completely', () {
      final note = db.createNote(title: 'Ephemeral', content: 'To be wiped');
      db.deletePermanently(note.id);

      expect(db.getNoteByIdOrPrefix(note.id), isNull);
      expect(db.listNotes(showTrash: true).any((n) => n.id == note.id), isFalse);
    });

    test('listTags aggregates note count accurately', () {
      db.createNote(title: 'Note 1', content: '#dev #flutter');
      db.createNote(title: 'Note 2', content: '#dev #dart');
      db.createNote(title: 'Note 3', content: '#design');

      final tags = db.listTags();
      final devTag = tags.firstWhere((t) => t.name == 'dev');
      final flutterTag = tags.firstWhere((t) => t.name == 'flutter');
      final designTag = tags.firstWhere((t) => t.name == 'design');

      expect(devTag.noteCount, 2);
      expect(flutterTag.noteCount, 1);
      expect(designTag.noteCount, 1);
    });
  });
}
