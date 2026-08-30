import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../search/search_index_projection.dart';
import '../search/search_models.dart';
import '../search/search_tokenizer.dart';
import '../utils/tag_parser.dart';
import 'connection/connection.dart' as conn;
import 'tables/attachment_ocr_pages_table.dart';
import 'tables/attachment_variants_table.dart';
import 'tables/attachments_table.dart';
import 'tables/document_ocr_pages_table.dart';
import 'tables/documents_table.dart';
import 'tables/note_tags_table.dart';
import 'tables/note_versions_table.dart';
import 'tables/notes_table.dart';
import 'tables/sync_conflicts_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/tags_table.dart';
import '../ocr/ocr_models.dart';

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

  String get id => tag.id;
  String get name => tag.name;
  String? get icon => tag.icon;
  String? get color => tag.color;
  bool get isPinned => tag.isPinned;
  int get pinnedOrder => tag.pinnedOrder;
  DateTime? get createdAt => tag.createdAt;
  DateTime? get updatedAt => tag.updatedAt;
}

@DriftDatabase(tables: [
  NotesTable,
  TagsTable,
  NoteTagsTable,
  SyncMetadataTable,
  SyncQueueTable,
  AttachmentsTable,
  AttachmentVariantsTable,
  AttachmentOcrPagesTable,
  NoteVersionsTable,
  DocumentsTable,
  DocumentOcrPagesTable,
  SyncConflictsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? conn.openConnection());

  AppDatabase.memory() : super(conn.openInMemoryConnection());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts5TablesAndTriggers();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _addColumnSafely(m, notesTable, notesTable.isArchived);
            await _addColumnSafely(m, notesTable, notesTable.isTrashed);
            await _addColumnSafely(m, notesTable, notesTable.deletedAt);
          }
          if (from < 3) {
            await _addColumnSafely(m, notesTable, notesTable.serverRevision);
            await _addColumnSafely(m, notesTable, notesTable.isDirty);
            await _addColumnSafely(m, notesTable, notesTable.syncedAt);
            await _createTableSafely(m, syncMetadataTable);
            await _createTableSafely(m, syncQueueTable);
          }
          if (from < 4) {
            await _createTableSafely(m, attachmentsTable);
            await _createTableSafely(m, attachmentVariantsTable);
          }
          if (from < 5) {
            await _createTableSafely(m, noteVersionsTable);
          }
          if (from < 6) {
            await _createTableSafely(m, documentsTable);
          }
          if (from < 7) {
            if (from >= 6) {
              await _addColumnSafely(m, documentsTable, documentsTable.source);
              await _addColumnSafely(m, documentsTable, documentsTable.ocrState);
              await _addColumnSafely(
                m,
                documentsTable,
                documentsTable.ocrLanguage,
              );
            }
            await _createTableSafely(m, documentOcrPagesTable);
          }
          if (from < 8) {
            await _createTableSafely(m, syncConflictsTable);
            if (from >= 5) {
              await _addColumnSafely(
                m,
                noteVersionsTable,
                noteVersionsTable.baseRevision,
              );
              await _addColumnSafely(
                m,
                noteVersionsTable,
                noteVersionsTable.localParentRevision,
              );
              await _addColumnSafely(
                m,
                noteVersionsTable,
                noteVersionsTable.remoteParentRevision,
              );
              await _addColumnSafely(
                m,
                noteVersionsTable,
                noteVersionsTable.mergeType,
              );
              await _addColumnSafely(
                m,
                noteVersionsTable,
                noteVersionsTable.resolutionSummary,
              );
            }
          }
          if (from < 9) {
            if (from >= 4) {
              await _addColumnSafely(m, attachmentsTable, attachmentsTable.ocrState);
              await _addColumnSafely(m, attachmentsTable, attachmentsTable.ocrLanguage);
            }
            await _createTableSafely(m, attachmentOcrPagesTable);
          }
          if (from < 10) {
            await _createFts5TablesAndTriggers();
            await _backfillSearchIndex();
          }
          if (from < 11) {
            if (from >= 4) {
              await _addColumnSafely(m, attachmentsTable, attachmentsTable.fileName);
              await _addColumnSafely(m, attachmentsTable, attachmentsTable.kind);
            }
          }
          if (from < 12) {
            await _addColumnSafely(m, tagsTable, tagsTable.icon);
            await _addColumnSafely(m, tagsTable, tagsTable.color);
            await _addColumnSafely(m, tagsTable, tagsTable.isPinned);
            await _addColumnSafely(m, tagsTable, tagsTable.pinnedOrder);
            await _addColumnSafely(m, tagsTable, tagsTable.createdAt);
            await _addColumnSafely(m, tagsTable, tagsTable.updatedAt);
            await _addColumnSafely(m, tagsTable, tagsTable.isDirty);
            await _addColumnSafely(m, tagsTable, tagsTable.serverRevision);
            await _addColumnSafely(m, tagsTable, tagsTable.syncedAt);
            await _addColumnSafely(m, tagsTable, tagsTable.isDeleted);
            await _addColumnSafely(m, tagsTable, tagsTable.deletedAt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await _createFts5TablesAndTriggers();
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
            'CREATE INDEX IF NOT EXISTS tags_pinned_idx ON tags (is_pinned, pinned_order);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS tags_name_idx ON tags (name);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS tags_dirty_idx ON tags (is_dirty);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachments_note_idx ON attachments (note_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachments_kind_idx ON attachments (kind);',
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
          await customStatement(
            'CREATE INDEX IF NOT EXISTS attachment_ocr_att_idx ON attachment_ocr_pages (attachment_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sync_conflicts_note_idx ON sync_conflicts (note_id, state);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sync_conflicts_state_idx ON sync_conflicts (state);',
          );
        },
      );

  Future<void> _addColumnSafely(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    try {
      final rows = await customSelect(
        'PRAGMA table_info("${table.actualTableName}");',
      ).get();
      final columnNames = rows
          .map((r) => r.read<String>('name').toLowerCase())
          .toSet();
      if (!columnNames.contains(column.name.toLowerCase())) {
        await m.addColumn(table, column);
      }
    } catch (_) {
      try {
        await m.addColumn(table, column);
      } catch (e) {
        if (!e.toString().toLowerCase().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
  }

  Future<void> _createTableSafely(
    Migrator m,
    TableInfo table,
  ) async {
    try {
      final rows = await customSelect(
        'SELECT name FROM sqlite_master WHERE type="table" AND name="${table.actualTableName}";',
      ).get();
      if (rows.isEmpty) {
        await m.createTable(table);
      }
    } catch (_) {
      try {
        await m.createTable(table);
      } catch (e) {
        if (!e.toString().toLowerCase().contains('already exists')) {
          rethrow;
        }
      }
    }
  }

  // ==========================================
  // FTS5 SEARCH INDEX & RETRIEVAL OPERATIONS
  // ==========================================

  Future<void> _createFts5TablesAndTriggers() async {
    try {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS note_search_prefix USING fts5(
            note_id UNINDEXED,
            title,
            body_text,
            tags,
            tokenize = 'unicode61 remove_diacritics 2'
        );
      ''');
    } catch (_) {}

    try {
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS note_search_trigram USING fts5(
            note_id UNINDEXED,
            title,
            body_text,
            tags,
            tokenize = 'trigram'
        );
      ''');
    } catch (_) {}

    try {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS trg_notes_fts_delete AFTER DELETE ON notes
        BEGIN
          DELETE FROM note_search_prefix WHERE note_id = old.id;
          DELETE FROM note_search_trigram WHERE note_id = old.id;
        END;
      ''');
    } catch (_) {}
  }

  Future<void> _backfillSearchIndex() async {
    try {
      final activeNotes = await (select(notesTable)..where((n) => n.isTrashed.equals(false))).get();
      if (activeNotes.isEmpty) return;

      final noteIds = activeNotes.map((n) => n.id).toList();
      final tagsMap = await getTagsForNoteIds(noteIds);

      for (final note in activeNotes) {
        final tags = (tagsMap[note.id] ?? []).map((t) => t.name).toList();
        final projection = SearchIndexProjection.project(
          noteId: note.id,
          title: note.title,
          content: note.content,
          tags: tags,
          isTrashed: note.isTrashed,
          deletedAt: note.deletedAt,
        );

        if (projection.title.isNotEmpty || projection.bodyText.isNotEmpty || projection.tags.isNotEmpty) {
          await customStatement(
            'INSERT INTO note_search_prefix (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
            [projection.noteId, projection.title, projection.bodyText, projection.tags],
          );
          await customStatement(
            'INSERT INTO note_search_trigram (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
            [projection.noteId, projection.title, projection.bodyText, projection.tags],
          );
        }
      }
    } catch (_) {}
  }

  /// Updates or inserts a note into both FTS5 search indexes atomically.
  Future<void> indexNoteForSearch(String noteId) async {
    try {
      final note = await (select(notesTable)..where((n) => n.id.equals(noteId))).getSingleOrNull();
      if (note == null || note.isTrashed || note.deletedAt != null) {
        await removeNoteFromSearchIndex(noteId);
        return;
      }

      final tags = await _getTagsForNote(noteId);
      final tagNames = tags.map((t) => t.name).toList();

      final projection = SearchIndexProjection.project(
        noteId: note.id,
        title: note.title,
        content: note.content,
        tags: tagNames,
        isTrashed: note.isTrashed,
        deletedAt: note.deletedAt,
      );

      await customStatement(
        'DELETE FROM note_search_prefix WHERE note_id = ?;',
        [noteId],
      );
      await customStatement(
        'DELETE FROM note_search_trigram WHERE note_id = ?;',
        [noteId],
      );

      if (projection.title.isNotEmpty || projection.bodyText.isNotEmpty || projection.tags.isNotEmpty) {
        await customStatement(
          'INSERT INTO note_search_prefix (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
          [projection.noteId, projection.title, projection.bodyText, projection.tags],
        );
        await customStatement(
          'INSERT INTO note_search_trigram (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
          [projection.noteId, projection.title, projection.bodyText, projection.tags],
        );
      }
    } catch (_) {}
  }

  /// Removes a note from both FTS5 search indexes.
  Future<void> removeNoteFromSearchIndex(String noteId) async {
    try {
      await customStatement(
        'DELETE FROM note_search_prefix WHERE note_id = ?;',
        [noteId],
      );
      await customStatement(
        'DELETE FROM note_search_trigram WHERE note_id = ?;',
        [noteId],
      );
    } catch (_) {}
  }

  /// Completely clears and repopulates both FTS search indexes in a single transaction.
  Future<void> rebuildSearchIndex() async {
    await transaction(() async {
      try {
        await customStatement('DELETE FROM note_search_prefix;');
        await customStatement('DELETE FROM note_search_trigram;');
      } catch (_) {}
      await _backfillSearchIndex();
    });
  }

  /// Tier 1 candidate retrieval: queries prefix and trigram FTS5 indexes and merges candidate note IDs.
  Future<List<String>> searchNoteCandidateIds(
    CompiledSearchQuery query, {
    int limit = 200,
  }) async {
    if (query.isEmpty) return const [];

    final candidateIds = <String>{};

    // 1. Prefix query in note_search_prefix
    if (query.ftsPrefixExpression.isNotEmpty) {
      try {
        final rows = await customSelect(
          'SELECT note_id FROM note_search_prefix WHERE note_search_prefix MATCH ? ORDER BY rank LIMIT ?;',
          variables: [
            Variable.withString(query.ftsPrefixExpression),
            Variable.withInt(limit),
          ],
        ).get();
        for (final row in rows) {
          final id = row.read<String>('note_id');
          candidateIds.add(id);
        }
      } catch (_) {}
    }

    // 2. Trigram query in note_search_trigram (for substring matches like 'part' in 'counterpart')
    if (query.isTrigramEligible && query.ftsTrigramExpression.isNotEmpty && candidateIds.length < limit) {
      try {
        final trigramLimit = limit - candidateIds.length;
        final rows = await customSelect(
          'SELECT note_id FROM note_search_trigram WHERE note_search_trigram MATCH ? ORDER BY rank LIMIT ?;',
          variables: [
            Variable.withString(query.ftsTrigramExpression),
            Variable.withInt(trigramLimit),
          ],
        ).get();
        for (final row in rows) {
          final id = row.read<String>('note_id');
          candidateIds.add(id);
        }
      } catch (_) {}
    }

    // 3. Fallback for very short queries (1-2 chars) or if FTS returns zero results
    if (candidateIds.isEmpty && query.cleanQuery.isNotEmpty) {
      try {
        final pattern = '%${query.cleanQuery}%';
        final rows = await customSelect(
          'SELECT id FROM notes WHERE is_trashed = 0 AND (LOWER(title) LIKE ? OR LOWER(content) LIKE ?) LIMIT ?;',
          variables: [
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withInt(limit),
          ],
        ).get();
        for (final row in rows) {
          candidateIds.add(row.read<String>('id'));
        }
      } catch (_) {}
    }

    return candidateIds.toList();
  }

  /// Fetches minimal SearchCandidateDto records for candidate IDs to pass across isolate boundaries.
  Future<List<SearchCandidateDto>> getSearchCandidatesByIds(List<String> noteIds) async {
    if (noteIds.isEmpty) return const [];

    final rows = await (select(notesTable)
          ..where((n) => n.id.isIn(noteIds) & n.isTrashed.equals(false)))
        .get();

    if (rows.isEmpty) return const [];

    final actualIds = rows.map((n) => n.id).toList();
    final tagsMap = await getTagsForNoteIds(actualIds);

    return rows.map((n) {
      final tags = (tagsMap[n.id] ?? []).map((t) => t.name).toList();
      return SearchCandidateDto(
        id: n.id,
        title: n.title,
        content: n.content,
        tags: tags,
        updatedAt: n.updatedAt,
        isPinned: n.isPinned,
        isArchived: n.isArchived,
        isPasswordProtected: SearchIndexProjection.isPasswordProtected(n.content),
      );
    }).toList();
  }

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
    List<String>? matchingNoteIds,
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

        final matchesAdditional = (matchingNoteIds != null && matchingNoteIds.isNotEmpty)
            ? n.id.isIn(matchingNoteIds)
            : const Constant(false);

        return titleOrContentMatch | existsQuery(tagSubQuery) | existsQuery(docSubQuery) | matchesAdditional;
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
      final tagsByNoteId = await getTagsForNoteIds(noteIds);

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

      // Extract and sync tags if tags list is empty or not passed, or sync provided tags
      final extractedTags = (tags != null && tags.isNotEmpty)
          ? tags
          : TagParser.extractTags('$title\n$content');
      await _syncNoteTags(id, extractedTags);

      // Atomic FTS5 Search Index Maintenance
      await customStatement(
        'DELETE FROM note_search_prefix WHERE note_id = ?;',
        [id],
      );
      await customStatement(
        'DELETE FROM note_search_trigram WHERE note_id = ?;',
        [id],
      );

      if (!isTrashed && deletedAt == null) {
        final projection = SearchIndexProjection.project(
          noteId: id,
          title: title,
          content: content,
          tags: extractedTags,
          isTrashed: isTrashed,
          deletedAt: deletedAt,
        );

        if (projection.title.isNotEmpty || projection.bodyText.isNotEmpty || projection.tags.isNotEmpty) {
          await customStatement(
            'INSERT INTO note_search_prefix (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
            [projection.noteId, projection.title, projection.bodyText, projection.tags],
          );
          await customStatement(
            'INSERT INTO note_search_trigram (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
            [projection.noteId, projection.title, projection.bodyText, projection.tags],
          );
        }
      }
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
    await transaction(() async {
      await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
        NotesTableCompanion(
          isTrashed: const Value(true),
          isArchived: const Value(false),
          deletedAt: Value(DateTime.now()),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await removeNoteFromSearchIndex(noteId);
    });
  }

  /// Restore note from Trash: trashed = false, archived = false, deletedAt = null
  Future<void> restoreFromTrash(String noteId) async {
    await transaction(() async {
      await (update(notesTable)..where((n) => n.id.equals(noteId))).write(
        NotesTableCompanion(
          isTrashed: const Value(false),
          isArchived: const Value(false),
          deletedAt: const Value(null),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await indexNoteForSearch(noteId);
    });
  }

  /// Permanent hard deletion of a single note
  Future<void> deletePermanently(String noteId, {bool enqueueSync = true}) async {
    await transaction(() async {
      await (delete(noteVersionsTable)..where((v) => v.noteId.equals(noteId))).go();
      await (delete(noteTagsTable)..where((nt) => nt.noteId.equals(noteId))).go();
      await (delete(notesTable)..where((n) => n.id.equals(noteId))).go();
      await removeNoteFromSearchIndex(noteId);
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
        for (final id in trashedIds) {
          await removeNoteFromSearchIndex(id);
        }
        await (delete(noteVersionsTable)..where((v) => v.noteId.isIn(trashedIds))).go();
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
    await transaction(() async {
      await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
        NotesTableCompanion(
          isTrashed: const Value(true),
          isArchived: const Value(false),
          deletedAt: Value(DateTime.now()),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      for (final id in noteIds) {
        await removeNoteFromSearchIndex(id);
      }
    });
  }

  /// Batch restore
  Future<void> restoreNotes(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await transaction(() async {
      await (update(notesTable)..where((n) => n.id.isIn(noteIds))).write(
        NotesTableCompanion(
          isTrashed: const Value(false),
          isArchived: const Value(false),
          deletedAt: const Value(null),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      for (final id in noteIds) {
        await indexNoteForSearch(id);
      }
    });
  }

  /// Batch permanent deletion
  Future<void> deletePermanentlyBatch(List<String> noteIds, {bool enqueueSync = true}) async {
    if (noteIds.isEmpty) return;
    await transaction(() async {
      for (final id in noteIds) {
        await removeNoteFromSearchIndex(id);
      }
      await (delete(noteVersionsTable)..where((v) => v.noteId.isIn(noteIds))).go();
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

  Future<List<NoteEntity>> getAllNotesRaw() async => select(notesTable).get();
  Future<List<AttachmentEntity>> getAllAttachmentsRaw() async => select(attachmentsTable).get();
  Future<List<DocumentEntity>> getAllDocumentsRaw() async => select(documentsTable).get();
  Future<void> deleteAttachmentLocal(String id) async => (delete(attachmentsTable)..where((t) => t.id.equals(id))).go();
  Future<void> deleteDocumentLocal(String id) async => (delete(documentsTable)..where((t) => t.id.equals(id))).go();

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
    final tagsMap = await getTagsForNoteIds(ids);

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

  /// Resets sync cursors in sync metadata to force clean initial pull or re-sync
  Future<void> resetSyncCursors() async {
    await (delete(syncMetadataTable)
          ..where((t) =>
              t.key.equals('sync_cursor') |
              t.key.equals('version_sync_cursor')))
        .go();
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
    final activeNotesCount = CustomExpression<int>(
      'COUNT(CASE WHEN notes.is_archived = 0 AND notes.is_trashed = 0 AND notes.id IS NOT NULL THEN 1 END)',
    );

    final query = select(tagsTable).join([
      leftOuterJoin(
        noteTagsTable,
        noteTagsTable.tagId.equalsExp(tagsTable.id),
      ),
      leftOuterJoin(
        notesTable,
        notesTable.id.equalsExp(noteTagsTable.noteId),
      ),
    ]);

    query.where(tagsTable.isDeleted.equals(false));
    query.groupBy([
      tagsTable.id,
      tagsTable.name,
      tagsTable.icon,
      tagsTable.color,
      tagsTable.isPinned,
      tagsTable.pinnedOrder,
      tagsTable.createdAt,
      tagsTable.updatedAt,
      tagsTable.isDirty,
      tagsTable.serverRevision,
      tagsTable.syncedAt,
      tagsTable.isDeleted,
      tagsTable.deletedAt,
    ]);
    query.addColumns([activeNotesCount]);
    query.orderBy([
      OrderingTerm.desc(tagsTable.isPinned),
      OrderingTerm.asc(tagsTable.pinnedOrder),
      OrderingTerm.desc(activeNotesCount),
      OrderingTerm.asc(tagsTable.name),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tag = row.readTable(tagsTable);
        final count = row.read(activeNotesCount) ?? 0;
        return TagWithCount(tag: tag, noteCount: count);
      }).toList();
    });
  }

  /// Get all distinct active tag names
  Future<List<String>> getAllTagNames() async {
    final tags = await (select(tagsTable)..where((t) => t.isDeleted.equals(false))).get();
    return tags.map((t) => t.name).toList();
  }

  /// Retrieves a tag by its stable ID
  Future<TagEntity?> getTagById(String id) {
    return (select(tagsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Retrieves a tag by its textual name
  Future<TagEntity?> getTagByName(String name) {
    final normalized = TagParser.normalizeTag(name);
    return (select(tagsTable)..where((t) => t.name.equals(normalized))).getSingleOrNull();
  }

  /// Creates a new tag or restores/updates existing
  Future<TagEntity> createTag(
    String name, {
    String? icon,
    String? color,
    bool isPinned = false,
  }) async {
    const uuid = Uuid();
    final normalized = TagParser.normalizeTag(name);
    if (!TagParser.isValidTag(normalized)) {
      throw ArgumentError('Invalid tag name: $name');
    }
    final now = DateTime.now();

    final existing = await (select(tagsTable)..where((t) => t.name.equals(normalized))).getSingleOrNull();
    if (existing != null) {
      if (existing.isDeleted) {
        await (update(tagsTable)..where((t) => t.id.equals(existing.id))).write(
          TagsTableCompanion(
            isDeleted: const Value(false),
            deletedAt: const Value(null),
            icon: Value(icon ?? existing.icon),
            color: Value(color ?? existing.color),
            isPinned: Value(isPinned),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
        return (await (select(tagsTable)..where((t) => t.id.equals(existing.id))).getSingle());
      }
      return existing;
    }

    final newId = uuid.v4();
    await into(tagsTable).insert(
      TagsTableCompanion.insert(
        id: newId,
        name: normalized,
        icon: Value(icon),
        color: Value(color),
        isPinned: Value(isPinned),
        pinnedOrder: const Value(0),
        createdAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
        serverRevision: const Value(0),
        isDeleted: const Value(false),
      ),
    );
    return (await (select(tagsTable)..where((t) => t.id.equals(newId))).getSingle());
  }

  /// Renames a tag and propagates the change to all associated note Markdown
  Future<void> renameTag(String tagId, String newName) async {
    final normalizedNew = TagParser.normalizeTag(newName);
    if (!TagParser.isValidTag(normalizedNew)) {
      throw ArgumentError('Invalid tag name: $newName');
    }

    await transaction(() async {
      final tag = await (select(tagsTable)..where((t) => t.id.equals(tagId))).getSingleOrNull();
      if (tag == null) return;
      final oldName = tag.name;
      if (oldName == normalizedNew) return;

      final existingWithNewName = await (select(tagsTable)..where((t) => t.name.equals(normalizedNew))).getSingleOrNull();
      if (existingWithNewName != null && existingWithNewName.id != tagId) {
        throw StateError('A tag with name "$normalizedNew" already exists.');
      }

      final now = DateTime.now();

      await (update(tagsTable)..where((t) => t.id.equals(tagId))).write(
        TagsTableCompanion(
          name: Value(normalizedNew),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );

      final noteRows = await (select(noteTagsTable)..where((nt) => nt.tagId.equals(tagId))).get();
      final noteIds = noteRows.map((r) => r.noteId).toList();

      for (final noteId in noteIds) {
        final note = await (select(notesTable)..where((n) => n.id.equals(noteId))).getSingleOrNull();
        if (note == null) continue;

        final newTitle = TagParser.renameTagInText(note.title, oldName, normalizedNew);
        final newContent = TagParser.renameTagInText(note.content, oldName, normalizedNew);

        await saveNote(
          id: note.id,
          title: newTitle,
          content: newContent,
          createdAt: note.createdAt,
          updatedAt: now,
          isPinned: note.isPinned,
          isArchived: note.isArchived,
          isTrashed: note.isTrashed,
          deletedAt: note.deletedAt,
          isDirty: true,
        );
      }
    });
  }

  /// Deletes a tag and removes it from all note Markdown without deleting notes
  Future<void> deleteTag(String tagId) async {
    await transaction(() async {
      final tag = await (select(tagsTable)..where((t) => t.id.equals(tagId))).getSingleOrNull();
      if (tag == null) return;

      final now = DateTime.now();
      final noteRows = await (select(noteTagsTable)..where((nt) => nt.tagId.equals(tagId))).get();
      final noteIds = noteRows.map((r) => r.noteId).toList();

      for (final noteId in noteIds) {
        final note = await (select(notesTable)..where((n) => n.id.equals(noteId))).getSingleOrNull();
        if (note == null) continue;

        final newTitle = TagParser.removeTagFromText(note.title, tag.name);
        final newContent = TagParser.removeTagFromText(note.content, tag.name);

        await saveNote(
          id: note.id,
          title: newTitle,
          content: newContent,
          createdAt: note.createdAt,
          updatedAt: now,
          isPinned: note.isPinned,
          isArchived: note.isArchived,
          isTrashed: note.isTrashed,
          deletedAt: note.deletedAt,
          isDirty: true,
        );
      }

      await (delete(tagsTable)..where((t) => t.id.equals(tagId))).go();
    });
  }

  /// Merges sourceTag into destinationTag, updating Markdown across all notes
  Future<void> mergeTags(String sourceTagId, String destinationTagId) async {
    if (sourceTagId == destinationTagId) return;

    await transaction(() async {
      final sourceTag = await (select(tagsTable)..where((t) => t.id.equals(sourceTagId))).getSingleOrNull();
      final destTag = await (select(tagsTable)..where((t) => t.id.equals(destinationTagId))).getSingleOrNull();
      if (sourceTag == null || destTag == null) return;

      final now = DateTime.now();
      final noteRows = await (select(noteTagsTable)..where((nt) => nt.tagId.equals(sourceTagId))).get();
      final noteIds = noteRows.map((r) => r.noteId).toList();

      for (final noteId in noteIds) {
        final note = await (select(notesTable)..where((n) => n.id.equals(noteId))).getSingleOrNull();
        if (note == null) continue;

        final newTitle = TagParser.mergeTagsInText(note.title, sourceTag.name, destTag.name);
        final newContent = TagParser.mergeTagsInText(note.content, sourceTag.name, destTag.name);

        await saveNote(
          id: note.id,
          title: newTitle,
          content: newContent,
          createdAt: note.createdAt,
          updatedAt: now,
          isPinned: note.isPinned,
          isArchived: note.isArchived,
          isTrashed: note.isTrashed,
          deletedAt: note.deletedAt,
          isDirty: true,
        );
      }

      await (delete(tagsTable)..where((t) => t.id.equals(sourceTagId))).go();
    });
  }

  /// Pins or unpins a tag
  Future<void> pinTag(String tagId, bool isPinned) async {
    int nextOrder = 0;
    if (isPinned) {
      final pinnedTags = await (select(tagsTable)
            ..where((t) => t.isPinned.equals(true) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.pinnedOrder)]))
          .get();
      if (pinnedTags.isNotEmpty) {
        nextOrder = pinnedTags.first.pinnedOrder + 1;
      }
    }

    await (update(tagsTable)..where((t) => t.id.equals(tagId))).write(
      TagsTableCompanion(
        isPinned: Value(isPinned),
        pinnedOrder: Value(nextOrder),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Reorders pinned tags by their specified list of IDs
  Future<void> reorderPinnedTags(List<String> orderedTagIds) async {
    await transaction(() async {
      final now = DateTime.now();
      for (var i = 0; i < orderedTagIds.length; i++) {
        await (update(tagsTable)..where((t) => t.id.equals(orderedTagIds[i]))).write(
          TagsTableCompanion(
            pinnedOrder: Value(i),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
      }
    });
  }

  /// Updates a tag's vector icon identifier
  Future<void> setTagIcon(String tagId, String? icon) async {
    await (update(tagsTable)..where((t) => t.id.equals(tagId))).write(
      TagsTableCompanion(
        icon: Value(icon),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Updates a tag's color accent identifier
  Future<void> setTagColor(String tagId, String? color) async {
    await (update(tagsTable)..where((t) => t.id.equals(tagId))).write(
      TagsTableCompanion(
        color: Value(color),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
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

  Future<Map<String, List<TagEntity>>> getTagsForNoteIds(
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
      return;
    }

    for (final tagName in normalized) {
      var tag = await (select(tagsTable)..where((t) => t.name.equals(tagName)))
          .getSingleOrNull();

      if (tag == null) {
        final newTagId = uuid.v4();
        final now = DateTime.now();
        await into(tagsTable).insert(
          TagsTableCompanion.insert(
            id: newTagId,
            name: tagName,
            createdAt: Value(now),
            updatedAt: Value(now),
            isPinned: const Value(false),
            pinnedOrder: const Value(0),
            isDirty: const Value(true),
          ),
        );
        tag = TagEntity(
          id: newTagId,
          name: tagName,
          isPinned: false,
          pinnedOrder: 0,
          createdAt: now,
          updatedAt: now,
          isDirty: true,
          serverRevision: 0,
          isDeleted: false,
        );
      }

      await into(noteTagsTable).insertOnConflictUpdate(
        NoteTagsTableCompanion.insert(
          noteId: noteId,
          tagId: tag.id,
        ),
      );
    }
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
    String fileName = 'attachment',
    String kind = 'image',
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
    String ocrState = 'not_requested',
    String ocrLanguage = 'en',
  }) async {
    await into(attachmentsTable).insertOnConflictUpdate(
      AttachmentsTableCompanion.insert(
        id: id,
        noteId: Value(noteId),
        fileName: Value(fileName),
        kind: Value(kind),
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
        ocrState: Value(ocrState),
        ocrLanguage: Value(ocrLanguage),
      ),
    );
  }

  /// Updates the user-visible filename of an attachment (preserves bytes and hash)
  Future<void> updateAttachmentFileName(String id, String fileName) async {
    await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
      AttachmentsTableCompanion(
        fileName: Value(fileName),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Updates the note association of an attachment
  Future<void> updateAttachmentNoteId(String id, String? noteId) async {
    await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
      AttachmentsTableCompanion(
        noteId: Value(noteId),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update OCR status of an attachment
  Future<void> updateAttachmentOcrState(
    String id,
    String ocrState, {
    String? ocrLanguage,
  }) async {
    await (update(attachmentsTable)..where((a) => a.id.equals(id))).write(
      AttachmentsTableCompanion(
        ocrState: Value(ocrState),
        ocrLanguage: ocrLanguage != null ? Value(ocrLanguage) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get all active non-deleted attachments
  Future<List<AttachmentEntity>> getActiveAttachments() async {
    return (select(attachmentsTable)..where((a) => a.isDeleted.equals(false)))
        .get();
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
    int? baseRevision,
    int? localParentRevision,
    int? remoteParentRevision,
    String? mergeType,
    String? resolutionSummary,
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
        baseRevision: Value(baseRevision),
        localParentRevision: Value(localParentRevision),
        remoteParentRevision: Value(remoteParentRevision),
        mergeType: Value(mergeType),
        resolutionSummary: Value(resolutionSummary),
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
  // SYNC CONFLICT OPERATIONS & STREAM QUERIES
  // ==========================================

  /// Save or update a sync conflict record
  Future<void> saveConflict({
    required String id,
    required String noteId,
    int baseRevision = 0,
    int localRevision = 0,
    int remoteRevision = 0,
    String conflictType = 'content',
    String state = 'detected',
    required DateTime createdAt,
    DateTime? resolvedAt,
    int? resolutionRevision,
    String? resolutionType,
    String dataJson = '{}',
  }) async {
    await into(syncConflictsTable).insertOnConflictUpdate(
      SyncConflictsTableCompanion.insert(
        id: id,
        noteId: noteId,
        baseRevision: Value(baseRevision),
        localRevision: Value(localRevision),
        remoteRevision: Value(remoteRevision),
        conflictType: Value(conflictType),
        state: Value(state),
        createdAt: createdAt,
        resolvedAt: Value(resolvedAt),
        resolutionRevision: Value(resolutionRevision),
        resolutionType: Value(resolutionType),
        dataJson: Value(dataJson),
      ),
    );
  }

  /// Get all active/pending conflicts requiring manual resolution
  Future<List<SyncConflictEntity>> getPendingConflicts() async {
    return (select(syncConflictsTable)
          ..where((c) =>
              c.state.isNotValue('resolved') & c.state.isNotValue('autoMerged'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  /// Watch active/pending conflicts requiring manual resolution
  Stream<List<SyncConflictEntity>> watchPendingConflicts() {
    return (select(syncConflictsTable)
          ..where((c) =>
              c.state.isNotValue('resolved') & c.state.isNotValue('autoMerged'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  /// Watch count of pending conflicts
  Stream<int> watchPendingConflictsCount() {
    final countExp = syncConflictsTable.id.count();
    final query = selectOnly(syncConflictsTable)
      ..where(syncConflictsTable.state.isNotValue('resolved') &
          syncConflictsTable.state.isNotValue('autoMerged'))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Get pending conflict count (Future)
  Future<int> getPendingConflictsCount() async {
    final countExp = syncConflictsTable.id.count();
    final query = selectOnly(syncConflictsTable)
      ..where(syncConflictsTable.state.isNotValue('resolved') &
          syncConflictsTable.state.isNotValue('autoMerged'))
      ..addColumns([countExp]);

    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Get single conflict by ID
  Future<SyncConflictEntity?> getConflict(String id) async {
    return (select(syncConflictsTable)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get most recent unresolved conflict for a note
  Future<SyncConflictEntity?> getConflictForNote(String noteId) async {
    return (select(syncConflictsTable)
          ..where((c) =>
              c.noteId.equals(noteId) &
              c.state.isNotValue('resolved') &
              c.state.isNotValue('autoMerged'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Mark conflict resolved
  Future<void> markConflictResolved(
    String id, {
    required int resolutionRevision,
    required String resolutionType,
  }) async {
    await (update(syncConflictsTable)..where((c) => c.id.equals(id))).write(
      SyncConflictsTableCompanion(
        state: const Value('resolved'),
        resolvedAt: Value(DateTime.now()),
        resolutionRevision: Value(resolutionRevision),
        resolutionType: Value(resolutionType),
      ),
    );
  }

  /// Delete conflict record
  Future<void> deleteConflict(String id) async {
    await (delete(syncConflictsTable)..where((c) => c.id.equals(id))).go();
  }

  /// Delete all conflicts for a note
  Future<void> deleteConflictsForNote(String noteId) async {
    await (delete(syncConflictsTable)..where((c) => c.noteId.equals(noteId))).go();
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

  /// Get all active (non-deleted) documents
  Future<List<DocumentEntity>> getActiveDocuments() async {
    return (select(documentsTable)..where((d) => d.isDeleted.equals(false))).get();
  }

  /// Watch all active (non-deleted) documents
  Stream<List<DocumentEntity>> watchActiveDocuments() {
    return (select(documentsTable)..where((d) => d.isDeleted.equals(false))).watch();
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

  /// Get a single OCR page record for a document by page number
  Future<DocumentOcrPageEntity?> getDocumentOcrPage(String documentId, int pageNumber) async {
    return (select(documentOcrPagesTable)
          ..where((p) => p.documentId.equals(documentId) & p.pageNumber.equals(pageNumber)))
        .getSingleOrNull();
  }

  /// Get total count of OCR pages for a document
  Future<int> getDocumentOcrPageCount(String documentId) async {
    final countExp = documentOcrPagesTable.pageNumber.count();
    final query = selectOnly(documentOcrPagesTable)
      ..addColumns([countExp])
      ..where(documentOcrPagesTable.documentId.equals(documentId));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Get lightweight OCR metadata summary for a document without loading encrypted payloads
  Future<OcrDocumentMetadata?> getDocumentOcrMetadata(String documentId) async {
    final rows = await (select(documentOcrPagesTable)
          ..where((p) => p.documentId.equals(documentId))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .get();

    if (rows.isEmpty) return null;

    final first = rows.first;
    return OcrDocumentMetadata(
      documentId: documentId,
      pageCount: rows.length,
      language: OcrLanguage.fromCode(first.language),
      engine: first.ocrEngine,
      engineVersion: first.ocrEngineVersion,
      schemaVersion: first.ocrSchemaVersion,
      processedAt: first.processedAt,
      pageNumbers: rows.map((r) => r.pageNumber).toList(),
    );
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

  // ==========================================
  // ATTACHMENT OCR OPERATIONS & QUERIES
  // ==========================================

  /// Save or update an attachment OCR page encrypted payload
  Future<void> saveAttachmentOcrPage({
    required String attachmentId,
    int pageNumber = 1,
    required String encryptedPayload,
    int ocrSchemaVersion = 1,
    String ocrEngine = 'quietpaper_ocr_v1',
    String ocrEngineVersion = '1.0.0',
    String language = 'en',
    required DateTime processedAt,
  }) async {
    await into(attachmentOcrPagesTable).insertOnConflictUpdate(
      AttachmentOcrPagesTableCompanion.insert(
        attachmentId: attachmentId,
        pageNumber: Value(pageNumber),
        encryptedPayload: encryptedPayload,
        ocrSchemaVersion: Value(ocrSchemaVersion),
        ocrEngine: Value(ocrEngine),
        ocrEngineVersion: Value(ocrEngineVersion),
        language: Value(language),
        processedAt: processedAt,
      ),
    );
  }

  /// Get all OCR page records for an attachment ordered by page number
  Future<List<AttachmentOcrPageEntity>> getAttachmentOcrPages(String attachmentId) async {
    return (select(attachmentOcrPagesTable)
          ..where((p) => p.attachmentId.equals(attachmentId))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .get();
  }

  /// Watch all OCR page records for an attachment ordered by page number
  Stream<List<AttachmentOcrPageEntity>> watchAttachmentOcrPages(String attachmentId) {
    return (select(attachmentOcrPagesTable)
          ..where((p) => p.attachmentId.equals(attachmentId))
          ..orderBy([(p) => OrderingTerm.asc(p.pageNumber)]))
        .watch();
  }

  /// Delete OCR pages for an attachment
  Future<void> deleteAttachmentOcrPages(String attachmentId) async {
    await (delete(attachmentOcrPagesTable)..where((p) => p.attachmentId.equals(attachmentId))).go();
  }

  /// Get all OCR pages across all attachments (for full search/backup)
  Future<List<AttachmentOcrPageEntity>> getAllAttachmentOcrPages() async {
    return select(attachmentOcrPagesTable).get();
  }
}
