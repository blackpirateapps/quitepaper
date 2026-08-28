import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/tag_parser.dart';
import '../domain/note_model.dart';
import '../domain/notes_cursor.dart';
import '../domain/notes_filter.dart';
import '../domain/notes_query.dart';
import '../domain/notes_sort.dart';

/// Result envelope containing loaded notes, next cursor, total matching count, and generation
class NotesQueryResult {
  const NotesQueryResult({
    required this.notes,
    required this.nextCursor,
    required this.hasMore,
    required this.totalCount,
    required this.generation,
  });

  final List<Note> notes;
  final NotesCursor? nextCursor;
  final bool hasMore;
  final int totalCount;
  final int generation;

  static const empty = NotesQueryResult(
    notes: [],
    nextCursor: null,
    hasMore: false,
    totalCount: 0,
    generation: 0,
  );
}

/// Executes database-level structured queries with deterministic keyset pagination
class NotesQueryExecutor {
  const NotesQueryExecutor(this._db);

  final AppDatabase _db;

  /// Executes query against local Drift SQLite database using keyset cursor pagination
  Future<NotesQueryResult> execute(NotesQuery query) async {
    final wherePredicate = _buildWherePredicate(query);

    // 1. Get total matching count
    final countExp = _db.notesTable.id.count();
    final countQuery = _db.selectOnly(_db.notesTable)
      ..where(wherePredicate)
      ..addColumns([countExp]);
    final countRow = await countQuery.getSingleOrNull();
    final totalCount = countRow?.read(countExp) ?? 0;

    if (totalCount == 0) {
      return NotesQueryResult(
        notes: const [],
        nextCursor: null,
        hasMore: false,
        totalCount: 0,
        generation: query.generation,
      );
    }

    // 2. Build keyset cursor predicate
    Expression<bool> fullPredicate = wherePredicate;
    if (query.cursor != null) {
      final cursorPredicate = _buildCursorPredicate(query.sort, query.cursor!, query.context);
      fullPredicate = fullPredicate & cursorPredicate;
    }

    // 3. Build ordered query
    final selectQuery = _db.select(_db.notesTable)
      ..where((_) => fullPredicate)
      ..orderBy(_buildOrderingTerms(query.sort, query.context))
      ..limit(query.limit);

    final noteEntities = await selectQuery.get();

    if (noteEntities.isEmpty) {
      return NotesQueryResult(
        notes: const [],
        nextCursor: null,
        hasMore: false,
        totalCount: totalCount,
        generation: query.generation,
      );
    }

    // 4. Batch-hydrate tags for all returned notes (prevents N+1 queries)
    final noteIds = noteEntities.map((e) => e.id).toList();
    final tagsMap = await _db.getTagsForNoteIds(noteIds);

    final notes = noteEntities.map((e) {
      final tagEntities = tagsMap[e.id] ?? const [];
      return Note(
        id: e.id,
        title: e.title,
        content: e.content,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        isPinned: e.isPinned,
        isArchived: e.isArchived,
        isTrashed: e.isTrashed,
        deletedAt: e.deletedAt,
        tags: tagEntities.map((t) => t.name).toList(),
      );
    }).toList();

    final hasMore = noteEntities.length == query.limit;
    final nextCursor = hasMore && notes.isNotEmpty
        ? NotesCursor.fromNote(notes.last, query.sort)
        : null;

    return NotesQueryResult(
      notes: notes,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: totalCount,
      generation: query.generation,
    );
  }

