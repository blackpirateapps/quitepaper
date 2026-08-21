import '../../../core/database/app_database.dart';
import '../../notes/domain/note_model.dart';

/// Available filter categories for global search
enum SearchFilter {
  all,
  notes,
  documents,
  tags,
}

extension SearchFilterExtension on SearchFilter {
  String get label {
    switch (this) {
      case SearchFilter.all:
        return 'All';
      case SearchFilter.notes:
        return 'Notes';
      case SearchFilter.documents:
        return 'Documents';
      case SearchFilter.tags:
        return 'Tags';
    }
  }
}

/// Base sealed class for heterogeneous global search results
sealed class SearchResultItem {
  const SearchResultItem();
}

/// Search result representing a matched Note
class NoteSearchMatch extends SearchResultItem {
  final Note note;
  final String? matchedSnippet;
  final bool matchedInTitle;
  final bool matchedInTags;
  final bool matchedInContent;

  const NoteSearchMatch({
    required this.note,
    this.matchedSnippet,
    this.matchedInTitle = false,
    this.matchedInTags = false,
    this.matchedInContent = false,
  });
}

/// Search result representing a matched Document or Document OCR text page
class DocumentSearchMatch extends SearchResultItem {
  final DocumentEntity document;
  final String? parentNoteTitle;
  final String? parentNoteId;
  final int matchedPageNumber; // 1-indexed page number
  final String snippet;
  final bool isOcrMatch;

  const DocumentSearchMatch({
    required this.document,
    this.parentNoteTitle,
    this.parentNoteId,
    required this.matchedPageNumber,
    required this.snippet,
    required this.isOcrMatch,
  });
}

/// Aggregated container holding all categorized search results
class GlobalSearchResults {
  final String query;
  final List<NoteSearchMatch> noteMatches;
  final List<DocumentSearchMatch> documentMatches;
  final List<String> matchingTags;

  const GlobalSearchResults({
    required this.query,
    this.noteMatches = const [],
    this.documentMatches = const [],
    this.matchingTags = const [],
  });

  bool get isEmpty =>
      noteMatches.isEmpty && documentMatches.isEmpty && matchingTags.isEmpty;

  int get totalCount => noteMatches.length + documentMatches.length;

  int get notesCount => noteMatches.length;
  int get documentsCount => documentMatches.length;
  int get tagsCount => matchingTags.length;

  List<SearchResultItem> filteredResultsForFilter(SearchFilter filter) {
    switch (filter) {
      case SearchFilter.all:
        return [...noteMatches, ...documentMatches];
      case SearchFilter.notes:
        return noteMatches;
      case SearchFilter.documents:
        return documentMatches;
      case SearchFilter.tags:
        return noteMatches.where((m) => m.matchedInTags).toList();
    }
  }
}
