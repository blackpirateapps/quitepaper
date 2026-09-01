import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../settings/application/settings_provider.dart';
import '../data/notes_repository.dart';
import '../domain/note_group.dart';
import '../domain/note_model.dart';
import '../domain/notes_cursor.dart';
import '../domain/notes_filter.dart';
import '../domain/notes_query.dart';
import '../domain/notes_sort.dart';
import 'notes_provider.dart';

// ==========================================
// SORT PREFERENCES PERSISTENCE
// ==========================================

const String _prefSortFieldKey = 'notes_sort_field';
const String _prefSortDirectionKey = 'notes_sort_direction';
const String _prefSortPinnedFirstKey = 'notes_sort_pinned_first';

final notesSortPreferenceProvider =
    StateNotifierProvider<NotesSortPreferenceNotifier, NotesSort>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotesSortPreferenceNotifier(prefs);
});

class NotesSortPreferenceNotifier extends StateNotifier<NotesSort> {
  NotesSortPreferenceNotifier(this._prefs) : super(_loadSort(_prefs));

  final SharedPreferences _prefs;

  static NotesSort _loadSort(SharedPreferences prefs) {
    final fieldStr = prefs.getString(_prefSortFieldKey);
    final dirStr = prefs.getString(_prefSortDirectionKey);
    final pinnedFirst = prefs.getBool(_prefSortPinnedFirstKey) ?? true;

    return NotesSort(
      field: SortField.fromString(fieldStr),
      direction: SortDirection.fromString(dirStr),
      pinnedFirst: pinnedFirst,
    );
  }

  Future<void> updateSort(NotesSort sort) async {
    state = sort;
    await _prefs.setString(_prefSortFieldKey, sort.field.name);
    await _prefs.setString(
      _prefSortDirectionKey,
      sort.direction == SortDirection.ascending ? 'asc' : 'desc',
    );
    await _prefs.setBool(_prefSortPinnedFirstKey, sort.pinnedFirst);
  }
}

// ==========================================
// NOTES QUERY STATE NOTIFIER
// ==========================================

final notesQueryProvider =
    StateNotifierProvider<NotesQueryNotifier, NotesQuery>((ref) {
  final initialSort = ref.read(notesSortPreferenceProvider);
  final destination = ref.read(currentDestinationProvider);
  final tagFilter = ref.read(selectedTagFilterProvider);

  NotesContext context = NotesContext.active;
  bool pinnedOnly = false;

  switch (destination) {
    case AppDestination.allNotes:
      context = NotesContext.active;
      break;
    case AppDestination.pinned:
      context = NotesContext.active;
      pinnedOnly = true;
      break;
    case AppDestination.archive:
      context = NotesContext.archive;
      break;
    case AppDestination.trash:
      context = NotesContext.trash;
      break;
    case AppDestination.tag:
      context = NotesContext.active;
      break;
    case AppDestination.tagBrowser:
    case AppDestination.allJournalEntries:
    case AppDestination.onThisDay:
      context = NotesContext.active;
      break;
  }

  final initialQuery = NotesQuery(
    context: context,
    sort: initialSort,
    filter: NotesFilter(
      tags: tagFilter != null && tagFilter.isNotEmpty ? {tagFilter} : const {},
      pinnedOnly: pinnedOnly,
    ),
    generation: 1,
  );

  return NotesQueryNotifier(ref, initialQuery);
});

class NotesQueryNotifier extends StateNotifier<NotesQuery> {
  NotesQueryNotifier(this._ref, super.initial) {
    // Synchronize navigation changes
    _ref.listen<AppDestination>(currentDestinationProvider, (prev, next) {
      if (prev != next) {
        _onDestinationChanged(next);
      }
    });

    // Synchronize single tag selection changes
    _ref.listen<String?>(selectedTagFilterProvider, (prev, next) {
      if (prev != next) {
        _onTagFilterChanged(next);
      }
    });
  }

  final Ref _ref;

  void _onDestinationChanged(AppDestination destination) {
    NotesContext newContext = NotesContext.active;
    bool pinnedOnly = false;

    switch (destination) {
      case AppDestination.allNotes:
        newContext = NotesContext.active;
        break;
      case AppDestination.pinned:
        newContext = NotesContext.active;
        pinnedOnly = true;
        break;
      case AppDestination.archive:
        newContext = NotesContext.archive;
        break;
      case AppDestination.trash:
        newContext = NotesContext.trash;
        break;
      case AppDestination.tag:
      case AppDestination.tagBrowser:
      case AppDestination.allJournalEntries:
      case AppDestination.onThisDay:
        newContext = NotesContext.active;
        break;
    }

    state = state
        .copyWith(
          context: newContext,
          filter: state.filter.copyWith(pinnedOnly: pinnedOnly),
        )
        .resetPagination();
  }

  void _onTagFilterChanged(String? tag) {
    final newTags = tag != null && tag.isNotEmpty ? {tag} : <String>{};
    if (state.filter.tags != newTags) {
      state = state
          .copyWith(
            filter: state.filter.copyWith(tags: newTags),
          )
          .resetPagination();
    }
  }

