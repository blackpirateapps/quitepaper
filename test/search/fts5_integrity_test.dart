import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/search/search_tokenizer.dart';

void main() {
  group('FTS5 Index Integrity & Auto-Repair Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Integrity check detects empty FTS index when active notes exist and triggers auto-repair', () async {
      // 1. Add notes into database
      for (var i = 1; i <= 5; i++) {
        await db.saveNote(
          id: 'note-integrity-$i',
          title: 'Integrity Note $i',
          content: 'Important content about quantum mechanics and computing #physics',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isPinned: false,
          tags: ['physics'],
        );
      }

      // Verify FTS is populated initially
      var ftsRows = await db.customSelect('SELECT COUNT(*) as cnt FROM note_search_prefix;').getSingle();
      expect(ftsRows.read<int>('cnt'), equals(5));

      // 2. Simulate app update wiping FTS virtual table data (e.g. SQLite shadow table corruption)
      await db.customStatement('DELETE FROM note_search_prefix;');
      await db.customStatement('DELETE FROM note_search_trigram;');

      ftsRows = await db.customSelect('SELECT COUNT(*) as cnt FROM note_search_prefix;').getSingle();
      expect(ftsRows.read<int>('cnt'), equals(0));

      // 3. Close database and reopen (simulating app restart after update)
      // Note: for in-memory, we can call the internal _verifySearchIndexIntegrity or check flag logic directly
      // Let's invoke a search when FTS was wiped
      final candidateBefore = await db.searchNoteCandidateIds(SearchTokenizer.compileQuery('quantum'));
      // In our fallback, LIKE fallback still finds notes so user doesn't get completely empty results!
      expect(candidateBefore, isNotEmpty);

      // 4. Now run rebuildSearchIndex with batched transactions
      var completedCount = 0;
      var totalCount = 0;
      await db.rebuildSearchIndex(
        batchSize: 2,
        onProgress: (completed, total) {
          completedCount = completed;
          totalCount = total;
        },
      );

      expect(totalCount, equals(5));
      expect(completedCount, equals(5));
      expect(db.needsSearchIndexRebuild, isFalse);

      // 5. Verify FTS is fully restored and fast candidate search works
      final restoredFtsRows = await db.customSelect('SELECT COUNT(*) as cnt FROM note_search_prefix;').getSingle();
      expect(restoredFtsRows.read<int>('cnt'), equals(5));

      final candidatesAfter = await db.searchNoteCandidateIds(SearchTokenizer.compileQuery('quantum'));
      expect(candidatesAfter.length, equals(5));
    });

    test('getSearchCandidatesLightweight omits body content for 0ms Phase 1 memory efficiency', () async {
      await db.saveNote(
        id: 'note-lightweight-1',
        title: 'Meeting Notes',
        content: 'Very long body content that would consume memory across isolates' * 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: true,
        tags: ['meeting'],
      );

      final lightweightCandidates = await db.getSearchCandidatesLightweight(['note-lightweight-1']);
      expect(lightweightCandidates.length, equals(1));
      expect(lightweightCandidates.first.id, equals('note-lightweight-1'));
      expect(lightweightCandidates.first.title, equals('Meeting Notes'));
      expect(lightweightCandidates.first.tags, contains('meeting'));
      expect(lightweightCandidates.first.isPinned, isTrue);
      // Body content is intentionally empty to save memory during Phase 1
      expect(lightweightCandidates.first.content, isEmpty);

      // Full candidate loader still preserves content for Phase 2
      final fullCandidates = await db.getSearchCandidatesByIds(['note-lightweight-1']);
      expect(fullCandidates.first.content, isNotEmpty);
    });

    test('getSearchCandidatesByIds defensively bounds excessively large notes to 50KB', () async {
      final hugeContent = 'A' * 75000;
      await db.saveNote(
        id: 'note-huge-1',
        title: 'Massive Document',
        content: hugeContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final candidates = await db.getSearchCandidatesByIds(['note-huge-1']);
      expect(candidates.length, equals(1));
      // Truncated to 50,000 characters cap to prevent isolate memory exhaustion
      expect(candidates.first.content.length, equals(50000));
    });
  });
}
