import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../search/fuzzy_search_engine.dart';
import '../search/search_index_projection.dart';



/// Represents a ranked note candidate item in the note link autocomplete picker.
class NoteLinkSearchResultItem {
  const NoteLinkSearchResultItem({
    required this.id,
    required this.title,
    required this.snippet,
    required this.tags,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isPasswordProtected = false,
    this.score = 0.0,
  });

  final String id;
  final String title;
  final String snippet;
  final List<String> tags;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isPasswordProtected;
  final double score;

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : 'Untitled';
}

/// Service that coordinates fast, local, title-dominant note search for note linking.
class NoteLinkSearchService {
  const NoteLinkSearchService(this._db);

  final AppDatabase _db;

  /// Searches for notes matching [query], prioritizing title matches and excluding [currentNoteId].
  Future<List<NoteLinkSearchResultItem>> searchNotes({
    required String query,
    String? currentNoteId,
    int limit = 30,
  }) async {
    final cleanQuery = query.trim().toLowerCase();

    // 1. Empty query: return recent notes ordered by updatedAt
    if (cleanQuery.isEmpty) {
      final rows = await (_db.select(_db.notesTable)
            ..where((n) {
              var predicate = n.isTrashed.equals(false);
              if (currentNoteId != null && currentNoteId.isNotEmpty) {
                predicate = predicate & n.id.isNotValue(currentNoteId);
              }
              return predicate;
            })
            ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
            ..limit(limit))
          .get();

      if (rows.isEmpty) return const [];

      final noteIds = rows.map((n) => n.id).toList();
      final tagsMap = await _db.getTagsForNoteIds(noteIds);

      return rows.map((n) {
        final isProtected = SearchIndexProjection.isPasswordProtected(n.content);
        final tags = (tagsMap[n.id] ?? []).map((t) => t.name).toList();
        final snippet = isProtected
            ? '🔒 Password protected note'
            : _generatePreviewSnippet(n.content);

        return NoteLinkSearchResultItem(
          id: n.id,
          title: n.title,
          snippet: snippet,
          tags: tags,
          updatedAt: n.updatedAt,
          isPinned: n.isPinned,
          isArchived: n.isArchived,
          isPasswordProtected: isProtected,
          score: 1.0,
        );
      }).toList();
    }

    // 2. Query compilation for candidate retrieval
    final compiledQuery = SearchTokenizer.compileQuery(cleanQuery);
    final candidateNoteIds = await _db.searchNoteCandidateIds(compiledQuery, limit: 100);

    // Also fetch notes directly by title LIKE to ensure all title candidates are retrieved
    final titlePattern = '%$cleanQuery%';
    final titleMatchRows = await (_db.select(_db.notesTable)
          ..where((n) =>
              n.isTrashed.equals(false) &
              (n.title.lower().like(titlePattern) |
                  n.content.lower().like(titlePattern)))
          ..limit(100))
        .get();

    final allIds = <String>{
      ...candidateNoteIds,
      ...titleMatchRows.map((n) => n.id),
    };

    if (currentNoteId != null && currentNoteId.isNotEmpty) {
      allIds.remove(currentNoteId);
    }

    if (allIds.isEmpty) return const [];

    final candidateDtos = await _db.getSearchCandidatesByIds(allIds.toList());
    final scoredItems = <NoteLinkSearchResultItem>[];

    final queryTokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    for (final candidate in candidateDtos) {
      if (candidate.id == currentNoteId) continue;

      final titleLower = candidate.title.trim().toLowerCase();
      var score = 0.0;
      var hasMatch = false;

      // Exact title match
      if (titleLower == cleanQuery) {
        score += 1000.0;
        hasMatch = true;
      }
      // Title prefix match
      else if (titleLower.startsWith(cleanQuery)) {
        score += 500.0;
        hasMatch = true;
      }
      // Title contains substring
      else if (titleLower.contains(cleanQuery)) {
        score += 250.0;
        hasMatch = true;
      }

      // Check all query tokens against title
      var allTokensInTitle = queryTokens.isNotEmpty;
      var tokensInTitleCount = 0;
      for (final tok in queryTokens) {
        if (titleLower.contains(tok)) {
          tokensInTitleCount++;
        } else {
          allTokensInTitle = false;
        }
      }

      if (allTokensInTitle && queryTokens.isNotEmpty) {
        score += 300.0 + (tokensInTitleCount * 20.0);
        hasMatch = true;
      } else if (tokensInTitleCount > 0) {
        score += (tokensInTitleCount * 30.0);
        hasMatch = true;
      }

      // Fuzzy title match
      if (!hasMatch) {
        final fuzzyTitle = FuzzySearchEngine.evaluate(
          query: cleanQuery,
          text: candidate.title,
        );
        if (fuzzyTitle.hasMatch) {
          score += 100.0 * fuzzyTitle.score;
          hasMatch = true;
        }
      }


      // Tag match
      for (final tag in candidate.tags) {
        final tagLower = tag.toLowerCase();
        if (tagLower == cleanQuery) {
          score += 90.0;
          hasMatch = true;
        } else if (tagLower.contains(cleanQuery)) {
          score += 60.0;
          hasMatch = true;
        }
      }

      // Content match (lower weight)
      if (!hasMatch && !candidate.isPasswordProtected) {
        final contentLower = candidate.content.toLowerCase();
        if (contentLower.contains(cleanQuery)) {
          score += 40.0;
          hasMatch = true;
        }
      }

      if (hasMatch) {
        // Recency bonus: up to 10 points
        final ageInHours = DateTime.now().difference(candidate.updatedAt).inHours;
        final recencyBonus = (10.0 / (1.0 + (ageInHours / 24.0))).clamp(0.0, 10.0);
        score += recencyBonus;

        if (candidate.isPinned) {
          score += 15.0;
        }

        final snippet = candidate.isPasswordProtected
            ? '🔒 Password protected note'
            : _generatePreviewSnippet(candidate.content);

        scoredItems.add(
          NoteLinkSearchResultItem(
            id: candidate.id,
            title: candidate.title,
            snippet: snippet,
            tags: candidate.tags,
            updatedAt: candidate.updatedAt,
            isPinned: candidate.isPinned,
            isArchived: candidate.isArchived,
            isPasswordProtected: candidate.isPasswordProtected,
            score: score,
          ),
        );
      }
    }

    // Sort by score descending, then by updatedAt descending
    scoredItems.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    if (scoredItems.length > limit) {
      return scoredItems.sublist(0, limit);
    }

    return scoredItems;
  }

  static String _generatePreviewSnippet(String content) {
    if (content.isEmpty) return '';
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#') ||
          trimmed.startsWith('---') ||
          trimmed.startsWith('<!--')) {
        continue;
      }
      if (trimmed.length > 100) {
        return '${trimmed.substring(0, 100)}...';
      }
      return trimmed;
    }
    return '';
  }
}
