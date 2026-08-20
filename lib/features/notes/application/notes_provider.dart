import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/notes_repository.dart';
import '../domain/note_group.dart';
import '../domain/note_model.dart';

enum AppDestination {
  allNotes,
  pinned,
  archive,
  trash,
  tag,
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final ocrCrypto = ref.watch(ocrCryptoProvider);
  return DriftNotesRepository(db, keyManager, ocrCrypto);
});

/// Currently selected top-level destination in the sidebar / navigation
final currentDestinationProvider = StateProvider<AppDestination>((ref) => AppDestination.allNotes);

/// Currently selected tag filter on notes list (null = no tag filter)
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);

/// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Stream of notes matching the current destination and tag filter
final filteredNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final destination = ref.watch(currentDestinationProvider);
  final tagFilter = ref.watch(selectedTagFilterProvider);

  switch (destination) {
    case AppDestination.allNotes:
      return repository.watchNotes(
        isArchived: false,
        isTrashed: false,
        filterTag: tagFilter,
      );
    case AppDestination.pinned:
      return repository.watchNotes(
        isArchived: false,
        isTrashed: false,
        isPinned: true,
        filterTag: tagFilter,
      );
    case AppDestination.archive:
      return repository.watchNotes(
        isArchived: true,
        isTrashed: false,
        filterTag: tagFilter,
      );
    case AppDestination.trash:
      return repository.watchNotes(
        isTrashed: true,
        filterTag: tagFilter,
      );
    case AppDestination.tag:
      return repository.watchNotes(
        isArchived: false,
        isTrashed: false,
        filterTag: tagFilter,
      );
  }
});

/// Stream of grouped notes (separated by Pinned, Today, Yesterday, etc.)
final groupedNotesStreamProvider = Provider<AsyncValue<List<NoteGroup>>>((ref) {
  final notesAsync = ref.watch(filteredNotesStreamProvider);
  final destination = ref.watch(currentDestinationProvider);

  return notesAsync.whenData((notes) {
    final separatePinned = destination == AppDestination.allNotes;
    return NoteGroup.groupByDate(notes, separatePinned: separatePinned);
  });
});

/// Stream of all tags with active note count
final allTagsStreamProvider = StreamProvider<List<TagWithCount>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchTags();
});

/// Stream counts for sidebar badge indicators
final activeNotesCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchActiveNotesCount();
});

final pinnedNotesCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchPinnedNotesCount();
});

final archivedNotesCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchArchivedNotesCount();
});

final trashedNotesCountProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchTrashedNotesCount();
});

/// Stream of search results (searches active notes by default, or all non-trashed)
final searchNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return const Stream.empty();
  }
  // Default search looks through active notes
  return repository.watchNotes(
    isArchived: false,
    isTrashed: false,
    searchQuery: query.trim(),
  );
});

/// Provider for a single note by id
final noteDetailStreamProvider = StreamProvider.family<Note?, String>((ref, id) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchNoteById(id);
});

/// Whether the left navigation sidebar is visible on large/tablet screens
final isNavSidebarVisibleProvider = StateProvider<bool>((ref) => true);

/// Whether the middle note list pane is visible on large/tablet screens
final isNoteListVisibleProvider = StateProvider<bool>((ref) => true);
