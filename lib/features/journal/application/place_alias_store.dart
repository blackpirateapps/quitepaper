import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/journal/application/place_grouping_service.dart';
import '../../settings/application/settings_provider.dart';

/// Device-local, reversible merge/alias store for the Places surface (§2.3).
///
/// IMPORTANT — locked decision: although §2.3 describes this as *synced* vault
/// data, for now it is persisted **device-local** in [SharedPreferences] under a
/// single JSON key. It is a presentation-layer mapping only: it NEVER mutates
/// note frontmatter and is fully reversible via [unmerge].
///
/// State shape mirrors what [PlaceGroupingService.group] consumes: a
/// `Map<String, PlaceAlias>` keyed by the *normalized* match key being remapped.
/// Each value points that key at a `canonicalKey` and a pretty `displayName`.
class PlaceAliasStore extends StateNotifier<Map<String, PlaceAlias>> {
  PlaceAliasStore(this._prefs) : super(_load(_prefs));

  final SharedPreferences? _prefs;

  /// Single SharedPreferences key holding the JSON-encoded alias map.
  static const String storageKey = 'journal_place_aliases';

  /// Folds [matchKeys] into one place: each key is pointed at [canonicalKey]
  /// with the shared [displayName]. The canonical key is also mapped to itself
  /// so entries that already produce it adopt the chosen display name.
  void merge(
    List<String> matchKeys, {
    required String canonicalKey,
    required String displayName,
  }) {
    final next = Map<String, PlaceAlias>.of(state);
    final alias = PlaceAlias(canonicalKey: canonicalKey, displayName: displayName);
    for (final key in matchKeys) {
      next[key] = alias;
    }
    next[canonicalKey] = alias;
    state = next;
    _persist();
  }

  /// Renames a merged place: updates [displayName] for every entry that points
  /// at [canonicalKey], and ensures the canonical key maps to itself.
  void rename({
    required String canonicalKey,
    required String displayName,
  }) {
    final alias = PlaceAlias(canonicalKey: canonicalKey, displayName: displayName);
    final next = Map<String, PlaceAlias>.of(state);
    next.updateAll(
      (key, existing) => existing.canonicalKey == canonicalKey ? alias : existing,
    );
    next[canonicalKey] = alias;
    state = next;
    _persist();
  }

  /// Removes the alias entry for [matchKey], restoring it to its own group
  /// (reversible unmerge). No-op when the key is not aliased.
  void unmerge(String matchKey) {
    if (!state.containsKey(matchKey)) return;
    state = Map<String, PlaceAlias>.of(state)..remove(matchKey);
    _persist();
  }

  static Map<String, PlaceAlias> _load(SharedPreferences? prefs) {
    if (prefs == null) return const {};
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, PlaceAlias>{};
      decoded.forEach((key, value) {
        if (key is String && value is Map) {
          final canonical = value['canonicalKey'];
          final display = value['displayName'];
          if (canonical is String && display is String) {
            result[key] = PlaceAlias(canonicalKey: canonical, displayName: display);
          }
        }
      });
      return result;
    } catch (_) {
      // Corrupt payload → start empty rather than crash the Places surface.
      return const {};
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return; // in-memory only (e.g. tests without prefs)
    final map = <String, Map<String, String>>{
      for (final entry in state.entries)
        entry.key: {
          'canonicalKey': entry.value.canonicalKey,
          'displayName': entry.value.displayName,
        },
    };
    unawaited(prefs.setString(storageKey, jsonEncode(map)));
  }
}

/// Device-local alias/merge store provider. Falls back to an in-memory store
/// when [sharedPreferencesProvider] is not overridden (mirrors
/// `default_settings_provider.dart`).
final placeAliasStoreProvider =
    StateNotifierProvider<PlaceAliasStore, Map<String, PlaceAlias>>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // No prefs in this scope → in-memory only.
  }
  return PlaceAliasStore(prefs);
});
