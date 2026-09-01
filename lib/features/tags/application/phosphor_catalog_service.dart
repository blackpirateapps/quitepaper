import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/tag_icon_definition.dart';

/// Riverpod provider for [PhosphorCatalogService].
final phosphorCatalogServiceProvider = Provider<PhosphorCatalogService>((ref) {
  return PhosphorCatalogService();
});

/// Service managing the full offline Phosphor Icon catalog, lazy loading, and search indexing.
class PhosphorCatalogService {
  PhosphorCatalogService({AssetBundle? assetBundle}) : _bundle = assetBundle ?? rootBundle;

  final AssetBundle _bundle;
  List<PhosphorIconDefinition>? _cachedCatalog;
  int _currentGeneration = 0;

  /// Returns whether the catalog is already loaded into RAM.
  bool get isLoaded => _cachedCatalog != null;

  /// Total count of icons in the catalog (loads lazily if not loaded).
  Future<int> get iconCount async {
    final catalog = await getCatalog();
    return catalog.length;
  }

  /// Lazily loads the Phosphor icon catalog from bundled assets.
  Future<List<PhosphorIconDefinition>> getCatalog({bool forceReload = false}) async {
    if (_cachedCatalog != null && !forceReload) {
      return _cachedCatalog!;
    }

    try {
      final jsonString = await _bundle.loadString('assets/icons/phosphor_catalog.json');
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        throw const FormatException('Invalid catalog structure: expected JSON array');
      }

      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(PhosphorIconDefinition.fromJson)
          .toList();

      _cachedCatalog = items;
      return items;
    } catch (e) {
      // Return empty list on failure; caller handles error state
      return [];
    }
  }

  /// Searches and filters the catalog with rank scoring and generation token race guard.
  Future<List<PhosphorIconDefinition>> search({
    required String query,
    String? category,
    Set<String>? favoriteIds,
    List<String>? recentIds,
    int? generation,
  }) async {
    if (generation != null) {
      if (generation < _currentGeneration) {
        return []; // Stale request
      }
      _currentGeneration = generation;
    }

    final catalog = await getCatalog();
    if (catalog.isEmpty) return [];

    final normalizedQuery = query.trim().toLowerCase();
    final isSearching = normalizedQuery.isNotEmpty;

    // Filter by category or special filters (Favorites, Recent)
    Iterable<PhosphorIconDefinition> filtered = catalog;

    if (category != null && category.isNotEmpty) {
      final cat = category.toLowerCase();
      if (cat == 'favorites') {
        if (favoriteIds == null || favoriteIds.isEmpty) {
          return [];
        }
        filtered = filtered.where((item) => favoriteIds.contains(item.id));
      } else if (cat == 'recent') {
        if (recentIds == null || recentIds.isEmpty) {
          return [];
        }
        // Preserve MRU order
        final itemMap = {for (final item in catalog) item.id: item};
        final ordered = <PhosphorIconDefinition>[];
        for (final id in recentIds) {
          if (itemMap.containsKey(id)) {
            ordered.add(itemMap[id]!);
          }
        }
        filtered = ordered;
      } else if (cat != 'all') {
        filtered = filtered.where((item) => item.categories.contains(cat));
      }
    }

    if (!isSearching) {
      // If we filtered by 'recent' without a query, return in MRU order
      if (category?.toLowerCase() == 'recent') {
        return filtered.toList();
      }
      // Otherwise alphabetical
      return filtered.toList();
    }

    // Score and rank search matches
    final scoredList = <_ScoredIcon>[];
    final queryTokens = normalizedQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    for (final item in filtered) {
      final score = _calculateScore(item, normalizedQuery, queryTokens);
      if (score > 0) {
        scoredList.add(_ScoredIcon(item, score));
      }
    }

    // Sort by score descending, then by name length, then alphabetically
    scoredList.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;

      final lenCmp = a.item.id.length.compareTo(b.item.id.length);
      if (lenCmp != 0) return lenCmp;

      return a.item.id.compareTo(b.item.id);
    });

    return scoredList.map((s) => s.item).toList();
  }

  int _calculateScore(PhosphorIconDefinition item, String normalizedQuery, List<String> queryTokens) {
    final id = item.id.toLowerCase();
    final name = item.name.toLowerCase();
    final tags = item.tags.map((t) => t.toLowerCase()).toList();

    // 1. Exact match on ID or Name
    if (id == normalizedQuery || name == normalizedQuery) {
      return 1000;
    }

    // 2. Exact prefix match on ID or Name
    if (id.startsWith(normalizedQuery) || name.startsWith(normalizedQuery)) {
      return 800;
    }

    // 3. Exact match on one of the tags/aliases
    if (tags.contains(normalizedQuery)) {
      return 700;
    }

    // 4. Token prefix match
    final nameWords = name.split(' ');
    final idWords = id.split('-');
    final allWords = [...nameWords, ...idWords];

    bool allTokensMatchPrefix = true;
    for (final qToken in queryTokens) {
      final matchesAWord = allWords.any((w) => w.startsWith(qToken));
      if (!matchesAWord) {
        allTokensMatchPrefix = false;
        break;
      }
    }
    if (allTokensMatchPrefix && queryTokens.isNotEmpty) {
      return 600;
    }

    // 5. Substring match on ID or Name
    if (id.contains(normalizedQuery) || name.contains(normalizedQuery)) {
      return 500;
    }

    // 6. Tag prefix match
    if (tags.any((t) => t.startsWith(normalizedQuery))) {
      return 400;
    }

    // 7. Tag substring match
    if (tags.any((t) => t.contains(normalizedQuery))) {
      return 300;
    }

    // 8. Category match
    if (item.categories.any((c) => c.toLowerCase().contains(normalizedQuery))) {
      return 200;
    }

    return 0;
  }
}

class _ScoredIcon {
  _ScoredIcon(this.item, this.score);
  final PhosphorIconDefinition item;
  final int score;
}
