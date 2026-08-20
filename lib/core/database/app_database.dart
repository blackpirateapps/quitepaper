import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../utils/tag_parser.dart';
import 'connection/connection.dart' as conn;
import 'tables/attachment_variants_table.dart';
import 'tables/attachments_table.dart';
import 'tables/document_ocr_pages_table.dart';
import 'tables/documents_table.dart';
import 'tables/note_tags_table.dart';
import 'tables/note_versions_table.dart';
import 'tables/notes_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/tags_table.dart';

part 'app_database.g.dart';

class NoteWithTags {
  const NoteWithTags({
    required this.note,
    required this.tags,
  });

  final NoteEntity note;
  final List<TagEntity> tags;

  List<String> get tagNames => tags.map((t) => t.name).toList();
}

class TagWithCount {
  const TagWithCount({
    required this.tag,
    required this.noteCount,
  });

  final TagEntity tag;
  final int noteCount;
}

@DriftDatabase(tables: [
  NotesTable,
  TagsTable,
  NoteTagsTable,
  SyncMetadataTable,
  SyncQueueTable,
  AttachmentsTable,
  AttachmentVariantsTable,
  NoteVersionsTable,
  DocumentsTable,
  DocumentOcrPagesTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? conn.openConnection());

  AppDatabase.memory() : super(conn.openInMemoryConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(notesTable, notesTable.isArchived);
            await m.addColumn(notesTable, notesTable.isTrashed);
            await m.addColumn(notesTable, notesTable.deletedAt);
          }
          if (from < 3) {
            await m.addColumn(notesTable, notesTable.serverRevision);
            await m.addColumn(notesTable, notesTable.isDirty);
            await m.addColumn(notesTable, notesTable.syncedAt);
            await m.createTable(syncMetadataTable);
            await m.createTable(syncQueueTable);
          }
          if (from < 4) {
            await m.createTable(attachmentsTable);
            await m.createTable(attachmentVariantsTable);
          }
          if (from < 5) {
            await m.createTable(noteVersionsTable);
          }
          if (from < 6) {
            await m.createTable(documentsTable);
          }
          if (from < 7) {
            await m.addColumn(documentsTable, documentsTable.source);
            await m.addColumn(documentsTable, documentsTable.ocrState);
            await m.addColumn(documentsTable, documentsTable.ocrLanguage);
            await m.createTable(documentOcrPagesTable);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS notes_lifecycle_idx ON notes (is_archived, is_trashed, is_pinned, updated_at);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS notes_deleted_idx ON notes (is_trashed, deleted_at);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS notes_dirty_idx ON notes (is_dirty);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS note_tags_tag_idx ON note_tags (tag_id, note_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachments_note_idx ON attachments (note_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachments_dirty_idx ON attachments (is_dirty);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachments_upload_state_idx ON attachments (upload_state);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachment_variants_att_idx ON attachment_variants (attachment_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS note_versions_note_idx ON note_versions (note_id, version_number DESC);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS note_versions_dirty_idx ON note_versions (is_dirty);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS documents_note_idx ON documents (note_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS documents_dirty_idx ON documents (is_dirty);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS documents_upload_state_idx ON documents (upload_state);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS document_ocr_doc_idx ON document_ocr_pages (document_id);',
          );
        },
      );

  // ==========================================
  // NOTE OPERATIONS & STREAM QUERIES
  // ==========================================

  /// Watches notes filtered by lifecycle state (active, archived, or trashed), optional tag, and optional search query.
  Stream<List<NoteWithTags>> watchNotes({
    bool isArchived = false,
    bool isTrashed = false,
    bool? isPinned,
    String? filterTag,
    String? searchQuery,
  }) {
    final notesQuery = select(notesTable);

    notesQuery.where((n) => n.isArchived.equals(isArchived) & n.isTrashed.equals(isTrashed));

    if (isPinned != null) {
      notesQuery.where((n) => n.isPinned.equals(isPinned));
    }

    if (filterTag != null && filterTag.trim().isNotEmpty) {
      final normalizedTag = TagParser.normalizeTag(filterTag);
      notesQuery.where((n) {
        final subQuery = selectOnly(noteTagsTable)
          ..join([
            innerJoin(
              tagsTable,
              tagsTable.id.equalsExp(noteTagsTable.tagId),
            ),
          ])
          ..addColumns([noteTagsTable.noteId])
          ..where(
            tagsTable.name.equals(normalizedTag) &
                noteTagsTable.noteId.equalsExp(n.id),
          );
        return existsQuery(subQuery);
      });
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final pattern = '%${searchQuery.trim().toLowerCase()}%';
      final tagMatch = TagParser.normalizeTag(searchQuery.trim());

      notesQuery.where((n) {
        final titleOrContentMatch =
            n.title.lower().like(pattern) | n.content.lower().like(pattern);

        final tagSubQuery = selectOnly(noteTagsTable)
          ..join([
            innerJoin(
              tagsTable,
              tagsTable.id.equalsExp(noteTagsTable.tagId),
            ),
          ])
          ..addColumns([noteTagsTable.noteId])
          ..where(
            tagsTable.name.lower().like('%$tagMatch%') &
                noteTagsTable.noteId.equalsExp(n.id),
          );

        final docSubQuery = selectOnly(documentsTable)
          ..addColumns([documentsTable.noteId])
          ..where(
            documentsTable.noteId.equalsExp(n.id) &
                documentsTable.isDeleted.equals(false) &
                documentsTable.title.lower().like(pattern),
          );

        return titleOrContentMatch | existsQuery(tagSubQuery) | existsQuery(docSubQuery);
      });
    }

    if (isTrashed) {
      notesQuery.orderBy([
        (n) => OrderingTerm(expression: n.deletedAt, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    } else if (isArchived) {
      notesQuery.orderBy([
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    } else {
      notesQuery.orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    }

    return notesQuery.watch().asyncMap((notesList) async {
      if (notesList.isEmpty) return [];

      final noteIds = notesList.map((n) => n.id).toList();
      final tagsByNoteId = await _getTagsForNoteIds(noteIds);

      return notesList.map((note) {
        return NoteWithTags(
          note: note,
          tags: tagsByNoteId[note.id] ?? [],
        );
      }).toList();
    });
  }

  /// Get single note by ID with tags
  Future<NoteWithTags?> getNoteWithTags(String noteId) async {
    final note = await (select(notesTable)..where((n) => n.id.equals(noteId)))
        .getSingleOrNull();
    if (note == null) return null;

    final tags = await _getTagsForNote(noteId);
    return NoteWithTags(note: note, tags: tags);
  }

  /// Watch single note by ID with tags
  Stream<NoteWithTags?> watchNoteWithTags(String noteId) {
    return (select(notesTable)..where((n) => n.id.equals(noteId)))
        .watchSingleOrNull()
        .asyncMap((note) async {
      if (note == null) return null;
      final tags = await _getTagsForNote(noteId);
      return NoteWithTags(note: note, tags: tags);
    });
  }

  /// Create or update a note and sync tags
  Future<void> saveNote({
    required String id,
    required String title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool isPinned,
    bool isArchived = false,
    bool isTrashed = false,
    DateTime? deletedAt,
    List<String>? tags,
    int serverRevision = 0,
    bool isDirty = true,
    DateTime? syncedAt,
  }) async {
    await transaction(() async {
      await into(notesTable).insertOnConflictUpdate(
        NotesTableCompanion.insert(
          id: id,
          title: Value(title),
          content: Value(content),
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: Value(isPinned),
          isArchived: Value(isArchived),
          isTrashed: Value(isTrashed),
          deletedAt: Value(deletedAt),
          serverRevision: Value(serverRevision),
          isDirty: Value(isDirty),
          syncedAt: Value(syncedAt),
        ),
      );

      // Extract and sync tags if tags list is not passed, or sync provided tags
      final extractedTags = tags ?? TagParser.extractTags('$title\n$content');
      await _syncNoteTags(id, extractedTags);
    });
  }

  /// Toggle or set pin status
  Future<void> setPinned(String noteId, bool isPinned) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        isPinned: Value(isPinned),
        isDirty: const Value(true),
      ),
    );
  }

  /// Archive note: archived = true, trashed = false
  Future<void> archiveNote(String noteId) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        isArchived: const Value(true),
        isTrashed: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Unarchive note: archived = false, trashed = false
  Future<void> unarchiveNote(String noteId) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        isArchived: const Value(false),
        isTrashed: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Move note to Trash: trashed = true, archived = false, records deletedAt
  Future<void> trashNote(String noteId) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        isTrashed: const Value(true),
        isArchived: const Value(false),
        deletedAt: Value(DateTime.now()),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restore note from Trash: trashed = false, archived = false, deletedAt = null
  Future<void> restoreFromTrash(String noteId) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        isTrashed: const Value(false),
        isArchived: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Permanent hard deletion of a single note
  Future<void> deletePermanently(String noteId, {bool enqueueSync = true}) async {
    await transaction(() async {
      await (delete(noteTagsTable)..where((nt) => nt.noteId.equals(noteId))).go();
      await (delete(notesTable)..where((n) => n.id.equals(noteId))).go();
      await _cleanupOrphanedTags();
      // Record permanent delete in sync queue so server registers deletion
      if (enqueueSync) {
        await enqueueSyncOperation(noteId, 'delete');
      }
    });
  }

  /// Empty all notes currently in Trash
  Future<void> emptyTrash({bool enqueueSync = true}) async {
    await transaction(() async {
      final trashedNotes = await (select(notesTable)
            ..where((n) => n.isTrashed.equals(true)))
          .get();
      final trashedIds = trashedNotes.map((n) => n.id).toList();

      if (trashedIds.isNotEmpty) {
        await (delete(noteTagsTable)..where((nt) => nt.noteId.isIn(trashedIds))).go();
        await (delete(notesTable)..where((n) => n.id.isIn(trashedIds))).go();
        await _cleanupOrphanedTags();
        if (enqueueSync) {
          for (final id in trashedIds) {
            await enqueueSyncOperation(id, 'delete');
          }
        }
      }
    });
  }

  /// Batch archive
  Future<void> archiveNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
      NotesTableCompanion(
        isArchived: const Value(true),
        isTrashed: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Batch unarchive
  Future<void> unarchiveNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
      NotesTableCompanion(
        isArchived: const Value(false),
        isTrashed: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Batch trash
  Future<void> trashNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
      NotesTableCompanion(
        isTrashed: const Value(true),
        isArchived: const Value(false),
        deletedAt: Value(DateTime.now()),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Batch restore
  Future<void> restoreNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
      NotesTableCompanion(
        isTrashed: const Value(false),
        isArchived: const Value(false),
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Batch permanent deletion
  Future<void> deletePermanentlyBatch(List<String> noteIds, {bool enqueueSync = true}) async {
    if (noteIds.isEmpty) return;
    await transaction(() async {
      await (delete(noteTagsTable)..where((nt) => nt.noteId.isIn(noteIds))).go();
      await (delete(notesTable)..where((n) => n.id.isIn(noteIds))).go();
      await _cleanupOrphanedTags();
      if (enqueueSync) {
        for (final id in noteIds) {
          await enqueueSyncOperation(id, 'delete');
        }
      }
    });
  }

  /// Legacy helper for deleting a note
  Future<void> deleteNote(String noteId, {bool enqueueSync = true}) async {
    await deletePermanently(noteId, enqueueSync: enqueueSync);
  }

  // ==========================================
  // SYNC OPERATIONS & QUERIES
  // ==========================================

  /// Get all local notes marked dirty for pushing
  Future<List<NoteWithTags>> getDirtyNotes() async {
    final dirtyEntities = await (select(notesTable)
          ..where((n) => n.isDirty.equals(true)))
        .get();
    if (dirtyEntities.isEmpty) return [];

    final ids = dirtyEntities.map((n) => n.id).toList();
    final tagsMap = await _getTagsForNoteIds(ids);

    return dirtyEntities.map((n) {
      return NoteWithTags(note: n, tags: tagsMap[n.id] ?? []);
    }).toList();
  }

  /// Mark note as synced with given server revision
  Future<void> markNoteSynced({
    required String noteId,
    required int serverRevision,
    required DateTime syncedAt,
  }) async {
    await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
      NotesTableCompanion(
        serverRevision: Value(serverRevision),
        isDirty: const Value(false),
        syncedAt: Value(syncedAt),
      ),
    );
  }

  /// Gets a sync metadata value by key
  Future<String?> getSyncMetadata(String key) async {
    final row = await (select(syncMetadataTable)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Sets a sync metadata value
  Future<void> setSyncMetadata(String key, String value) async {
    await into(syncMetadataTable).insertOnConflictUpdate(
      SyncMetadataTableCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Enqueue sync operation (e.g. permanent deletion tombstone)
  Future<void> enqueueSyncOperation(String noteId, String operation) async {
    const uuid = Uuid();
    await into(syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: uuid.v4(),
        noteId: noteId,
        operation: operation,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Get all pending sync queue entries
  Future<List<SyncQueueEntity>> getPendingSyncQueue() async {
    return (select(syncQueueTable)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
  }

  /// Remove processed sync queue entries
  Future<void> removeSyncQueueEntries(List<String> queueIds) async {
    if (queueIds.isEmpty) return;
    await (delete(syncQueueTable)..where((t) => t.id.isIn(queueIds))).go();
  }

  // ==========================================
  // COUNT QUERIES (REACTIVE STREAMS)
  // ==========================================

  /// Stream count of active notes (All Notes)
  Stream<int> watchActiveNotesCount() {
    final countExp = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..where(notesTable.isArchived.equals(false) & notesTable.isTrashed.equals(false))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Stream count of pinned active notes
  Stream<int> watchPinnedNotesCount() {
    final countExp = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..where(notesTable.isPinned.equals(true) &
          notesTable.isArchived.equals(false) &
          notesTable.isTrashed.equals(false))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Stream count of archived notes
  Stream<int> watchArchivedNotesCount() {
    final countExp = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..where(notesTable.isArchived.equals(true) & notesTable.isTrashed.equals(false))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Stream count of trashed notes
  Stream<int> watchTrashedNotesCount() {
    final countExp = notesTable.id.count();
    final query = selectOnly(notesTable)
      ..where(notesTable.isTrashed.equals(true))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  // ==========================================
  // TAG OPERATIONS
  // ==========================================

  /// Watches all tags with active note count (excluding archived and trashed notes)
  Stream<List<TagWithCount>> watchAllTagsWithCount() {
    final query = select(tagsTable).join([
      innerJoin(
        noteTagsTable,
        noteTagsTable.tagId.equalsExp(tagsTable.id),
      ),
      innerJoin(
        notesTable,
        notesTable.id.equalsExp(noteTagsTable.noteId),
      ),
    ]);

    query.where(notesTable.isArchived.equals(false) & notesTable.isTrashed.equals(false));
    query.groupBy([tagsTable.id, tagsTable.name]);
    query.addColumns([noteTagsTable.noteId.count()]);
    query.orderBy([
      OrderingTerm.desc(noteTagsTable.noteId.count()),
      OrderingTerm.asc(tagsTable.name),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tag = row.readTable(tagsTable);
        final count = row.read(noteTagsTable.noteId.count()) ?? 0;
        return TagWithCount(tag: tag, noteCount: count);
      }).toList();
    });
  }

  /// Get all distinct tag names
  Future<List<String>> getAllTagNames() async {
    final tags = await select(tagsTable).get();
    return tags.map((t) => t.name).toList();
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  Future<List<TagEntity>> _getTagsForNote(String noteId) async {
    final query = select(tagsTable).join([
      innerJoin(
        noteTagsTable,
        noteTagsTable.tagId.equalsExp(tagsTable.id),
      ),
    ])..where(noteTagsTable.noteId.equals(noteId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(tagsTable)).toList();
  }

  Future<Map<String, List<TagEntity>>> _getTagsForNoteIds(
      List<String> noteIds) async {
    if (noteIds.isEmpty) return {};

    final query = select(tagsTable).join([
      innerJoin(
        noteTagsTable,
        noteTagsTable.tagId.equalsExp(tagsTable.id),
      ),
    ])..where(noteTagsTable.noteId.isIn(noteIds));

    final rows = await query.get();
    final map = <String, List<TagEntity>>{};

    for (final row in rows) {
      final noteId = row.readTable(noteTagsTable).noteId;
      final tag = row.readTable(tagsTable);
      map.putIfAbsent(noteId, () => []).add(tag);
    }

    return map;
  }

  Future<void> _syncNoteTags(String noteId, List<String> tagNames) async {
    const uuid = Uuid();
    final normalized = tagNames
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet()
        .toList();

    await (delete(noteTagsTable)..where((nt) => nt.noteId.equals(noteId))).go();

    if (normalized.isEmpty) {
      await _cleanupOrphanedTags();
      return;
    }

    for (final tagName in normalized) {
      var tag = await (select(tagsTable)..where((t) => t.name.equals(tagName)))
          .getSingleOrNull();

      if (tag == null) {
        final newTagId = uuid.v4();
        await into(tagsTable).insert(
          TagsTableCompanion.insert(
            id: newTagId,
            name: tagName,
          ),
        );
        tag = TagEntity(id: newTagId, name: tagName);
      }

      await into(noteTagsTable).insertOnConflictUpdate(
        NoteTagsTableCompanion.insert(
          noteId: noteId,
          tagId: tag.id,
        ),
      );
    }

    await _cleanupOrphanedTags();
  }

  Future<void> _cleanupOrphanedTags() async {
    final orphanedTagsQuery = selectOnly(tagsTable)
      ..addColumns([tagsTable.id])
      ..where(
        notExistsQuery(
          selectOnly(noteTagsTable)
            ..addColumns([noteTagsTable.tagId])
            ..where(noteTagsTable.tagId.equalsExp(tagsTable.id)),
        ),
      );

    final orphanedTagRows = await orphanedTagsQuery.get();
    final orphanedIds = orphanedTagRows.map((r) => r.read(tagsTable.id)!).toList();

    if (orphanedIds.isNotEmpty) {
      await (delete(tagsTable)..where((t) => t.id.isIn(orphanedIds))).go();
    }
  }

  // ==========================================
  // ATTACHMENT OPERATIONS & QUERIES
  // ==========================================

  /// Inserts or updates an attachment record
  Future<void> saveAttachment({
    required String id,
    String? noteId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String mimeType = 'image/png',
    int byteSize = 0,
    int? width,
    int? height,
    String sha256 = '',
    int encryptionKeyVersion = 1,
    bool isDirty = true,
    bool isDeleted = false,
    DateTime? deletedAt,
    int serverRevision = 0,
    DateTime? syncedAt,
    String uploadState = 'local_only',
    String? cloudPublicId,
    String? cloudUrl,
    String? localPath,
  }) async {
    await into(attachmentsTable).insertOnConflictUpdate(
      AttachmentsTableCompanion.insert(
        id: id,
        noteId: Value(noteId),
        createdAt: createdAt,
        updatedAt: updatedAt,
        mimeType: Value(mimeType),
        byteSize: Value(byteSize),
        width: Value(width),
        height: Value(height),
        sha256: Value(sha256),
        encryptionKeyVersion: Value(encryptionKeyVersion),
        isDirty: Value(isDirty),
        isDeleted: Value(isDeleted),
        deletedAt: Value(deletedAt),
        serverRevision: Value(serverRevision),
        syncedAt: Value(syncedAt),
        uploadState: Value(uploadState),
        cloudPublicId: Value(cloudPublicId),
        cloudUrl: Value(cloudUrl),
        localPath: Value(localPath),
      ),
    );
  }

  /// Get a single attachment by ID
  Future<AttachmentEntity?> getAttachment(String id) async {
    return (select(attachmentsTable)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all active attachments for a note
  Future<List<AttachmentEntity>> getAttachmentsForNote(String noteId) async {
    return (select(attachmentsTable)
          ..where((a) => a.noteId.equals(noteId) & a.isDeleted.equals(false)))
        .get();
  }

  /// Watch active attachments for a note
  Stream<List<AttachmentEntity>> watchAttachmentsForNote(String noteId) {
    return (select(attachmentsTable)
          ..where((a) => a.noteId.equals(noteId) & a.isDeleted.equals(false)))
        .watch();
  }

  /// Get all dirty attachments requiring sync
  Future<List<AttachmentEntity>> getDirtyAttachments() async {
    return (select(attachmentsTable)..where((a) => a.isDirty.equals(true)))
        .get();
  }

  /// Get all attachments pending Cloudinary upload
  Future<List<AttachmentEntity>> getPendingUploadAttachments() async {
    return (select(attachmentsTable)
          ..where((a) =>
              a.isDeleted.equals(false) &
              (a.uploadState.isNotValue('synced') | a.isDirty.equals(true))))
        .get();
  }

  /// Mark attachment as synced with remote server revision
  Future<void> markAttachmentSynced({
    required String id,
    required int serverRevision,
    required DateTime syncedAt,
    String? cloudPublicId,
    String? cloudUrl,
  }) async {
    await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
      AttachmentsTableCompanion(
        serverRevision: Value(serverRevision),
        isDirty: const Value(false),
        syncedAt: Value(syncedAt),
        uploadState: const Value('synced'),
        cloudPublicId: cloudPublicId != null
            ? Value(cloudPublicId)
            : const Value.absent(),
        cloudUrl: cloudUrl != null ? Value(cloudUrl) : const Value.absent(),
      ),
    );
  }

  /// Update upload status of attachment
  Future<void> updateAttachmentUploadState(
    String id,
    String state, {
    String? cloudPublicId,
    String? cloudUrl,
    String? localPath,
  }) async {
    await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
      AttachmentsTableCompanion(
        uploadState: Value(state),
        cloudPublicId: cloudPublicId != null
            ? Value(cloudPublicId)
            : const Value.absent(),
        cloudUrl: cloudUrl != null ? Value(cloudUrl) : const Value.absent(),
        localPath: localPath != null ? Value(localPath) : const Value.absent(),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-delete (tombstone) or permanently delete an attachment
  Future<void> deleteAttachment(String id, {bool enqueueSync = true}) async {
    await transaction(() async {
      await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
        AttachmentsTableCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (enqueueSync) {
        await enqueueSyncOperation(id, 'attachment_delete');
      }
    });
  }

  /// Get all attachments (including tombstones) for backup
  Future<List<AttachmentEntity>> getAllAttachments() async {
    return select(attachmentsTable).get();
  }

  /// Save an attachment variant record
  Future<void> saveAttachmentVariant({
    required String id,
    required String attachmentId,
    required String variantType,
    int byteSize = 0,
    int? width,
    int? height,
    String? localPath,
    String? cloudPublicId,
    String? cloudUrl,
    required DateTime createdAt,
  }) async {
    await into(attachmentVariantsTable).insertOnConflictUpdate(
      AttachmentVariantsTableCompanion.insert(
        id: id,
        attachmentId: attachmentId,
        variantType: variantType,
        byteSize: Value(byteSize),
        width: Value(width),
        height: Value(height),
        localPath: Value(localPath),
        cloudPublicId: Value(cloudPublicId),
        cloudUrl: Value(cloudUrl),
        createdAt: createdAt,
      ),
    );
  }

  /// Get variants for an attachment
  Future<List<AttachmentVariantEntity>> getVariantsForAttachment(
      String attachmentId) async {
    return (select(attachmentVariantsTable)
          ..where((v) => v.attachmentId.equals(attachmentId)))
        .get();
  }

  // ==========================================
  // NOTE VERSION OPERATIONS & STREAM QUERIES
  // ==========================================

  /// Save or update a note version snapshot
  Future<void> saveNoteVersion({
    required String id,
    required String noteId,
    required int versionNumber,
    String title = '',
    String content = '',
    String tagsJson = '[]',
    required DateTime createdAt,
    int charCount = 0,
    int wordCount = 0,
    String? deltaSummary,
    int serverRevision = 0,
    bool isDirty = true,
    DateTime? syncedAt,
  }) async {
    await into(noteVersionsTable).insertOnConflictUpdate(
      NoteVersionsTableCompanion.insert(
        id: id,
        noteId: noteId,
        versionNumber: versionNumber,
        title: Value(title),
        content: Value(content),
        tagsJson: Value(tagsJson),
        createdAt: createdAt,
        charCount: Value(charCount),
        wordCount: Value(wordCount),
        deltaSummary: Value(deltaSummary),
        serverRevision: Value(serverRevision),
        isDirty: Value(isDirty),
        syncedAt: Value(syncedAt),
      ),
    );
  }

  /// Get note versions for a note sorted newest first
  Future<List<NoteVersionEntity>> getNoteVersions(String noteId,
      {int limit = 50}) async {
    return (select(noteVersionsTable)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
          ..limit(limit))
        .get();
  }

  /// Watch note versions for a note sorted newest first
  Stream<List<NoteVersionEntity>> watchNoteVersions(String noteId,
      {int limit = 50}) {
    return (select(noteVersionsTable)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
          ..limit(limit))
        .watch();
  }

  /// Get the latest version for a note
  Future<NoteVersionEntity?> getLatestNoteVersion(String noteId) async {
    return (select(noteVersionsTable)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Calculates next version number for a note
  Future<int> getNextVersionNumber(String noteId) async {
    final latest = await getLatestNoteVersion(noteId);
    return (latest?.versionNumber ?? 0) + 1;
  }

  /// Prune old versions exceeding maxKeep limit
  Future<void> pruneOldNoteVersions(String noteId, {int maxKeep = 50}) async {
    final versions = await getNoteVersions(noteId, limit: 200);
    if (versions.length > maxKeep) {
      final toDelete = versions.sublist(maxKeep);
      final idsToDelete = toDelete.map((v) => v.id).toList();
      await (delete(noteVersionsTable)..where((v) => v.id.isIn(idsToDelete)))
          .go();
    }
  }

  /// Delete all versions for a note
  Future<void> deleteNoteVersions(String noteId) async {
    await (delete(noteVersionsTable)..where((v) => v.noteId.equals(noteId)))
        .go();
  }

  /// Get dirty versions pending sync
  Future<List<NoteVersionEntity>> getDirtyNoteVersions() async {
    return (select(noteVersionsTable)..where((v) => v.isDirty.equals(true)))
        .get();
  }

  /// Mark a note version as synced
  Future<void> markNoteVersionSynced({
    required String id,
    required int revision,
    required DateTime syncedAt,
  }) async {
    await (update(noteVersionsTable)..where((v) => v.id.equals(id))).write(
      NoteVersionsTableCompanion(
        serverRevision: Value(revision),
        isDirty: const Value(false),
        syncedAt: Value(syncedAt),
      ),
    );
  }

  // ==========================================
  // DOCUMENT OPERATIONS & STREAM QUERIES
  // ==========================================

  /// Save or update a scanned document metadata record
  Future<void> saveDocument({
    required String id,
    String? noteId,
    String title = 'Scanned Document',
    String source = 'scanner',
    required DateTime createdAt,
    required DateTime updatedAt,
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
    int encryptionKeyVersion = 1,
    bool isDirty = true,
    bool isDeleted = false,
    DateTime? deletedAt,
    int serverRevision = 0,
    DateTime? syncedAt,
    String uploadState = 'local_only',
    String? cloudPublicId,
    String? cloudUrl,
    String? localPath,
    String? thumbnailPath,
    String ocrState = 'not_requested',
    String ocrLanguage = 'en',
  }) async {
    await into(documentsTable).insertOnConflictUpdate(
      DocumentsTableCompanion.insert(
        id: id,
        noteId: Value(noteId),
        title: Value(title),
        source: Value(source),
        createdAt: createdAt,
        updatedAt: updatedAt,
        mimeType: Value(mimeType),
        byteSize: Value(byteSize),
        pageCount: Value(pageCount),
        sha256: Value(sha256),
        encryptionKeyVersion: Value(encryptionKeyVersion),
        isDirty: Value(isDirty),
        isDeleted: Value(isDeleted),
        deletedAt: Value(deletedAt),
        serverRevision: Value(serverRevision),
        syncedAt: Value(syncedAt),
        uploadState: Value(uploadState),
        cloudPublicId: Value(cloudPublicId),
        cloudUrl: Value(cloudUrl),
        localPath: Value(localPath),
        thumbnailPath: Value(thumbnailPath),
        ocrState: Value(ocrState),
        ocrLanguage: Value(ocrLanguage),
      ),
    );
  }

  /// Get a single document by ID
  Future<DocumentEntity?> getDocument(String id) async {
    return (select(documentsTable)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch a single document by ID
  Stream<DocumentEntity?> watchDocument(String id) {
    return (select(documentsTable)..where((d) => d.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Get all active documents for a note
  Future<List<DocumentEntity>> getDocumentsForNote(String noteId) async {
    return (select(documentsTable)
          ..where((d) => d.noteId.equals(noteId) & d.isDeleted.equals(false)))
        .get();
  }

  /// Watch active documents for a note
  Stream<List<DocumentEntity>> watchDocumentsForNote(String noteId) {
    return (select(documentsTable)
          ..where((d) => d.noteId.equals(noteId) & d.isDeleted.equals(false)))
        .watch();
  }

  /// Get all dirty documents requiring sync
  Future<List<DocumentEntity>> getDirtyDocuments() async {
    return (select(documentsTable)..where((d) => d.isDirty.equals(true)))
        .get();
  }

  /// Get all documents pending Cloudinary upload
  Future<List<DocumentEntity>> getPendingUploadDocuments() async {
    return (select(documentsTable)
          ..where((d) =>
              d.isDeleted.equals(false) &
              (d.uploadState.isNotValue('synced') | d.isDirty.equals(true))))
        .get();
  }

  /// Mark document as synced with remote server revision
  Future<void> markDocumentSynced({
    required String id,
    required int serverRevision,
    required DateTime syncedAt,
    String? cloudPublicId,
    String? cloudUrl,
  }) async {
    await (update(documentsTable)..where((d) => d.id.equals(id))).write(
      DocumentsTableCompanion(
        serverRevision: Value(serverRevision),
        isDirty: const Value(false),
        syncedAt: Value(syncedAt),
        uploadState: const Value('synced'),
        cloudPublicId: cloudPublicId != null
            ? Value(cloudPublicId)
            : const Value.absent(),
        cloudUrl: cloudUrl != null ? Value(cloudUrl) : const Value.absent(),
      ),
    );
  }

  /// Update upload status and paths of document
  Future<void> updateDocumentUploadState(
    String id,
    String state, {
    String? cloudPublicId,
    String? cloudUrl,
    String? localPath,
    String? thumbnailPath,
  }) async {
    await (update(documentsTable)..where((d) => d.id.equals(id))).write(
      DocumentsTableCompanion(
        uploadState: Value(state),
        cloudPublicId: cloudPublicId != null
            ? Value(cloudPublicId)
            : const Value.absent(),
        cloudUrl: cloudUrl != null ? Value(cloudUrl) : const Value.absent(),
        localPath: localPath != null ? Value(localPath) : const Value.absent(),
        thumbnailPath: thumbnailPath != null
            ? Value(thumbnailPath)
            : const Value.absent(),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update the title of a document
  Future<void> updateDocumentTitle(String id, String newTitle) async {
    await (update(documentsTable)..where((d) => d.id.equals(id))).write(
      DocumentsTableCompanion(
        title: Value(newTitle),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update OCR state of a document
  Future<void> updateDocumentOcrState(
    String id,
    String ocrState, {
    String? ocrLanguage,
  }) async {
    await (update(documentsTable)..where((d) => d.id.equals(id))).write(
      DocumentsTableCompanion(
        ocrState: Value(ocrState),
        ocrLanguage: ocrLanguage != null ? Value(ocrLanguage) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get documents queued or in-progress for OCR
  Future<List<DocumentEntity>> getDocumentsPendingOcr() async {
    return (select(documentsTable)
          ..where((d) =>
              d.isDeleted.equals(false) &
              (d.ocrState.equals('queued') | d.ocrState.equals('processing'))))
        .get();
  }

  /// Soft-delete (tombstone) a document and enqueue sync operation
  Future<void> deleteDocument(String id, {bool enqueueSync = true}) async {
    await transaction(() async {
      await (update(documentsTable)..where((d) => d.id.equals(id))).write(
        DocumentsTableCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (enqueueSync) {
        await enqueueSyncOperation(id, 'document_delete');
      }
    });
  }

  /// Get all documents (including tombstones) for backup
  Future<List<DocumentEntity>> getAllDocuments() async {
    return select(documentsTable).get();
  }

  // ==========================================
  // DOCUMENT OCR OPERATIONS & QUERIES
  // ==========================================

  /// Save or update a single page OCR encrypted payload
  Future<void> saveDocumentOcrPage({
    required String documentId,
    required int pageNumber,
    required String encryptedPayload,
    int ocrSchemaVersion = 1,
    String ocrEngine = 'quietpaper_ocr_v1',
    String ocrEngineVersion = '1.0.0',
    String language = 'en',
    required DateTime processedAt,
  }) async {
    await into(documentOcrPagesTable).insertOnConflictUpdate(
      DocumentOcrPagesTableCompanion.insert(
        documentId: documentId,
        pageNumber: pageNumber,
        encryptedPayload: encryptedPayload,
        ocrSchemaVersion: Value(ocrSchemaVersion),
        ocrEngine: Value(ocrEngine),
        ocrEngineVersion: Value(ocrEngineVersion),
        language: Value(language),
        processedAt: processedAt,
      ),
    );
  }

  /// Get all OCR page records for a document ordered by page number
  Future<List<DocumentOcrPageEntity>> getDocumentOcrPages(String documentId) async {
    return (select(documentOcrPagesTable)
          ..where((p) => p.documentId.equals(documentId))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .get();
  }

  /// Watch all OCR page records for a document ordered by page number
  Stream<List<DocumentOcrPageEntity>> watchDocumentOcrPages(String documentId) {
    return (select(documentOcrPagesTable)
          ..where((p) => p.documentId.equals(documentId))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .watch();
  }

  /// Delete OCR pages for a document
  Future<void> deleteDocumentOcrPages(String documentId) async {
    await (delete(documentOcrPagesTable)..where((p) => p.documentId.equals(documentId))).go();
  }

  /// Get all OCR pages across all documents (for full backup)
  Future<List<DocumentOcrPageEntity>> getAllDocumentOcrPages() async {
    return select(documentOcrPagesTable).get();
  }
}
