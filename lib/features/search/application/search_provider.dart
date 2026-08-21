import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../../../core/search/fuzzy_search_engine.dart';
import '../../notes/application/notes_provider.dart';
import '../domain/search_result.dart';

export '../domain/search_result.dart';

/// Provider for active search filter chip (All, Notes, Documents, Tags)
final searchFilterProvider = StateProvider<SearchFilter>((ref) => SearchFilter.all);

/// Reactive provider yielding unified notes, documents, and OCR search results
/// with fuzzy typo tolerance and relevance ranking.
final globalSearchResultsProvider = StreamProvider<GlobalSearchResults>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    return Stream.value(const GlobalSearchResults(query: ''));
  }

  final notesRepo = ref.watch(notesRepositoryProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);

  // Watch all active notes (unfiltered by SQLite LIKE so FuzzySearchEngine evaluates typos)
  final notesStream = notesRepo.watchNotes(
    isArchived: false,
    isTrashed: false,
  );

  return notesStream.asyncMap((notesList) async {
    final noteMatches = <NoteSearchMatch>[];

    for (final note in notesList) {
      final titleMatch = FuzzySearchEngine.evaluate(
        query: query,
        text: note.title,
        isTitle: true,
      );

      final tagsText = note.tags.map((t) => '#$t $t').join(' ');
      final tagMatch = FuzzySearchEngine.evaluate(
        query: query,
        text: tagsText,
        isTag: true,
      );

      final contentMatch = FuzzySearchEngine.evaluate(
        query: query,
        text: note.content,
        isTitle: false,
      );

      if (titleMatch.hasMatch || tagMatch.hasMatch || contentMatch.hasMatch) {
        final totalScore = titleMatch.score + tagMatch.score + contentMatch.score;
        final isFuzzy = titleMatch.isFuzzy || tagMatch.isFuzzy || contentMatch.isFuzzy;
        final maxTokensMatched = max(
          titleMatch.matchedTokensCount,
          max(tagMatch.matchedTokensCount, contentMatch.matchedTokensCount),
        );

        final snippet = contentMatch.hasMatch && contentMatch.snippet.isNotEmpty
            ? contentMatch.snippet
            : note.previewSnippet;

        noteMatches.add(
          NoteSearchMatch(
            note: note,
            matchedSnippet: snippet,
            matchedInTitle: titleMatch.hasMatch,
            matchedInContent: contentMatch.hasMatch,
            matchedInTags: tagMatch.hasMatch,
            isFuzzy: isFuzzy,
            matchedTokensCount: maxTokensMatched,
            score: totalScore,
          ),
        );
      }
    }

    // Sort notes by relevance score
    noteMatches.sort((a, b) => b.score.compareTo(a.score));

    // Query matching documents and OCR text
    final documentMatches = await ocrSearchService.searchDocuments(query);

    // Query matching tags
    final allTags = await notesRepo.getAllTagNames();
    final matchingTags = <String>[];
    for (final tag in allTags) {
      final tagEval = FuzzySearchEngine.evaluate(
        query: query,
        text: tag,
        isTag: true,
      );
      if (tagEval.hasMatch) {
        matchingTags.add(tag);
      }
    }

    return GlobalSearchResults(
      query: query,
      noteMatches: noteMatches,
      documentMatches: documentMatches,
      matchingTags: matchingTags,
    );
  });
});
