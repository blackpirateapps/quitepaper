import 'dart:collection';
import '../domain/highlight_result.dart';

/// LRU cache for syntax tokenization results.
/// Tokenization results are cached independently of UI themes, ensuring theme switches
/// reuse parsed tokens with zero re-tokenization overhead.
class SyntaxHighlightCache {
  SyntaxHighlightCache({this.maxEntries = 100});

  final int maxEntries;
  final LinkedHashMap<String, HighlightResult> _cache = LinkedHashMap<String, HighlightResult>();

  int _hits = 0;
  int _misses = 0;

  int get hits => _hits;
  int get misses => _misses;
  int get size => _cache.length;

  /// Builds a deterministic cache key.
  static String buildKey({
    required String languageId,
    required String source,
    required int highlighterVersion,
  }) {
    // Fast hash code combined with length for quick comparison
    return '$highlighterVersion:$languageId:${source.length}:${source.hashCode}';
  }

  /// Retrieves a cached [HighlightResult] or returns `null` if not found.
  HighlightResult? get(String key) {
    final result = _cache.remove(key);
    if (result != null) {
      // Re-insert at end for LRU order
      _cache[key] = result;
      _hits++;
      return result;
    }
    _misses++;
    return null;
  }

  /// Caches a [HighlightResult] under [key], evicting oldest entries if capacity is exceeded.
  void put(String key, HighlightResult result) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  /// Clears the entire cache.
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }
}