  /// Builds base WHERE predicates matching the filter without cursor or limits
  Expression<bool> _buildWherePredicate(NotesQuery query) {
    Expression<bool> predicate = const Constant(true);

    // 1. Context lifecycle constraint
    switch (query.context) {
      case NotesContext.active:
        predicate = predicate &
            _db.notesTable.isArchived.equals(false) &
            _db.notesTable.isTrashed.equals(false);
        break;
      case NotesContext.archive:
        predicate = predicate &
            _db.notesTable.isArchived.equals(true) &
            _db.notesTable.isTrashed.equals(false);
        break;
      case NotesContext.trash:
        predicate = predicate & _db.notesTable.isTrashed.equals(true);
        break;
    }

    // 2. Pinned predicate
    if (query.filter.pinnedOnly) {
      predicate = predicate & _db.notesTable.isPinned.equals(true);
    }

    // 3. Untagged predicate
    if (query.filter.untaggedOnly) {
      final untaggedSub = _db.selectOnly(_db.noteTagsTable)
        ..addColumns([_db.noteTagsTable.noteId])
        ..where(_db.noteTagsTable.noteId.equalsExp(_db.notesTable.id));
      predicate = predicate & notExistsQuery(untaggedSub);
    }

    // 4. Tags with match mode (All vs Any)
    if (query.filter.tags.isNotEmpty) {
      final normalizedTags = query.filter.tags
          .map(TagParser.normalizeTag)
          .where(TagParser.isValidTag)
          .toList();

      if (normalizedTags.isNotEmpty) {
        if (query.filter.tagMatchMode == TagMatchMode.all) {
          // AND mode: Note must have EVERY selected tag
          for (final tag in normalizedTags) {
            final tagSub = _db.selectOnly(_db.noteTagsTable)
              ..join([
                innerJoin(
                  _db.tagsTable,
                  _db.tagsTable.id.equalsExp(_db.noteTagsTable.tagId),
                ),
              ])
              ..addColumns([_db.noteTagsTable.noteId])
              ..where(
                _db.tagsTable.name.equals(tag) &
                    _db.noteTagsTable.noteId.equalsExp(_db.notesTable.id),
              );
            predicate = predicate & existsQuery(tagSub);
          }
        } else {
          // OR mode: Note must have AT LEAST ONE selected tag
          final tagSub = _db.selectOnly(_db.noteTagsTable)
            ..join([
              innerJoin(
                _db.tagsTable,
                _db.tagsTable.id.equalsExp(_db.noteTagsTable.tagId),
              ),
            ])
            ..addColumns([_db.noteTagsTable.noteId])
            ..where(
              _db.tagsTable.name.isIn(normalizedTags) &
                  _db.noteTagsTable.noteId.equalsExp(_db.notesTable.id),
            );
          predicate = predicate & existsQuery(tagSub);
        }
      }
    }

    // 5. Date filters (Created / Modified) using half-open intervals [start, endExclusive)
    if (query.filter.createdRange != null) {
      final bounds = query.filter.createdRange!.getBounds();
      predicate = predicate &
          _db.notesTable.createdAt.isBiggerOrEqualValue(bounds.start) &
          _db.notesTable.createdAt.isSmallerThanValue(bounds.endExclusive);
    }

    if (query.filter.modifiedRange != null) {
      final bounds = query.filter.modifiedRange!.getBounds();
      predicate = predicate &
          _db.notesTable.updatedAt.isBiggerOrEqualValue(bounds.start) &
          _db.notesTable.updatedAt.isSmallerThanValue(bounds.endExclusive);
    }

    // 6. Content-derived predicates
    for (final contentFilter in query.filter.contentFilters) {
      switch (contentFilter) {
        case ContentFilter.hasCode:
          predicate = predicate &
              (_db.notesTable.content.like('%```%') |
                  _db.notesTable.content.like('%`%'));
          break;
        case ContentFilter.hasChecklist:
          predicate = predicate &
              (_db.notesTable.content.like('%- [ ]%') |
                  _db.notesTable.content.like('%- [x]%') |
                  _db.notesTable.content.like('%- [X]%'));
          break;
        case ContentFilter.hasIncompleteTasks:
          predicate = predicate & _db.notesTable.content.like('%- [ ]%');
          break;
        case ContentFilter.hasCompletedTasks:
          predicate = predicate &
              (_db.notesTable.content.like('%- [x]%') |
                  _db.notesTable.content.like('%- [X]%'));
          break;
        case ContentFilter.hasLinks:
          predicate = predicate &
              (_db.notesTable.content.like('%http://%') |
                  _db.notesTable.content.like('%https://%') |
                  _db.notesTable.content.like('%qp://%') |
                  _db.notesTable.content.like('%](%'));
          break;
      }
    }

    // 7. Attachment & media relationship predicates
    for (final attachmentFilter in query.filter.attachmentFilters) {
      switch (attachmentFilter) {
        case AttachmentFilter.hasAttachments:
          final attSub = _db.selectOnly(_db.attachmentsTable)
            ..addColumns([_db.attachmentsTable.noteId])
            ..where(
              _db.attachmentsTable.noteId.equalsExp(_db.notesTable.id) &
                  _db.attachmentsTable.isDeleted.equals(false),
            );
          predicate = predicate & existsQuery(attSub);
          break;
        case AttachmentFilter.hasImages:
          final imgSub = _db.selectOnly(_db.attachmentsTable)
            ..addColumns([_db.attachmentsTable.noteId])
            ..where(
              _db.attachmentsTable.noteId.equalsExp(_db.notesTable.id) &
                  _db.attachmentsTable.isDeleted.equals(false) &
                  _db.attachmentsTable.mimeType.like('image/%'),
            );
          predicate = predicate & existsQuery(imgSub);
          break;
        case AttachmentFilter.hasDocuments:
          final docSub = _db.selectOnly(_db.documentsTable)
            ..addColumns([_db.documentsTable.noteId])
            ..where(
              _db.documentsTable.noteId.equalsExp(_db.notesTable.id) &
                  _db.documentsTable.isDeleted.equals(false),
            );
          predicate = predicate & existsQuery(docSub);
          break;
        case AttachmentFilter.hasOcr:
          final ocrAttSub = _db.selectOnly(_db.attachmentsTable)
            ..addColumns([_db.attachmentsTable.noteId])
            ..where(
              _db.attachmentsTable.noteId.equalsExp(_db.notesTable.id) &
                  _db.attachmentsTable.isDeleted.equals(false) &
                  _db.attachmentsTable.ocrState.equals('available'),
            );
          final ocrDocSub = _db.selectOnly(_db.documentsTable)
            ..addColumns([_db.documentsTable.noteId])
            ..where(
              _db.documentsTable.noteId.equalsExp(_db.notesTable.id) &
                  _db.documentsTable.isDeleted.equals(false) &
                  _db.documentsTable.ocrState.equals('available'),
            );
          predicate = predicate & (existsQuery(ocrAttSub) | existsQuery(ocrDocSub));
          break;
      }
    }

    // 8. Security filter
    switch (query.filter.securityFilter) {
      case SecurityFilter.protectedOnly:
        predicate = predicate &
            _db.notesTable.content.like('<!-- quiet-paper-encrypted-note-v1:%');
        break;
      case SecurityFilter.unprotectedOnly:
        predicate = predicate &
            _db.notesTable.content.like('<!-- quiet-paper-encrypted-note-v1:%').not();
        break;
      case SecurityFilter.all:
        break;
    }

    // 9. Optional search query integration
    if (query.searchQuery != null && query.searchQuery!.trim().isNotEmpty) {
      final clean = query.searchQuery!.trim().toLowerCase();
      final pattern = '%$clean%';
      final tagMatch = TagParser.normalizeTag(clean);

      final tagSub = _db.selectOnly(_db.noteTagsTable)
        ..join([
          innerJoin(
            _db.tagsTable,
            _db.tagsTable.id.equalsExp(_db.noteTagsTable.tagId),
          ),
        ])
        ..addColumns([_db.noteTagsTable.noteId])
        ..where(
          _db.tagsTable.name.lower().like('%$tagMatch%') &
              _db.noteTagsTable.noteId.equalsExp(_db.notesTable.id),
        );

      final docSub = _db.selectOnly(_db.documentsTable)
        ..addColumns([_db.documentsTable.noteId])
        ..where(
          _db.documentsTable.noteId.equalsExp(_db.notesTable.id) &
              _db.documentsTable.isDeleted.equals(false) &
              _db.documentsTable.title.lower().like(pattern),
        );

      predicate = predicate &
          (_db.notesTable.title.lower().like(pattern) |
              _db.notesTable.content.lower().like(pattern) |
              existsQuery(tagSub) |
              existsQuery(docSub));
    }

    return predicate;
  }

