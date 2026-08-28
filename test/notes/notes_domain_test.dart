import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_cursor.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/notes/domain/saved_filter.dart';

void main() {
  group('NotesSort', () {
    test('default configuration is Recently Updated descending with pinnedFirst', () {
      const sort = NotesSort.defaultSort;
      expect(sort.field, SortField.updated);
      expect(sort.direction, SortDirection.descending);
      expect(sort.pinnedFirst, true);
    });

    test('serializes to and from JSON correctly', () {
      const sort = NotesSort(
        field: SortField.title,
        direction: SortDirection.ascending,
        pinnedFirst: false,
      );

      final json = sort.toJson();
      expect(json['field'], 'title');
      expect(json['direction'], 'asc');
      expect(json['pinnedFirst'], false);

      final restored = NotesSort.fromJson(json);
      expect(restored, equals(sort));
    });

    test('display names adapt to sort field and direction', () {
      expect(SortField.updated.displayName, 'Recently Updated');
      expect(SortField.created.displayName, 'Recently Created');
      expect(SortField.title.displayName, 'Title');

      expect(SortDirection.descending.getDisplayName(SortField.updated), 'Newest First');
      expect(SortDirection.ascending.getDisplayName(SortField.updated), 'Oldest First');
      expect(SortDirection.ascending.getDisplayName(SortField.title), 'A → Z');
      expect(SortDirection.descending.getDisplayName(SortField.title), 'Z → A');
    });
  });

  group('DateFilterRange & Boundaries', () {
    final now = DateTime(2026, 8, 28, 14, 30, 0);

    test('calculates half-open boundaries for Today', () {
      const range = DateFilterRange(type: DateFilterType.today);
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 8, 28, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2026, 8, 29, 0, 0, 0));
    });

    test('calculates half-open boundaries for Yesterday', () {
      const range = DateFilterRange(type: DateFilterType.yesterday);
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 8, 27, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2026, 8, 28, 0, 0, 0));
    });

    test('calculates half-open boundaries for Last 7 Days', () {
      const range = DateFilterRange(type: DateFilterType.last7Days);
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 8, 22, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2026, 8, 29, 0, 0, 0));
    });

    test('calculates half-open boundaries for Last 30 Days', () {
      const range = DateFilterRange(type: DateFilterType.last30Days);
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 7, 30, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2026, 8, 29, 0, 0, 0));
    });

    test('calculates half-open boundaries for This Year', () {
      const range = DateFilterRange(type: DateFilterType.thisYear);
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 1, 1, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2027, 1, 1, 0, 0, 0));
    });

    test('calculates half-open boundaries for Custom Range', () {
      final from = DateTime(2026, 3, 10);
      final to = DateTime(2026, 3, 15);
      final range = DateFilterRange(
        type: DateFilterType.custom,
        customFrom: from,
        customTo: to,
      );
      final bounds = range.getBounds(now);

      expect(bounds.start, DateTime(2026, 3, 10, 0, 0, 0));
      expect(bounds.endExclusive, DateTime(2026, 3, 16, 0, 0, 0));
    });
  });

  group('NotesFilter', () {
    test('empty filter reports isEmpty true and activeFilterCount 0', () {
      const filter = NotesFilter.empty;
      expect(filter.isEmpty, true);
      expect(filter.hasAdvancedFilters, false);
      expect(filter.activeFilterCount, 0);
    });

    test('activeFilterCount aggregates all configured predicates accurately', () {
      final filter = NotesFilter(
        tags: const {'work', 'ideas'},
        tagMatchMode: TagMatchMode.all,
        pinnedOnly: true,
        contentFilters: const {ContentFilter.hasCode, ContentFilter.hasChecklist},
        attachmentFilters: const {AttachmentFilter.hasImages},
        securityFilter: SecurityFilter.protectedOnly,
        createdRange: const DateFilterRange(type: DateFilterType.last7Days),
      );

      expect(filter.isEmpty, false);
      expect(filter.hasAdvancedFilters, true);
      // 2 tags + 1 pinned + 2 content + 1 attachment + 1 security + 1 createdRange = 8
      expect(filter.activeFilterCount, 8);
    });

    test('clearAdvancedFilters resets predicates while optionally preserving tags', () {
      final filter = NotesFilter(
        tags: const {'design'},
        pinnedOnly: true,
        contentFilters: const {ContentFilter.hasLinks},
      );

      final clearedKeepTags = filter.clearAdvancedFilters(keepTags: true);
      expect(clearedKeepTags.tags, const {'design'});
      expect(clearedKeepTags.pinnedOnly, false);
      expect(clearedKeepTags.contentFilters, isEmpty);

      final clearedAll = filter.clearAdvancedFilters(keepTags: false);
      expect(clearedAll.tags, isEmpty);
    });

    test('serializes to and from JSON', () {
      final filter = NotesFilter(
        tags: const {'swift', 'flutter'},
        tagMatchMode: TagMatchMode.any,
        untaggedOnly: false,
        pinnedOnly: true,
        createdRange: const DateFilterRange(type: DateFilterType.last30Days),
        contentFilters: const {ContentFilter.hasCode},
        attachmentFilters: const {AttachmentFilter.hasDocuments, AttachmentFilter.hasOcr},
        securityFilter: SecurityFilter.unprotectedOnly,
      );

      final json = filter.toJson();
      final restored = NotesFilter.fromJson(json);

      expect(restored, equals(filter));
    });
  });

  group('NotesCursor', () {
    test('extracts deterministic keys from Note', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);
      final note = Note(
        id: 'note-uuid-1',
        title: ' My Note Title ',
        content: 'Content',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
        isPinned: true,
      );

      final cursor = NotesCursor.fromNote(note, NotesSort.defaultSort);
      expect(cursor.lastNoteId, 'note-uuid-1');
      expect(cursor.lastUpdatedAt, now);
      expect(cursor.lastCreatedAt, now.subtract(const Duration(days: 1)));
      expect(cursor.lastTitle, 'my note title');
      expect(cursor.lastIsPinned, true);
    });

    test('serializes to and from JSON', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);
      final cursor = NotesCursor(
        lastNoteId: 'test-id',
        lastUpdatedAt: now,
        lastCreatedAt: now,
        lastTitle: 'test title',
        lastIsPinned: false,
      );

      final json = cursor.toJson();
      final restored = NotesCursor.fromJson(json);

      expect(restored, equals(cursor));
    });
  });

  group('NotesQuery', () {
    test('default query initializes with active context and generation 0', () {
      const query = NotesQuery.defaultQuery;
      expect(query.context, NotesContext.active);
      expect(query.filter.isEmpty, true);
      expect(query.sort, NotesSort.defaultSort);
      expect(query.limit, 40);
      expect(query.generation, 0);
    });

    test('resetPagination clears cursor and increments generation', () {
      final query = const NotesQuery(
        cursor: NotesCursor(lastNoteId: 'prev-id'),
        generation: 3,
      );

      final reset = query.resetPagination();
      expect(reset.cursor, isNull);
      expect(reset.generation, 4);
    });

    test('nextPage updates cursor while preserving generation', () {
      final query = const NotesQuery(generation: 2);
      const nextCursor = NotesCursor(lastNoteId: 'next-id');

      final advanced = query.nextPage(nextCursor);
      expect(advanced.cursor, nextCursor);
      expect(advanced.generation, 2);
    });

    test('serializes to and from JSON with version 1', () {
      final query = NotesQuery(
        context: NotesContext.archive,
        filter: const NotesFilter(pinnedOnly: true),
        sort: const NotesSort(field: SortField.created, direction: SortDirection.ascending),
        searchQuery: 'architecture',
        limit: 50,
      );

      final json = query.toJson();
      expect(json['version'], 1);
      expect(json['context'], 'archive');
      expect(json['searchQuery'], 'architecture');
      expect(json['limit'], 50);

      final restored = NotesQuery.fromJson(json);
      expect(restored.context, NotesContext.archive);
      expect(restored.filter.pinnedOnly, true);
      expect(restored.sort.field, SortField.created);
      expect(restored.sort.direction, SortDirection.ascending);
      expect(restored.searchQuery, 'architecture');
      expect(restored.limit, 50);
    });
  });

  group('SavedFilter', () {
    test('serializes to and from JSON', () {
      final now = DateTime(2026, 8, 28, 10, 0, 0);
      final saved = SavedFilter(
        id: 'smart-view-1',
        name: 'Work Tasks',
        query: const NotesQuery(
          filter: NotesFilter(
            tags: {'work'},
            contentFilters: {ContentFilter.hasIncompleteTasks},
          ),
        ),
        createdAt: now,
        updatedAt: now,
      );

      final json = saved.toJson();
      expect(json['id'], 'smart-view-1');
      expect(json['name'], 'Work Tasks');

      final restored = SavedFilter.fromJson(json);
      expect(restored.id, saved.id);
      expect(restored.name, saved.name);
      expect(restored.query.filter.tags, const {'work'});
      expect(restored.query.filter.contentFilters, const {ContentFilter.hasIncompleteTasks});
    });
  });
}
