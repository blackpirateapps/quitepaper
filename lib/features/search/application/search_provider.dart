import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../domain/search_result.dart';

export '../domain/search_result.dart';

/// Provider for active search filter chip (All, Notes, Documents, Tags)
final searchFilterProvider = StateProvider<SearchFilter>((ref) => SearchFilter.all);

/// Reactive provider yielding unified notes, documents, and OCR search results
final globalSearchResultsProvider = StreamProvider<GlobalSearchResults>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    return Stream.value(const GlobalSearchResults(query: ''));
  }

  final notesRepo = ref.watch(notesRepositoryProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);

  // 1. Stream of matching notes
  final notesStream = notesRepo.watchNotes(
    isArchived: false,
    isTrashed: false,
    searchQuery: query,
  );

  // 2. Stream/Future of matching documents (Title and OCR Text)
  return notesStream.asyncMap((notesList) async {
    final cleanQuery = query.toLowerCase();

    // Map notes to NoteSearchMatch with match metadata
    final noteMatches = <NoteSearchMatch>[];
    for (final note in notesList) {
      final titleMatch = note.title.toLowerCase().contains(cleanQuery);
      final contentMatch = note.content.toLowerCase().contains(cleanQuery);
      final tagMatch = note.tags.any((t) => t.toLowerCase().contains(cleanQuery.replaceAll(RegExp(r'^#'), '')));

      noteMatches.add(
        NoteSearchMatch(
          note: note,
          matchedSnippet: _getNotePreviewSnippet(note, cleanQuery),
          matchedInTitle: titleMatch,
          matchedInContent: contentMatch,
          matchedInTags: tagMatch,
        ),
      );
    }

    // Query matching documents and OCR text
    final documentMatches = await ocrSearchService.searchDocuments(query);

    // Query matching tags
    final allTags = await notesRepo.getAllTagNames();
    final matchingTags = allTags
        .where((tag) => tag.toLowerCase().contains(cleanQuery.replaceAll(RegExp(r'^#'), '')))
        .toList();

    return GlobalSearchResults(
      query: query,
      noteMatches: noteMatches,
      documentMatches: documentMatches,
      matchingTags: matchingTags,
    );
  });
});

String _getNotePreviewSnippet(Note note, String cleanQuery) {
  final query = cleanQuery.replaceAll(RegExp(r'^#'), '');
  if (query.isEmpty) return note.previewSnippet;

  final content = note.content;
  final matchIdx = content.toLowerCase().indexOf(query);
  if (matchIdx == -1) return note.previewSnippet;

  final start = (matchIdx - 25).clamp(0, content.length);
  final prefix = start > 0 ? '…' : '';
  final rawSnippet = content.substring(start).trim();
  return '$prefix$rawSnippet'.replaceAll(RegExp(r'\s+'), ' ');
}
