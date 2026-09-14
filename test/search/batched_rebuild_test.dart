import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/search/search_tokenizer.dart';

void main() {
  group('Batched Search Index Rebuild Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Rebuilds empty database cleanly without exceptions', () async {
      var progressCalled = false;
      await db.rebuildSearchIndex(
        onProgress: (completed, total) {
          progressCalled = true;
          expect(completed, equals(0));
          expect(total, equals(0));
        },
      );

      expect(progressCalled, isTrue);
      expect(db.needsSearchIndexRebuild, isFalse);
    });

    test('Rebuilds 25 notes across multiple batches with accurate progress callbacks', () async {
      const noteCount = 25;
      const batchSize = 7;

      for (var i = 1; i <= noteCount; i++) {
        await db.saveNote(
          id: 'note-batch-$i',
          title: 'Batch Note Title $i',
          content: 'Detailed note body $i discussing astrophysics and galaxies #space',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isPinned: i % 5 == 0,
          tags: ['space', 'astronomy'],
        );
      }

      final progressSnapshots = <Map<String, int>>[];

      await db.rebuildSearchIndex(
        batchSize: batchSize,
        onProgress: (completed, total) {
          progressSnapshots.add({'completed': completed, 'total': total});
        },
      );

      // Verify progress milestones
      expect(progressSnapshots.isNotEmpty, isTrue);
      expect(progressSnapshots.last['completed'], equals(noteCount));
      expect(progressSnapshots.last['total'], equals(noteCount));

      // Check monotonicity of completed count
      for (var i = 1; i < progressSnapshots.length; i++) {
        expect(
          progressSnapshots[i]['completed']! >= progressSnapshots[i - 1]['completed']!,
          isTrue,
        );
      }

      // Verify all notes are searchable via FTS prefix and trigram
      final query = SearchTokenizer.compileQuery('astrophysics');
      final results = await db.searchNoteCandidateIds(query, limit: 100);
      expect(results.length, equals(noteCount));
    });
  });
}
