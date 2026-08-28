import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotesQuery Database Sorting & Deterministic Ordering', () {
    test('Updated sort DESC orders newest modified first with ID tie-breaker', () async {
      final t0 = DateTime(2026, 8, 28, 10, 0, 0);

      // Notes with same updatedAt but different IDs to test tie breaking
      await repository.saveNote(Note(
        id: 'note-b',
        title: 'Note B',
        content: 'Content B',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-a',
        title: 'Note A',
        content: 'Content A',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-c',
        title: 'Note C',
        content: 'Content C',
        createdAt: t0,
        updatedAt: t0.add(const Duration(minutes: 5)),
      ));

      final result = await repository.executeNotesQuery(
        const NotesQuery(
          sort: NotesSort(field: SortField.updated, direction: SortDirection.descending, pinnedFirst: false),
        ),
      );

      expect(result.notes.length, 3);
      expect(result.notes[0].id, 'note-c'); // Newest updatedAt
      expect(result.notes[1].id, 'note-a'); // Same updatedAt, ID 'a' < 'b'
      expect(result.notes[2].id, 'note-b');
    });

    test('Created sort ASC orders oldest created first', () async {
      final t0 = DateTime(2026, 1, 1);

      await repository.saveNote(Note(
        id: 'note-1',
        title: 'First',
        content: 'C1',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-2',
        title: 'Second',
        content: 'C2',
        createdAt: t0.add(const Duration(days: 10)),
        updatedAt: t0,
      ));

      final result = await repository.executeNotesQuery(
        const NotesQuery(
          sort: NotesSort(field: SortField.created, direction: SortDirection.ascending, pinnedFirst: false),
        ),
      );

      expect(result.notes[0].id, 'note-1');
      expect(result.notes[1].id, 'note-2');
    });

    test('Title sort is case-insensitive NOCASE and supports duplicate titles', () async {
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);

      await repository.saveNote(Note(
        id: 'note-zebra',
        title: 'zebra',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-Apple',
        title: 'Apple',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-banana-2',
        title: 'Banana',
        content: '',
        createdAt: t0,
        updatedAt: t0.add(const Duration(minutes: 1)),
      ));
      await repository.saveNote(Note(
        id: 'note-banana-1',
        title: 'banana',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));

      final resultAsc = await repository.executeNotesQuery(
        const NotesQuery(
          sort: NotesSort(field: SortField.title, direction: SortDirection.ascending, pinnedFirst: false),
        ),
      );

      expect(resultAsc.notes.map((n) => n.id).toList(), [
        'note-Apple',
        'note-banana-2', // Newer updatedAt among identical titles
        'note-banana-1',
        'note-zebra',
      ]);
    });

    test('Pinned first sorting partitions pinned notes ahead of unpinned notes', () async {
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);

      await repository.saveNote(Note(
        id: 'unpinned-recent',
        title: 'Unpinned Recent',
        content: '',
        createdAt: t0,
        updatedAt: t0.add(const Duration(hours: 2)),
        isPinned: false,
      ));
      await repository.saveNote(Note(
        id: 'pinned-old',
        title: 'Pinned Old',
        content: '',
        createdAt: t0,
        updatedAt: t0,
        isPinned: true,
      ));

      final result = await repository.executeNotesQuery(
        const NotesQuery(
          sort: NotesSort(field: SortField.updated, direction: SortDirection.descending, pinnedFirst: true),
        ),
      );

      expect(result.notes[0].id, 'pinned-old');
      expect(result.notes[1].id, 'unpinned-recent');
    });
  });

  group('NotesQuery Database Context Isolation', () {
    test('filters notes by active, archive, and trash contexts', () async {
      final t0 = DateTime.now();

      await repository.saveNote(Note(
        id: 'active-note',
        title: 'Active',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'archived-note',
        title: 'Archived',
        content: '',
        createdAt: t0,
        updatedAt: t0,
        isArchived: true,
      ));
      await repository.saveNote(Note(
        id: 'trashed-note',
        title: 'Trashed',
        content: '',
        createdAt: t0,
        updatedAt: t0,
        isTrashed: true,
        deletedAt: t0,
      ));

      final activeRes = await repository.executeNotesQuery(
        const NotesQuery(context: NotesContext.active),
      );
      expect(activeRes.notes.map((n) => n.id).toList(), ['active-note']);

      final archiveRes = await repository.executeNotesQuery(
        const NotesQuery(context: NotesContext.archive),
      );
      expect(archiveRes.notes.map((n) => n.id).toList(), ['archived-note']);

      final trashRes = await repository.executeNotesQuery(
        const NotesQuery(context: NotesContext.trash),
      );
      expect(trashRes.notes.map((n) => n.id).toList(), ['trashed-note']);
    });
  });

  group('NotesQuery Database Tag Filtering', () {
    setUp(() async {
      final t0 = DateTime.now();
      await repository.saveNote(Note(
        id: 'note-flutter-dart',
        title: 'Flutter Dart Note',
        content: 'Content',
        createdAt: t0,
        updatedAt: t0,
        tags: const ['flutter', 'dart'],
      ));
      await repository.saveNote(Note(
        id: 'note-flutter-only',
        title: 'Flutter Only Note',
        content: 'Content',
        createdAt: t0,
        updatedAt: t0,
        tags: const ['flutter'],
      ));
      await repository.saveNote(Note(
        id: 'note-untagged',
        title: 'Untagged Note',
        content: 'Content',
        createdAt: t0,
        updatedAt: t0,
        tags: const [],
      ));
    });

    test('single tag filter returns matching notes', () async {
      final result = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(tags: {'flutter'})),
      );
      expect(result.notes.map((n) => n.id).toSet(), {
        'note-flutter-dart',
        'note-flutter-only',
      });
    });

    test('multiple tags with MatchMode.all (AND) requires all tags', () async {
      final result = await repository.executeNotesQuery(
        const NotesQuery(
          filter: NotesFilter(
            tags: {'flutter', 'dart'},
            tagMatchMode: TagMatchMode.all,
          ),
        ),
      );
      expect(result.notes.map((n) => n.id).toList(), ['note-flutter-dart']);
    });

    test('multiple tags with MatchMode.any (OR) matches either tag', () async {
      final result = await repository.executeNotesQuery(
        const NotesQuery(
          filter: NotesFilter(
            tags: {'dart', 'other'},
            tagMatchMode: TagMatchMode.any,
          ),
        ),
      );
      expect(result.notes.map((n) => n.id).toList(), ['note-flutter-dart']);
    });

    test('untaggedOnly returns notes with zero tag associations', () async {
      final result = await repository.executeNotesQuery(
        const NotesQuery(
          filter: NotesFilter(untaggedOnly: true),
        ),
      );
      expect(result.notes.map((n) => n.id).toList(), ['note-untagged']);
    });
  });

  group('NotesQuery Database Content & Attachment Filters', () {
    final t0 = DateTime.now();

    test('content predicates filter code, checklists, tasks, and links', () async {
      await repository.saveNote(Note(
        id: 'note-code',
        title: 'Code Note',
        content: 'Here is code: ```dart\nvoid main() {}\n```',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-task-incomplete',
        title: 'Task Note',
        content: '- [ ] Todo task',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-task-completed',
        title: 'Done Note',
        content: '- [x] Completed task',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-links',
        title: 'Links Note',
        content: 'Check https://quietpaper.app or [docs](qp://document/123)',
        createdAt: t0,
        updatedAt: t0,
      ));

      final codeRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(contentFilters: {ContentFilter.hasCode})),
      );
      expect(codeRes.notes.map((n) => n.id).toList(), ['note-code']);

      final incompleteRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(contentFilters: {ContentFilter.hasIncompleteTasks})),
      );
      expect(incompleteRes.notes.map((n) => n.id).toList(), ['note-task-incomplete']);

      final completedRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(contentFilters: {ContentFilter.hasCompletedTasks})),
      );
      expect(completedRes.notes.map((n) => n.id).toList(), ['note-task-completed']);

      final linksRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(contentFilters: {ContentFilter.hasLinks})),
      );
      expect(linksRes.notes.map((n) => n.id).toList(), ['note-links']);
    });

    test('attachment and OCR filters query actual database relationships', () async {
      await repository.saveNote(Note(
        id: 'note-with-image',
        title: 'Image Note',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-with-doc',
        title: 'Doc Note',
        content: '',
        createdAt: t0,
        updatedAt: t0,
      ));

      // Attach image
      await db.saveAttachment(
        id: 'att-1',
        noteId: 'note-with-image',
        createdAt: t0,
        updatedAt: t0,
        mimeType: 'image/jpeg',
        ocrState: 'available',
      );

      // Attach document
      await db.saveDocument(
        id: 'doc-1',
        noteId: 'note-with-doc',
        createdAt: t0,
        updatedAt: t0,
        ocrState: 'queued',
      );

      final hasImagesRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(attachmentFilters: {AttachmentFilter.hasImages})),
      );
      expect(hasImagesRes.notes.map((n) => n.id).toList(), ['note-with-image']);

      final hasDocsRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(attachmentFilters: {AttachmentFilter.hasDocuments})),
      );
      expect(hasDocsRes.notes.map((n) => n.id).toList(), ['note-with-doc']);

      final hasOcrRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(attachmentFilters: {AttachmentFilter.hasOcr})),
      );
      expect(hasOcrRes.notes.map((n) => n.id).toList(), ['note-with-image']);
    });

    test('security filter separates password protected notes', () async {
      await repository.saveNote(Note(
        id: 'note-protected',
        title: 'Protected Note',
        content: '<!-- quiet-paper-encrypted-note-v1:{"nonce":"...","ciphertext":"..."} -->',
        createdAt: t0,
        updatedAt: t0,
      ));
      await repository.saveNote(Note(
        id: 'note-unprotected',
        title: 'Normal Note',
        content: 'Plain markdown content',
        createdAt: t0,
        updatedAt: t0,
      ));

      final protectedRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(securityFilter: SecurityFilter.protectedOnly)),
      );
      expect(protectedRes.notes.map((n) => n.id).toList(), ['note-protected']);

      final unprotectedRes = await repository.executeNotesQuery(
        const NotesQuery(filter: NotesFilter(securityFilter: SecurityFilter.unprotectedOnly)),
      );
      expect(unprotectedRes.notes.map((n) => n.id).toList(), ['note-unprotected']);
    });
  });

  group('Large Dataset Keyset Pagination (125 Notes across 4 Batches)', () {
    setUp(() async {
      final baseTime = DateTime(2026, 1, 1, 0, 0, 0);

      // Create 125 notes with distinct timestamps and titles
      for (var i = 1; i <= 125; i++) {
        final padded = i.toString().padLeft(3, '0');
        await repository.saveNote(Note(
          id: 'note-$padded',
          title: 'Note $padded',
          content: 'Body $padded',
          createdAt: baseTime.add(Duration(minutes: i)),
          updatedAt: baseTime.add(Duration(minutes: i)),
          isPinned: i <= 5, // First 5 notes pinned
        ));
      }
    });

    test('paginates 125 notes incrementally using keyset cursors without duplicate items', () async {
      const batchSize = 40;
      final loadedNotes = <Note>[];

      // Query 1: Initial batch
      var currentQuery = const NotesQuery(
        sort: NotesSort(field: SortField.updated, direction: SortDirection.descending, pinnedFirst: true),
        limit: batchSize,
      );

      final batch1 = await repository.executeNotesQuery(currentQuery);
      expect(batch1.notes.length, 40);
      expect(batch1.hasMore, true);
      expect(batch1.nextCursor, isNotNull);
      expect(batch1.totalCount, 125);
      loadedNotes.addAll(batch1.notes);

      // Query 2: Second batch
      currentQuery = currentQuery.nextPage(batch1.nextCursor!);
      final batch2 = await repository.executeNotesQuery(currentQuery);
      expect(batch2.notes.length, 40);
      expect(batch2.hasMore, true);
      expect(batch2.nextCursor, isNotNull);
      loadedNotes.addAll(batch2.notes);

      // Query 3: Third batch
      currentQuery = currentQuery.nextPage(batch2.nextCursor!);
      final batch3 = await repository.executeNotesQuery(currentQuery);
      expect(batch3.notes.length, 40);
      expect(batch3.hasMore, true);
      expect(batch3.nextCursor, isNotNull);
      loadedNotes.addAll(batch3.notes);

      // Query 4: Fourth batch (final short batch)
      currentQuery = currentQuery.nextPage(batch3.nextCursor!);
      final batch4 = await repository.executeNotesQuery(currentQuery);
      expect(batch4.notes.length, 5); // 125 - 120 = 5
      expect(batch4.hasMore, false);
      expect(batch4.nextCursor, isNull);
      loadedNotes.addAll(batch4.notes);

      // Verify total count and zero duplicates
      expect(loadedNotes.length, 125);
      final uniqueIds = loadedNotes.map((n) => n.id).toSet();
      expect(uniqueIds.length, 125);

      // Verify top 5 are the pinned notes
      for (var i = 0; i < 5; i++) {
        expect(loadedNotes[i].isPinned, true);
      }
      for (var i = 5; i < 125; i++) {
        expect(loadedNotes[i].isPinned, false);
      }
    });
  });
}