  /// Builds ordering clauses for deterministic sorting
  List<OrderingTerm Function($NotesTableTable)> _buildOrderingTerms(
    NotesSort sort,
    NotesContext context,
  ) {
    if (context == NotesContext.trash) {
      return [
        (n) => OrderingTerm(expression: n.deletedAt, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.id, mode: OrderingMode.asc),
      ];
    }

    final terms = <OrderingTerm Function($NotesTableTable)>[];

    // 1. Pinned first in active context
    if (sort.pinnedFirst && context == NotesContext.active) {
      terms.add((n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc));
    }

    // 2. Primary sort field
    final orderMode = sort.direction == SortDirection.descending
        ? OrderingMode.desc
        : OrderingMode.asc;

    switch (sort.field) {
      case SortField.updated:
        terms.add((n) => OrderingTerm(expression: n.updatedAt, mode: orderMode));
        break;
      case SortField.created:
        terms.add((n) => OrderingTerm(expression: n.createdAt, mode: orderMode));
        break;
      case SortField.title:
        terms.add(
          (n) => OrderingTerm(
            expression: n.title.collate(Collate.noCase),
            mode: orderMode,
          ),
        );
        // Secondary sort for identical titles: updated_at DESC
        terms.add((n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc));
        break;
    }

    // 3. Final unique ID tie-breaker for 100% deterministic results
    terms.add((n) => OrderingTerm(expression: n.id, mode: OrderingMode.asc));

    return terms;
  }

