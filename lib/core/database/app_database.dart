import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../utils/tag_parser.dart';
import 'connection/connection.dart' as conn;
import 'tables/note_tags_table.dart';
import 'tables/notes_table.dart';
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

@DriftDatabase(tables: [NotesTable, TagsTable, NoteTagsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? conn.openConnection());

  AppDatabase.memory() : super(conn.openInMemoryConnection());

  @override
  int get schemaVersion => 2;

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
            'CREATE INDEX IF NOT EXISTS note_tags_tag_idx ON note_tags (tag_id, note_id);',
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

        return titleOrContentMatch | existsQuery(tagSubQuery);
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
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Permanent hard deletion of a single note (cascades note_tags via foreign key)
  Future<void> deletePermanently(String noteId) async {
    await transaction(() async {
      await (delete(noteTagsTable)..where((nt) => nt.noteId.equals(noteId))).go();
      await (delete(notesTable)..where((n) => n.id.equals(noteId))).go();
      await _cleanupOrphanedTags();
    });
  }

  /// Empty all notes currently in Trash
  Future<void> emptyTrash() async {
    await transaction(() async {
      final trashedNotes = await (select(notesTable)
            ..where((n) => n.isTrashed.equals(true)))
          .get();
      final trashedIds = trashedNotes.map((n) => n.id).toList();

      if (trashedIds.isNotEmpty) {
        await (delete(noteTagsTable)..where((nt) => nt.noteId.isIn(trashedIds))).go();
        await (delete(notesTable)..where((n) => n.id.isIn(trashedIds))).go();
        await _cleanupOrphanedTags();
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
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Batch permanent deletion
  Future<void> deletePermanentlyBatch(List<String> noteIds) async {
    if (noteIds.isEmpty) return;
    await transaction(() async {
      await (delete(noteTagsTable)..where((nt) => nt.noteId.isIn(noteIds))).go();
      await (delete(notesTable)..where((n) => n.id.isIn(noteIds))).go();
      await _cleanupOrphanedTags();
    });
  }

  /// Legacy helper for deleting a note (can route to deletePermanently or trashNote)
  Future<void> deleteNote(String noteId) async {
    await deletePermanently(noteId);
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

    // Only count active notes in tags
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

    // Clear existing relations
    await (delete(noteTagsTable)..where((nt) => nt.noteId.equals(noteId))).go();

    if (normalized.isEmpty) {
      await _cleanupOrphanedTags();
      return;
    }

    for (final tagName in normalized) {
      // Find or create tag
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

      // Link note to tag
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
}
