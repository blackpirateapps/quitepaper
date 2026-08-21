import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/conflict/conflict_model.dart';
import 'package:quitepaper/core/sync/conflict/conflict_region.dart';
import 'package:quitepaper/core/sync/conflict/conflict_repository.dart';
import 'package:quitepaper/core/sync/conflict/merge_result.dart';

void main() {
  late AppDatabase db;
  late ConflictRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftConflictRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Conflict Persistence & Drift Repository Tests', () {
    test('Saves, retrieves, updates, and deletes SyncConflict with all regions', () async {
      const noteId = '55555555-5555-5555-5555-555555555555';

      await db.saveNote(
        id: noteId,
        title: 'Initial Title',
        content: 'Initial Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['alpha'],
        serverRevision: 1,
      );

      final conflict = SyncConflict(
        id: 'conflict-uuid-1',
        noteId: noteId,
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 2,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime(2026, 1, 3, 10, 0),
        basePlaintext: const NotePlaintext(title: 'Initial Title', body: 'Initial Content', tags: ['alpha']),
        localPlaintext: const NotePlaintext(title: 'Initial Title', body: 'Local edited body', tags: ['alpha', 'local']),
        remotePlaintext: const NotePlaintext(title: 'Initial Title', body: 'Remote edited body', tags: ['alpha', 'remote']),
        conflictRegions: const [
          ConflictRegion(
            id: 'reg-1',
            baseText: 'Initial Content',
            localText: 'Local edited body',
            remoteText: 'Remote edited body',
            startLine: 1,
            endLine: 1,
          ),
        ],
        explanation: '1 conflicting section(s) detected.',
      );

      await repo.saveConflict(conflict);

      // Verify pending count and list
      final pendingCount = await repo.getPendingConflictsCount();
      expect(pendingCount, 1);

      final pendingList = await repo.getPendingConflicts();
      expect(pendingList.length, 1);
      final retrieved = pendingList.first;
      expect(retrieved.id, 'conflict-uuid-1');
      expect(retrieved.noteId, noteId);
      expect(retrieved.baseRevision, 1);
      expect(retrieved.remoteRevision, 2);
      expect(retrieved.conflictType, ConflictType.content);
      expect(retrieved.state, ConflictState.manualRequired);
      expect(retrieved.conflictRegions.length, 1);
      expect(retrieved.conflictRegions.first.localText, 'Local edited body');
      expect(retrieved.conflictRegions.first.remoteText, 'Remote edited body');

      // Verify getConflict and getConflictForNote
      final byId = await repo.getConflict('conflict-uuid-1');
      expect(byId, isNotNull);
      expect(byId!.explanation, '1 conflicting section(s) detected.');

      final byNote = await repo.getConflictForNote(noteId);
      expect(byNote, isNotNull);
      expect(byNote!.id, 'conflict-uuid-1');

      // Mark resolved
      await repo.markResolved(
        'conflict-uuid-1',
        resolutionRevision: 3,
        resolutionType: ConflictResolutionType.manual,
      );

      final resolvedCount = await repo.getPendingConflictsCount();
      expect(resolvedCount, 0);

      final resolvedEntity = await repo.getConflict('conflict-uuid-1');
      expect(resolvedEntity?.state, ConflictState.resolved);
      expect(resolvedEntity?.resolutionRevision, 3);
      expect(resolvedEntity?.resolutionType, ConflictResolutionType.manual);

      // Delete
      await repo.deleteConflict('conflict-uuid-1');
      final afterDelete = await repo.getConflict('conflict-uuid-1');
      expect(afterDelete, isNull);
    });

    test('Streams pending conflicts reactively', () async {
      const noteIdA = 'aaaaaaa1-1111-1111-1111-111111111111';
      const noteIdB = 'aaaaaaa2-2222-2222-2222-222222222222';

      await db.saveNote(
        id: noteIdA,
        title: 'A',
        content: 'A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: noteIdB,
        title: 'B',
        content: 'B',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      expect(repo.watchPendingConflictsCount(), emitsInOrder([0, 1, 2, 1]));

      await Future.delayed(const Duration(milliseconds: 10));

      await repo.saveConflict(SyncConflict(
        id: 'conf-a',
        noteId: noteIdA,
        createdAt: DateTime.now(),
        state: ConflictState.manualRequired,
      ));

      await Future.delayed(const Duration(milliseconds: 10));

      await repo.saveConflict(SyncConflict(
        id: 'conf-b',
        noteId: noteIdB,
        createdAt: DateTime.now(),
        state: ConflictState.manualRequired,
      ));

      await Future.delayed(const Duration(milliseconds: 10));

      await repo.markResolved('conf-a', resolutionRevision: 2, resolutionType: ConflictResolutionType.keepMine);
    });
  });
}