  /// Builds keyset cursor expression for continuation
  Expression<bool> _buildCursorPredicate(
    NotesSort sort,
    NotesCursor cursor,
    NotesContext context,
  ) {
    final sortCondition = _buildSortFieldCursorPredicate(sort, cursor);

    if (sort.pinnedFirst && context == NotesContext.active && cursor.lastIsPinned != null) {
      if (cursor.lastIsPinned == true) {
        // Cursor is in pinned partition: next can be unpinned OR (pinned with sort condition)
        return _db.notesTable.isPinned.equals(false) |
            (_db.notesTable.isPinned.equals(true) & sortCondition);
      } else {
        // Cursor is in unpinned partition: next must be unpinned with sort condition
        return _db.notesTable.isPinned.equals(false) & sortCondition;
      }
    }

    return sortCondition;
  }

  /// Builds keyset continuation predicate for the primary sort field
  Expression<bool> _buildSortFieldCursorPredicate(
    NotesSort sort,
    NotesCursor cursor,
  ) {
    final isDesc = sort.direction == SortDirection.descending;
    final cId = cursor.lastNoteId;

    switch (sort.field) {
      case SortField.updated:
        final cUpdated = cursor.lastUpdatedAt ?? DateTime.now();
        if (isDesc) {
          return (_db.notesTable.updatedAt.isSmallerThanValue(cUpdated)) |
              (_db.notesTable.updatedAt.equals(cUpdated) &
                  _db.notesTable.id.isBiggerThanValue(cId));
        } else {
          return (_db.notesTable.updatedAt.isBiggerThanValue(cUpdated)) |
              (_db.notesTable.updatedAt.equals(cUpdated) &
                  _db.notesTable.id.isBiggerThanValue(cId));
        }

      case SortField.created:
        final cCreated = cursor.lastCreatedAt ?? DateTime.now();
        if (isDesc) {
          return (_db.notesTable.createdAt.isSmallerThanValue(cCreated)) |
              (_db.notesTable.createdAt.equals(cCreated) &
                  _db.notesTable.id.isBiggerThanValue(cId));
        } else {
          return (_db.notesTable.createdAt.isBiggerThanValue(cCreated)) |
              (_db.notesTable.createdAt.equals(cCreated) &
                  _db.notesTable.id.isBiggerThanValue(cId));
        }

      case SortField.title:
        final cTitle = cursor.lastTitle ?? '';
        final cUpdated = cursor.lastUpdatedAt ?? DateTime.now();
        final titleLower = _db.notesTable.title.lower();

        final tieBreaker = (_db.notesTable.updatedAt.isSmallerThanValue(cUpdated)) |
            (_db.notesTable.updatedAt.equals(cUpdated) &
                _db.notesTable.id.isBiggerThanValue(cId));

        if (isDesc) {
          return (titleLower.isSmallerThanValue(cTitle)) |
              (titleLower.equals(cTitle) & tieBreaker);
        } else {
          return (titleLower.isBiggerThanValue(cTitle)) |
              (titleLower.equals(cTitle) & tieBreaker);
        }
    }
  }
}