  void setSort(NotesSort sort) {
    _ref.read(notesSortPreferenceProvider.notifier).updateSort(sort);
    state = state.copyWith(sort: sort).resetPagination();
  }

  void setFilters(NotesFilter filter) {
    if (filter.tags.length == 1) {
      _ref.read(selectedTagFilterProvider.notifier).state = filter.tags.first;
    } else if (filter.tags.isEmpty) {
      _ref.read(selectedTagFilterProvider.notifier).state = null;
    }
    state = state.copyWith(filter: filter).resetPagination();
  }

  void setContext(NotesContext context) {
    state = state.copyWith(context: context).resetPagination();
  }

  void setTag(String? tag) {
    final currentTags = tag != null && tag.isNotEmpty ? {tag} : <String>{};
    state = state
        .copyWith(
          filter: state.filter.copyWith(tags: currentTags),
        )
        .resetPagination();
  }

  void setSearchQuery(String? search) {
    state = state
        .copyWith(
          searchQuery: search,
          clearSearchQuery: search == null || search.trim().isEmpty,
        )
        .resetPagination();
  }

  void clearAdvancedFilters({bool keepTags = true}) {
    state = state
        .copyWith(
          filter: state.filter.clearAdvancedFilters(keepTags: keepTags),
        )
        .resetPagination();
  }

  void clearAllFilters() {
    _ref.read(selectedTagFilterProvider.notifier).state = null;
    state = state
        .copyWith(
          filter: NotesFilter.empty,
        )
        .resetPagination();
  }

  void removeFilterTag(String tag) {
    final newTags = Set<String>.of(state.filter.tags)..remove(tag);
    if (newTags.isEmpty) {
      _ref.read(selectedTagFilterProvider.notifier).state = null;
    } else if (newTags.length == 1) {
      _ref.read(selectedTagFilterProvider.notifier).state = newTags.first;
    }
    state = state
        .copyWith(
          filter: state.filter.copyWith(tags: newTags),
        )
        .resetPagination();
  }

  void toggleContentFilter(ContentFilter filter) {
    final newFilters = Set<ContentFilter>.of(state.filter.contentFilters);
    if (newFilters.contains(filter)) {
      newFilters.remove(filter);
    } else {
      newFilters.add(filter);
    }
    state = state
        .copyWith(
          filter: state.filter.copyWith(contentFilters: newFilters),
        )
        .resetPagination();
  }

  void toggleAttachmentFilter(AttachmentFilter filter) {
    final newFilters = Set<AttachmentFilter>.of(state.filter.attachmentFilters);
    if (newFilters.contains(filter)) {
      newFilters.remove(filter);
    } else {
      newFilters.add(filter);
    }
    state = state
        .copyWith(
          filter: state.filter.copyWith(attachmentFilters: newFilters),
        )
        .resetPagination();
  }

  void setCreatedRange(DateFilterRange? range) {
    state = state
        .copyWith(
          filter: state.filter.copyWith(
            createdRange: range,
            clearCreatedRange: range == null,
          ),
        )
        .resetPagination();
  }

  void setModifiedRange(DateFilterRange? range) {
    state = state
        .copyWith(
          filter: state.filter.copyWith(
            modifiedRange: range,
            clearModifiedRange: range == null,
          ),
        )
        .resetPagination();
  }
}

// ==========================================
// PAGINATED NOTES COLLECTION STATE
// ==========================================

class NotesCollectionState {
  const NotesCollectionState({
    required this.notes,
    required this.query,
    this.initialLoading = true,
    this.loadingMore = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.cursor,
    this.error,
    this.totalCount = 0,
    this.generation = 0,
  });

  final List<Note> notes;
  final NotesQuery query;
  final bool initialLoading;
  final bool loadingMore;
  final bool isRefreshing;
  final bool hasMore;
  final NotesCursor? cursor;
  final Object? error;
  final int totalCount;
  final int generation;

  NotesCollectionState copyWith({
    List<Note>? notes,
    NotesQuery? query,
    bool? initialLoading,
    bool? loadingMore,
    bool? isRefreshing,
    bool? hasMore,
    NotesCursor? cursor,
    bool clearCursor = false,
    Object? error,
    bool clearError = false,
    int? totalCount,
    int? generation,
  }) {
    return NotesCollectionState(
      notes: notes ?? this.notes,
      query: query ?? this.query,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
      generation: generation ?? this.generation,
    );
  }
}

// ==========================================
// PAGINATED NOTES COLLECTION NOTIFIER
// ==========================================

final notesCollectionProvider =
    StateNotifierProvider<NotesCollectionNotifier, NotesCollectionState>((ref) {
  final db = ref.watch(databaseProvider);
  final repository = ref.watch(notesRepositoryProvider);
  return NotesCollectionNotifier(ref, db, repository);
});

