import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('QuickCapture Database & Invariant Tests', () {
    test('draft CRUD operations persist and retrieve drafts accurately', () async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'draft-1',
        targetNoteId: 'note-1',
        content: 'Draft content for later',
        source: 'widget',
        sourceUrl: 'https://example.com',
        titleHint: 'Sample Title',
        cursorPosition: 10,
        createdAt: now,
        updatedAt: now,
      );

      final retrieved = await db.getQuickCaptureDraft('draft-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'draft-1');
      expect(retrieved.targetNoteId, 'note-1');
      expect(retrieved.content, 'Draft content for later');
      expect(retrieved.source, 'widget');
      expect(retrieved.sourceUrl, 'https://example.com');
      expect(retrieved.titleHint, 'Sample Title');
      expect(retrieved.cursorPosition, 10);

      // Delete draft
      await db.deleteQuickCaptureDraft('draft-1');
      final afterDelete = await db.getQuickCaptureDraft('draft-1');
      expect(afterDelete, isNull);
    });

    test('getAllQuickCaptureDrafts orders drafts by updatedAt descending', () async {
      final t1 = DateTime(2026, 10, 20, 10, 0);
      final t2 = DateTime(2026, 10, 20, 11, 0);

      await db.saveQuickCaptureDraft(
        id: 'draft-early',
        targetNoteId: 'note-early',
        content: 'Early thought',
        createdAt: t1,
        updatedAt: t1,
      );

      await db.saveQuickCaptureDraft(
        id: 'draft-later',
        targetNoteId: 'note-later',
        content: 'Later thought',
        createdAt: t2,
        updatedAt: t2,
      );

      final drafts = await db.getAllQuickCaptureDrafts();
      expect(drafts.length, 2);
      expect(drafts.first.id, 'draft-later');
      expect(drafts.last.id, 'draft-early');
    });

    test('drafts are excluded from notes queries and search index', () async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'draft-private',
        targetNoteId: 'note-private',
        content: 'Top secret uncommitted thought #secret',
        createdAt: now,
        updatedAt: now,
      );

      // Normal note queries
      final allNotes = await db.select(db.notesTable).get();
      expect(allNotes, isEmpty);

      // FTS search index
      final searchPrefix = await db.customSelect('SELECT * FROM note_search_prefix;').get();
      expect(searchPrefix, isEmpty);

      // Sync queue
      final syncQueue = await db.getPendingSyncQueue();
      expect(syncQueue, isEmpty);

      // Dirty notes
      final dirtyNotes = await db.getDirtyNotes();
      expect(dirtyNotes, isEmpty);
    });

    test('commitQuickCaptureNote atomically saves note and removes draft', () async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'draft-commit-test',
        targetNoteId: 'note-committed',
        content: 'Committed note body\n#quick',
        createdAt: now,
        updatedAt: now,
      );

      final note = Note(
        id: 'note-committed',
        title: 'Committed note body',
        content: 'Committed note body\n#quick',
        createdAt: now,
        updatedAt: now,
      );

      await db.commitQuickCaptureNote(
        note: note,
        draftSessionId: 'draft-commit-test',
      );

      // Draft is removed
      final draft = await db.getQuickCaptureDraft('draft-commit-test');
      expect(draft, isNull);

      // Note is committed
      final savedNote = await db.getNoteWithTags('note-committed');
      expect(savedNote, isNotNull);
      expect(savedNote!.note.title, 'Committed note body');
      expect(savedNote.note.content, 'Committed note body\n#quick');
      expect(savedNote.tags.map((t) => t.name), contains('quick'));

      // Note enters dirty state for cloud sync
      final dirtyNotes = await db.getDirtyNotes();
      expect(dirtyNotes.any((n) => n.note.id == 'note-committed'), isTrue);
    });

    test('retrying note commitment is idempotent', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'idempotent-note',
        title: 'Idempotent Title',
        content: 'Testing retry safety',
        createdAt: now,
        updatedAt: now,
      );

      await db.commitQuickCaptureNote(note: note, draftSessionId: 'non-existent-draft');
      await db.commitQuickCaptureNote(note: note, draftSessionId: 'non-existent-draft');

      final allNotes = await db.select(db.notesTable).get();
      expect(allNotes.where((n) => n.id == 'idempotent-note').length, 1);
    });

    test('eraseAllLocalVaultData purges drafts along with vault tables', () async {
      final now = DateTime.now();
      await db.saveQuickCaptureDraft(
        id: 'draft-to-erase',
        targetNoteId: 'note-erase',
        content: 'Sensitive content',
        createdAt: now,
        updatedAt: now,
      );

      await db.eraseAllLocalVaultData();

      final drafts = await db.getAllQuickCaptureDrafts();
      expect(drafts, isEmpty);
    });
  });
}
