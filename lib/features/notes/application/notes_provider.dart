import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../data/notes_repository.dart';
import '../domain/note_group.dart';
import '../domain/note_model.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftNotesRepository(db);
});

/// Currently selected tag filter on the main notes list (null = all notes)
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);

/// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Stream of all notes matching selected tag filter
final filteredNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final tagFilter = ref.watch(selectedTagFilterProvider);
  return repository.watchNotes(filterTag: tagFilter);
});

/// Stream of grouped notes (separated by Pinned, Today, Yesterday, etc.)
final groupedNotesStreamProvider = Provider<AsyncValue<List<NoteGroup>>>((ref) {
  final notesAsync = ref.watch(filteredNotesStreamProvider);
  return notesAsync.whenData((notes) => NoteGroup.groupByDate(notes));
});

/// Stream of all tags with note count
final allTagsStreamProvider = StreamProvider<List<TagWithCount>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchTags();
});

/// Stream of search results
final searchNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return const Stream.empty();
  }
  return repository.watchNotes(searchQuery: query.trim());
});

/// Provider for a single note by id
final noteDetailStreamProvider = StreamProvider.family<Note?, String>((ref, id) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchNoteById(id);
});
