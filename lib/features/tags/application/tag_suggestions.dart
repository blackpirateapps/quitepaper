import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/tag_parser.dart';
import '../../settings/application/settings_provider.dart';
import '../../watched_import/application/native_watched_engine.dart';
import '../../watched_import/native/api/tags.dart' as native;
import '../domain/tag_model.dart';
import 'tag_providers.dart';

enum TagSuggestionSort {
  suggested('Suggested'),
  recent('Recent'),
  mostUsed('Most used'),
  pinned('Pinned');

  const TagSuggestionSort(this.label);
  final String label;
}

/// Device-local history of actual additions, independent of tag metadata edits.
class RecentTagNames extends StateNotifier<List<String>> {
  RecentTagNames(this._prefs)
    : super(_clean(_prefs?.getStringList(storageKey) ?? const []));

  static const storageKey = 'recently_added_tags_v1';
  final SharedPreferences? _prefs;

  static List<String> _clean(Iterable<String> names) => names
      .map(TagParser.normalizeTag)
      .where(TagParser.isValidTag)
      .toSet()
      .take(50)
      .toList();

  Future<void> record(Iterable<String> names) async {
    final added = names
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet()
        .toList();
    if (added.isEmpty) return;
    state = _clean([...added.reversed, ...state]);
    try {
      await _prefs?.setStringList(storageKey, state);
    } catch (error) {
      // A preference write failure must not turn a successful note save into
      // an apparent tagging failure. Keep history available for this session.
      debugPrint('Could not persist recent tags ($error)');
    }
  }
}

final recentTagNamesProvider =
    StateNotifierProvider<RecentTagNames, List<String>>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } on UnimplementedError {
        // Tests and CLI containers can omit platform preferences.
      }
      return RecentTagNames(prefs);
    });

/// Rust ranks tags on the existing Linux bridge. Other targets keep the same
/// offline behavior without adding a native build prerequisite to Android/iOS.
class TagSuggestionService {
  TagSuggestionService({this.useNative = true});
  final bool useNative;
  Future<bool>? _nativeReady;

  Future<bool> _loadNative() async {
    if (!useNative || kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
      return false;
    }
    try {
      await NativeWatchedEngine().load();
      return true;
    } catch (error) {
      debugPrint('Tag suggestions: native ranking unavailable ($error)');
      return false;
    }
  }

  Future<List<String>> search({
    required List<Tag> tags,
    required String query,
    required List<String> recent,
    required Set<String> excluded,
    TagSuggestionSort sort = TagSuggestionSort.suggested,
    int limit = 40,
  }) async {
    final cleanQuery = TagParser.normalizeTag(query);
    final recentOrder = {for (var i = 0; i < recent.length; i++) recent[i]: i};
    if (await (_nativeReady ??= _loadNative())) {
      try {
        return await native.rankTagSuggestions(
          tags: tags
              .map(
                (tag) => native.TagSuggestionInput(
                  name: tag.name,
                  noteCount: tag.noteCount,
                  pinned: tag.isPinned,
                  pinnedOrder: tag.pinnedOrder,
                  recentOrder: recentOrder[tag.name] ?? -1,
                ),
              )
              .toList(),
          query: cleanQuery,
          excluded: excluded.toList(),
          order: switch (sort) {
            TagSuggestionSort.suggested => native.TagSuggestionOrder.suggested,
            TagSuggestionSort.recent => native.TagSuggestionOrder.recent,
            TagSuggestionSort.mostUsed => native.TagSuggestionOrder.mostUsed,
            TagSuggestionSort.pinned => native.TagSuggestionOrder.pinned,
          },
          limit: limit.clamp(0, 100),
        );
      } catch (error) {
        debugPrint('Tag suggestions: using portable ranking ($error)');
      }
    }
    final seen = <String>{};
    final matches = tags.where((tag) {
      if (excluded.contains(tag.name) || !seen.add(tag.name)) return false;
      if (sort == TagSuggestionSort.pinned && !tag.isPinned) return false;
      if (sort == TagSuggestionSort.recent &&
          !recentOrder.containsKey(tag.name)) {
        return false;
      }
      if (sort == TagSuggestionSort.mostUsed && tag.noteCount == 0) {
        return false;
      }
      return _matchScore(tag.name, cleanQuery) > 0;
    }).toList();
    int recency(Tag tag) => recentOrder[tag.name] ?? 0x7fffffff;
    matches.sort((a, b) {
      var comparison = _matchScore(
        b.name,
        cleanQuery,
      ).compareTo(_matchScore(a.name, cleanQuery));
      if (comparison != 0) return comparison;
      switch (sort) {
        case TagSuggestionSort.suggested:
          comparison = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
          if (comparison == 0 && a.isPinned && b.isPinned) {
            comparison = a.pinnedOrder.compareTo(b.pinnedOrder);
          }
          if (comparison == 0) comparison = recency(a).compareTo(recency(b));
          if (comparison == 0) comparison = b.noteCount.compareTo(a.noteCount);
        case TagSuggestionSort.pinned:
          comparison = a.pinnedOrder.compareTo(b.pinnedOrder);
        case TagSuggestionSort.recent:
          comparison = recency(a).compareTo(recency(b));
        case TagSuggestionSort.mostUsed:
          comparison = b.noteCount.compareTo(a.noteCount);
      }
      return comparison != 0 ? comparison : a.name.compareTo(b.name);
    });
    return matches.take(limit.clamp(0, 100)).map((tag) => tag.name).toList();
  }

  // Keep this portable implementation in parity with api/tags.rs. The native
  // integration test compares both paths using the same catalogue and queries.
  int _matchScore(String name, String query) {
    if (query.isEmpty) return 1;
    if (name == query) return 1000;
    final slash = query.lastIndexOf('/');
    if (slash >= 0) {
      final parent = query.substring(0, slash);
      if (!name.startsWith('$parent/') || !name.startsWith(query)) return 0;
      return name.substring(parent.length + 1).contains('/') ? 800 : 900;
    }
    if (name.startsWith(query)) return 800;
    if (name.split('/').last.startsWith(query)) return 700;
    return name.contains(query) ? 400 : 0;
  }
}

final tagSuggestionServiceProvider = Provider((ref) => TagSuggestionService());

typedef TagSuggestionRequest = ({
  String query,
  TagSuggestionSort sort,
  String excluded,
});

final tagSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, TagSuggestionRequest>((ref, request) async {
      final recent = ref.watch(recentTagNamesProvider);
      final service = ref.watch(tagSuggestionServiceProvider);
      final tags = await ref.watch(allTagsProvider.future);
      return service.search(
        tags: tags,
        query: request.query,
        recent: recent,
        excluded: request.excluded.split('\n').toSet(),
        sort: request.sort,
      );
    });
