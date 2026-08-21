import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/conflict/conflict_model.dart';
import 'package:quitepaper/core/sync/conflict/conflict_resolver.dart';
import 'package:quitepaper/core/sync/conflict/merge_result.dart';

void main() {
  late AppDatabase db;
  late ConflictResolver resolver;

  setUp(() {
    db = AppDatabase.memory();
    resolver = ConflictResolver(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ConflictResolver Operations Tests', () {
    test('resolveKeepMine preserves local note and records provenance', () async {
      const noteId = '11111111-1111-1111-1111-111111111111';

      await db.saveNote(
        id: noteId,
        title: 'Local Title',
        content: 'Local Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['local-tag'],
        serverRevision: 1,
        isDirty: false,
      );

      final conflict = SyncConflict(
        id: 'conf-1',
        noteId: noteId,
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 2,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        basePlaintext: const NotePlaintext(title: 'Base', body: 'Base', tags: []),
        localPlaintext: const NotePlaintext(title: 'Local Title', body: 'Local Content', tags: ['local-tag']),
        remotePlaintext: const NotePlaintext(title: 'Remote Title', body: 'Remote Content', tags: ['remote-tag']),
      );

      await db.saveConflict(
        id: conflict.id,
        noteId: conflict.noteId,
        baseRevision: conflict.baseRevision,
        localRevision: conflict.localRevision,
        remoteRevision: conflict.remoteRevision,
        conflictType: conflict.conflictType.name,
        state: conflict.state.name,
        createdAt: conflict.createdAt,
        dataJson: conflict.toDataJson(),
      );

      await resolver.resolveKeepMine(conflict);

      final note = await db.getNoteWithTags(noteId);
      expect(note, isNotNull);
      expect(note!.note.title, 'Local Title');
      expect(note.note.content, 'Local Content');
      expect(note.note.serverRevision, 2);
      expect(note.note.isDirty, isTrue);

      final versions = await db.getNoteVersions(noteId);
      expect(versions.length, 1);
      final v = versions.first;
      expect(v.mergeType, 'keepMine');
      expect(v.baseRevision, 1);
      expect(v.remoteParentRevision, 2);

      final resolvedConflict = await db.getConflict('conf-1');
      expect(resolvedConflict?.state, 'resolved');
    });

    test('resolveKeepTheirs applies remote content and marks clean', () async {
      const noteId = '22222222-2222-2222-2222-222222222222';

      await db.saveNote(
        id: noteId,
        title: 'Old Local Title',
        content: 'Old Local Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['old-tag'],
        serverRevision: 1,
        isDirty: true,
      );

      final conflict = SyncConflict(
        id: 'conf-2',
        noteId: noteId,
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 2,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        basePlaintext: const NotePlaintext(title: 'Base', body: 'Base', tags: []),
        localPlaintext: const NotePlaintext(title: 'Old Local Title', body: 'Old Local Content', tags: ['old-tag']),
        remotePlaintext: const NotePlaintext(title: 'Authoritative Remote Title', body: 'Authoritative Remote Content', tags: ['cloud-tag']),
      );

      await resolver.resolveKeepTheirs(conflict);

      final note = await db.getNoteWithTags(noteId);
      expect(note, isNotNull);
      expect(note!.note.title, 'Authoritative Remote Title');
      expect(note.note.content, 'Authoritative Remote Content');
      expect(note.tagNames, ['cloud-tag']);
      expect(note.note.serverRevision, 2);
      expect(note.note.isDirty, isFalse);

      final versions = await db.getNoteVersions(noteId);
      expect(versions.length, 1);
      expect(versions.first.mergeType, 'keepTheirs');
    });

    test('resolveKeepBoth creates conflict copy note with distinct UUID', () async {
      const origNoteId = '33333333-3333-3333-3333-333333333333';

      await db.saveNote(
        id: origNoteId,
        title: 'Original Title',
        content: 'Original Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['main'],
        serverRevision: 1,
        isDirty: true,
      );

      final conflict = SyncConflict(
        id: 'conf-3',
        noteId: origNoteId,
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 2,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        localPlaintext: const NotePlaintext(title: 'Original Title', body: 'Original Content', tags: ['main']),
        remotePlaintext: const NotePlaintext(title: 'Server Branch Title', body: 'Server Branch Content', tags: ['server']),
      );

      final newNoteId = await resolver.resolveKeepBoth(conflict);
      expect(newNoteId, isNot(origNoteId));

      final origNote = await db.getNoteWithTags(origNoteId);
      expect(origNote!.note.title, 'Original Title');

      final copyNote = await db.getNoteWithTags(newNoteId);
      expect(copyNote, isNotNull);
      expect(copyNote!.note.title, 'Server Branch Title (Conflict Copy)');
      expect(copyNote.note.content, 'Server Branch Content');
      expect(copyNote.tagNames, ['server']);
      expect(copyNote.note.isDirty, isTrue);
    });

    test('resolveWithCustomMerge applies manual content and records provenance', () async {
      const noteId = '44444444-4444-4444-4444-444444444444';

      await db.saveNote(
        id: noteId,
        title: 'Local',
        content: 'Local',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['tag1'],
        serverRevision: 1,
      );

      final conflict = SyncConflict(
        id: 'conf-4',
        noteId: noteId,
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 2,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
      );

      await resolver.resolveWithCustomMerge(
        conflict: conflict,
        resolvedTitle: 'Merged Title',
        resolvedContent: 'Custom Unified Content',
        resolvedTags: ['tag1', 'tag2'],
      );

      final note = await db.getNoteWithTags(noteId);
      expect(note!.note.title, 'Merged Title');
      expect(note.note.content, 'Custom Unified Content');
      expect(note.tagNames, unorderedEquals(['tag1', 'tag2']));
      expect(note.note.serverRevision, 2);
      expect(note.note.isDirty, isTrue);

      final versions = await db.getNoteVersions(noteId);
      expect(versions.first.mergeType, 'manual');
    });
  });
}
