import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/application/settings_provider.dart';

/// Device-local, non-synced suppression set for the §6.5 backfill nudge.
///
/// Holds the `YYYY-MM-DD` dates for which the user tapped
/// "Don't ask again for this day". Persisted in [SharedPreferences] as a
/// JSON-encoded list under a single key. This is an internal preference with
/// no UI and contains no location data, so it is intentionally **not synced**
/// (§6.5 / §7). Mirrors the prefs + try/catch fallback pattern of
/// `default_settings_provider.dart` and `place_alias_store.dart`.
class BackfillSuppressionStore extends StateNotifier<Set<String>> {
  BackfillSuppressionStore(this._prefs) : super(_load(_prefs));

  final SharedPreferences? _prefs;

  /// Single SharedPreferences key holding the JSON-encoded list of dates.
  static const String storageKey = 'journal_backfill_suppressed_days';

  /// Whether [date] (a `YYYY-MM-DD` string) is currently suppressed. Cheap
  /// membership check for the editor's per-build nudge gate.
  bool isDaySuppressed(String date) => state.contains(date);

  /// Adds [date] to the device-local suppression set (idempotent). Reopening
  /// an entry on that date will no longer nudge; other days are unaffected.
  void suppressDay(String date) {
    if (date.isEmpty || state.contains(date)) return;
    state = {...state, date};
    _persist();
  }

  static Set<String> _load(SharedPreferences? prefs) {
    if (prefs == null) return <String>{};
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      // Corrupt payload → start empty rather than crash the editor.
      return <String>{};
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return; // in-memory only (e.g. tests without prefs)
    unawaited(prefs.setString(storageKey, jsonEncode(state.toList())));
  }
}

/// Device-local backfill-suppression provider. Falls back to an in-memory
/// store when [sharedPreferencesProvider] is not overridden (mirrors
/// `default_settings_provider.dart`).
final backfillSuppressionProvider =
    StateNotifierProvider<BackfillSuppressionStore, Set<String>>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // No prefs in this scope → in-memory only.
  }
  return BackfillSuppressionStore(prefs);
});
