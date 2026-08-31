import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  group('AppDatabase Note Links & Backlinks Integration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('automatically derives and indexes note links on saveNote', () async {
      const targetId1 = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const targetId2 = '00112233-4455-4677-8899-aabbccddeeff';

      // 1. Create target notes
      await db.saveNote(
        id: targetId1,
        title: 'Target Note 1',
        content: 'Content 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: targetId2,
        title: 'Target Note 2',
        content: 'Content 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // 2. Create source note linking to targetId1 and targetId2
      const sourceId = '99999999-8888-4777-8666-555544443333';
      await db.saveNote(
        id: sourceId,
        title: 'Source Note',
        content: 'Links: [T1](qp://note/$targetId1) and [T2](qp://note/$targetId2)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Verify outgoing links
      final outgoing = await db.getOutgoingLinksForNote(sourceId);
      expect(outgoing.length, 2);
      expect(outgoing.map((l) => l.targetNoteId).toSet(), {targetId1, targetId2});

      // Verify backlinks for targetId1
      final backlinks1 = await db.getBacklinksForNote(targetId1);
      expect(backlinks1.activeBacklinks.length, 1);
      expect(backlinks1.activeBacklinks.first.sourceNote.id, sourceId);
      expect(backlinks1.activeBacklinks.first.occurrencesCount, 1);
      expect(backlinks1.trashedBacklinksCount, 0);

      // 3. Update source note content to remove link to targetId2 and add multiple links to targetId1
      await db.saveNote(
        id: sourceId,
        title: 'Source Note Updated',
        content: '[T1 First](qp://note/$targetId1) ... [T1 Second](qp://note/$targetId1)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final updatedOutgoing = await db.getOutgoingLinksForNote(sourceId);
      expect(updatedOutgoing.length, 2);
      expect(updatedOutgoing.every((l) => l.targetNoteId == targetId1), true);

      final updatedBacklinks1 = await db.getBacklinksForNote(targetId1);
      expect(updatedBacklinks1.activeBacklinks.length, 1);
      expect(updatedBacklinks1.activeBacklinks.first.occurrencesCount, 2);

      final updatedBacklinks2 = await db.getBacklinksForNote(targetId2);
      expect(updatedBacklinks2.activeBacklinks.isEmpty, true);
    });

    test('separates trashed source notes in BacklinkQueryResult', () async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Source Note',
        content: 'Link: [Target](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isTrashed: true,
        deletedAt: DateTime.now(),
      );

      final result = await db.getBacklinksForNote(targetId);
      expect(result.activeBacklinks.isEmpty, true);
      expect(result.trashedBacklinksCount, 1);
    });


    test('cleans up note_links upon permanent deletion', () async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Source Note',
        content: 'Link: [Target](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      expect((await db.getBacklinksForNote(targetId)).isNotEmpty, true);

      // Permanent delete target note
      await db.deletePermanently(targetId, enqueueSync: false);

      final outgoing = await db.getOutgoingLinksForNote(sourceId);
      expect(outgoing.isEmpty, true);
    });

    test('rebuildNoteLinkIndex reconstructs entire relationship graph', () async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Source Note',
        content: 'Link: [Target](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Clear note_links directly to simulate restore / unindexed state
      await db.delete(db.noteLinksTable).go();
      expect((await db.getOutgoingLinksForNote(sourceId)).isEmpty, true);

      // Rebuild index
      await db.rebuildNoteLinkIndex();

      final outgoing = await db.getOutgoingLinksForNote(sourceId);
      expect(outgoing.length, 1);
      expect(outgoing.first.targetNoteId, targetId);
    });
  });
}