class NotesCollectionNotifier extends StateNotifier<NotesCollectionState> {
  NotesCollectionNotifier(this._ref, this._db, this._repository)
      : super(
          NotesCollectionState(
            notes: const [],
            query: _ref.read(notesQueryProvider),
            initialLoading: true,
            generation: _ref.read(notesQueryProvider).generation,
          ),
        ) {
    _loadInitial(state.query);
    _ref.listen<NotesQuery>(notesQueryProvider, (prev, next) {
      if (prev != next) {
        _loadInitial(next);
      }
    });

    _tableSubscription = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.notesTable,
        _db.noteTagsTable,
        _db.attachmentsTable,
        _db.documentsTable,
      ]),
    ).listen((_) {
      refresh();
    });
  }

  final Ref _ref;
  final AppDatabase _db;
  final NotesRepository _repository;
  StreamSubscription? _tableSubscription;
  int _activeGeneration = 0;

  @override
  void dispose() {
    _tableSubscription?.cancel();
    super.dispose();
  }

  /// Loads the first batch for a new query
  Future<void> _loadInitial(NotesQuery query) async {
    final gen = query.generation;
    _activeGeneration = gen;

    state = state.copyWith(
      query: query,
      initialLoading: true,
      clearError: true,
      generation: gen,
      clearCursor: true,
      hasMore: true,
    );

    try {
      final result = await _repository.executeNotesQuery(query);

      // Race protection: ignore stale responses
      if (_activeGeneration != gen) return;

      state = state.copyWith(
        notes: result.notes,
        cursor: result.nextCursor,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        initialLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (e) {
      if (_activeGeneration != gen) return;
      state = state.copyWith(
        initialLoading: false,
        isRefreshing: false,
        error: e,
      );
    }
  }

  /// Loads subsequent batch using current keyset cursor
  Future<void> loadMore() async {
    // Load-more lock: ensure only one active load-more per generation
    if (state.loadingMore || !state.hasMore || state.initialLoading || state.cursor == null) {
      return;
    }

    final gen = state.generation;
    state = state.copyWith(loadingMore: true, clearError: true);

    try {
      final nextPageQuery = state.query.copyWith(
        cursor: state.cursor,
      );

      final result = await _repository.executeNotesQuery(nextPageQuery);

      if (_activeGeneration != gen) return;

      if (result.notes.isEmpty) {
        state = state.copyWith(
          loadingMore: false,
          hasMore: false,
          clearCursor: true,
        );
        return;
      }

      // Deduplicate new batch against existing note IDs
      final existingIds = state.notes.map((n) => n.id).toSet();
      final uniqueNewNotes = result.notes.where((n) => !existingIds.contains(n.id)).toList();

      final combined = List<Note>.of(state.notes)..addAll(uniqueNewNotes);

      state = state.copyWith(
        notes: combined,
        cursor: result.nextCursor,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        loadingMore: false,
        clearError: true,
      );
    } catch (e) {
      if (_activeGeneration != gen) return;
      // Failed load-more keeps existing loaded notes intact!
      state = state.copyWith(
        loadingMore: false,
        error: e,
      );
    }
  }

  /// Refreshes current query from the beginning without losing active filter/sort
  Future<void> refresh() async {
    final gen = state.generation + 1;
    _activeGeneration = gen;
    state = state.copyWith(
      isRefreshing: true,
      clearError: true,
      generation: gen,
    );

    try {
      final refreshQuery = state.query.resetPagination(newGeneration: gen);
      final result = await _repository.executeNotesQuery(refreshQuery);

      if (_activeGeneration != gen) return;

      state = state.copyWith(
        notes: result.notes,
        cursor: result.nextCursor,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        initialLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (e) {
      if (_activeGeneration != gen) return;
      state = state.copyWith(
        isRefreshing: false,
        error: e,
      );
    }
  }

  /// Retries either initial load or loadMore depending on where failure occurred
  Future<void> retry() async {
    if (state.notes.isEmpty) {
      await _loadInitial(state.query);
    } else {
      await loadMore();
    }
  }

  /// Optimistically updates a local note in the visible collection
  void updateLocalNote(Note note) {
    final idx = state.notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) {
      final updatedList = List<Note>.of(state.notes);
      updatedList[idx] = note;
      state = state.copyWith(notes: updatedList);
    }
  }

  /// Optimistically removes a note from visible collection
  void removeLocalNote(String noteId) {
    final idx = state.notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      final updatedList = List<Note>.of(state.notes)..removeAt(idx);
      final newCount = (state.totalCount - 1).clamp(0, 999999);
      state = state.copyWith(notes: updatedList, totalCount: newCount);
    }
  }
}

// ==========================================
// GROUPED NOTES PROVIDER FOR PAGINATED LIST
// ==========================================

final groupedNotesCollectionProvider = Provider<List<NoteGroup>>((ref) {
  final collectionState = ref.watch(notesCollectionProvider);
  final destination = ref.watch(currentDestinationProvider);
  final separatePinned = destination == AppDestination.allNotes &&
      collectionState.query.sort.pinnedFirst;

  return NoteGroup.groupByDate(
    collectionState.notes,
    separatePinned: separatePinned,
  );
});
