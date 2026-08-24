import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/search/search_tokenizer.dart';

void main() {
  group('FTS5 Database Search Integration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Indexes and retrieves prefix matches via note_search_prefix', () async {
      await db.saveNote(
        id: 'note-prefix-1',
        title: 'Project Synchronization',
        content: 'Details on distributed database replication.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        tags: ['sync'],
      );

      final query = SearchTokenizer.compileQuery('sync');
      final candidateIds = await db.searchNoteCandidateIds(query);

      expect(candidateIds, contains('note-prefix-1'));
    });

    test('Indexes and retrieves infix/substring matches via note_search_trigram (e.g. part -> counterpart)', () async {
      await db.saveNote(
        id: 'note-trigram-1',
        title: 'Meeting with the counterpart team',
        content: 'Discussing quarterly cross-team deliverables.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // 'part' is an infix of 'counterpart' (length 4 >= 3)
      final query = SearchTokenizer.compileQuery('part');
      final candidateIds = await db.searchNoteCandidateIds(query);

      expect(candidateIds, contains('note-trigram-1'));
    });

    test('Updates search index when note content or title changes', () async {
      await db.saveNote(
        id: 'note-update-1',
        title: 'Old Title Alpha',
        content: 'Original body text with unique keyword elephant.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Verify searchable with 'elephant'
      var q1 = SearchTokenizer.compileQuery('elephant');
      expect(await db.searchNoteCandidateIds(q1), contains('note-update-1'));

      // Update note content removing 'elephant' and adding 'giraffe'
      await db.saveNote(
        id: 'note-update-1',
        title: 'New Title Beta',
        content: 'Updated body text with unique keyword giraffe.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Old keyword elephant must no longer match
      expect(await db.searchNoteCandidateIds(q1), isEmpty);

      // New keyword giraffe and title Beta must match
      var q2 = SearchTokenizer.compileQuery('giraffe');
      var q3 = SearchTokenizer.compileQuery('beta');
      expect(await db.searchNoteCandidateIds(q2), contains('note-update-1'));
      expect(await db.searchNoteCandidateIds(q3), contains('note-update-1'));
    });

    test('Removes trashed note from search candidates and restores on restoreFromTrash', () async {
      await db.saveNote(
        id: 'note-trash-1',
        title: 'Confidential Finance Report',
        content: 'Quarterly financial statements and tax filings.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final query = SearchTokenizer.compileQuery('finance');
      expect(await db.searchNoteCandidateIds(query), contains('note-trash-1'));

      // Move note to trash
      await db.trashNote('note-trash-1');

      // Must be excluded from candidate results
      expect(await db.searchNoteCandidateIds(query), isEmpty);

      // Restore note from trash
      await db.restoreFromTrash('note-trash-1');

      // Must be searchable again
      expect(await db.searchNoteCandidateIds(query), contains('note-trash-1'));
    });

    test('Removes note completely on permanent deletion', () async {
      await db.saveNote(
        id: 'note-del-1',
        title: 'Temporary Scratchpad',
        content: 'Temporary notes that will be discarded.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final query = SearchTokenizer.compileQuery('scratchpad');
      expect(await db.searchNoteCandidateIds(query), contains('note-del-1'));

      await db.deletePermanently('note-del-1');

      expect(await db.searchNoteCandidateIds(query), isEmpty);
    });

    test('rebuildSearchIndex repopulates all active notes and excludes trashed notes', () async {
      await db.saveNote(
        id: 'note-active-1',
        title: 'Active Document',
        content: 'Production architecture overview.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: 'note-trashed-2',
        title: 'Trashed Document',
        content: 'Old discarded notes.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isTrashed: true,
      );

      // Rebuild index
      await db.rebuildSearchIndex();

      final qActive = SearchTokenizer.compileQuery('architecture');
      final qTrashed = SearchTokenizer.compileQuery('discarded');

      expect(await db.searchNoteCandidateIds(qActive), contains('note-active-1'));
      expect(await db.searchNoteCandidateIds(qTrashed), isEmpty);
    });
  });
}
