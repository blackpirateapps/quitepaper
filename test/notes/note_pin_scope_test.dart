import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';

/// Covers the global-vs-per-tag pin model:
///  - Global pins float everywhere and appear in the Pinned view.
///  - Per-tag pins float only inside their own tag + the Pinned view.
///  - The Pinned smart view aggregates both.
///  - Per-tag pins survive content edits and are pruned when the tag goes away.
void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;

  final t0 = DateTime(2026, 10, 11, 9, 0, 0);

  setUp(() async {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addNote(String id, String content,
      {DateTime? updatedAt}) async {
    await repository.saveNote(Note(
      id: id,
      title: id,
      content: content,
      createdAt: t0,
      updatedAt: updatedAt ?? t0,
    ));
  }

  NotesQuery allNotes({bool pinnedFirst = true}) => NotesQuery(
        sort: NotesSort(
          field: SortField.updated,
          direction: SortDirection.descending,
          pinnedFirst: pinnedFirst,
        ),
      );

  NotesQuery tagView(String tag) => NotesQuery.forDestination(
        context: NotesContext.active,
        tag: tag,
      );

  NotesQuery pinnedView() => NotesQuery.forDestination(
        context: NotesContext.active,
        pinnedOnly: true,
      );

  group('per-tag pin storage', () {
    test('setPinnedInTag records the tag and persists on the note', () async {
      await addNote('n1', 'hello #work #home');

      await repository.setPinnedInTag('n1', 'work', true);

      final note = await repository.getNoteById('n1');
      expect(note!.pinnedTags, contains('work'));
      expect(note.isPinnedInTag('work'), isTrue);
      expect(note.isPinnedInTag('home'), isFalse);
      expect(note.isPinned, isFalse, reason: 'tag pin is not a global pin');
    });

    test('unpinning a tag removes it from pinnedTags', () async {
      await addNote('n1', 'hello #work');
      await repository.setPinnedInTag('n1', 'work', true);
      await repository.setPinnedInTag('n1', 'work', false);

      final note = await repository.getNoteById('n1');
      expect(note!.pinnedTags, isEmpty);
    });

    test('a per-tag pin survives a content edit', () async {
      await addNote('n1', 'first #work');
      await repository.setPinnedInTag('n1', 'work', true);

      // Edit the body but keep the #work tag (tags re-derived from content).
      await addNote('n1', 'edited body still #work');

      final note = await repository.getNoteById('n1');
      expect(note!.isPinnedInTag('work'), isTrue);
    });

    test('removing the tag from content prunes its pin', () async {
      await addNote('n1', 'first #work');
      await repository.setPinnedInTag('n1', 'work', true);

      // Remove the #work tag entirely (tags re-derived from content).
      await addNote('n1', 'no tags now');

      final note = await repository.getNoteById('n1');
      expect(note!.pinnedTags, isEmpty);
    });
  });

  group('ordering & grouping scope', () {
    test('a per-tag pin floats inside its tag but NOT in All Notes', () async {
      await addNote('older', 'older #work', updatedAt: t0);
      await addNote('newer', 'newer #work',
          updatedAt: t0.add(const Duration(hours: 1)));
      await repository.setPinnedInTag('older', 'work', true);

      // In All Notes, no global pin → pure recency: newer first.
      final all = await repository.executeNotesQuery(allNotes());
      expect(all.notes.map((n) => n.id).toList(), ['newer', 'older']);

      // Inside #work, the tag-pinned 'older' floats to the top.
      final work = await repository.executeNotesQuery(tagView('work'));
      expect(work.notes.first.id, 'older');
    });

    test('a global pin floats in All Notes and inside a tag view', () async {
      await addNote('plain', 'plain #work',
          updatedAt: t0.add(const Duration(hours: 2)));
      await addNote('pinned', 'pinned #work', updatedAt: t0);
      await repository.setPinned('pinned', true);

      final all = await repository.executeNotesQuery(allNotes());
      expect(all.notes.first.id, 'pinned',
          reason: 'global pin floats despite being older');

      final work = await repository.executeNotesQuery(tagView('work'));
      expect(work.notes.first.id, 'pinned',
          reason: 'global pin floats inside the tag too');
    });
  });

  group('Pinned smart view aggregation', () {
    test('aggregates both global and per-tag pins', () async {
      await addNote('global', 'g #work');
      await addNote('tagpinned', 'tp #home');
      await addNote('unpinned', 'u #misc');

      await repository.setPinned('global', true);
      await repository.setPinnedInTag('tagpinned', 'home', true);

      final pinned = await repository.executeNotesQuery(pinnedView());
      final ids = pinned.notes.map((n) => n.id).toSet();
      expect(ids, {'global', 'tagpinned'});
      expect(ids.contains('unpinned'), isFalse);
    });
  });
}
