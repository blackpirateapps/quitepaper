import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/journal_activity.dart';

final activityStorageServiceProvider = Provider<ActivityStorageService>((ref) {
  return ActivityStorageService();
});

/// Service for managing standard activity presets and persisting custom activities.
class ActivityStorageService {
  ActivityStorageService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  SharedPreferences? _prefs;
  static const _storageKey = 'quietpaper_custom_activities_v1';

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static final Map<String, JournalActivity> _cachedActivities = {};

  /// Resolves an activity synchronously from presets or in-memory cache.
  static JournalActivity? findActivitySync(String id) {
    final normalized = id.trim().toLowerCase();
    for (final act in JournalActivity.standardPresets) {
      if (act.id.toLowerCase() == normalized) return act;
    }
    return _cachedActivities[normalized];
  }

  /// Loads all custom activities stored in SharedPreferences.
  Future<List<JournalActivity>> loadCustomActivities() async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_storageKey) ?? [];
    final customActivities = <JournalActivity>[];

    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final act = JournalActivity.fromJson(map);
        customActivities.add(act);
        _cachedActivities[act.id.toLowerCase()] = act;
      } catch (_) {
        // Skip corrupted entries
      }
    }

    return customActivities;
  }

  /// Returns standard presets merged with user's saved custom activities.
  Future<List<JournalActivity>> getAllActivities() async {
    final custom = await loadCustomActivities();
    final all = <JournalActivity>[...JournalActivity.standardPresets];

    for (final act in custom) {
      if (!all.any((existing) => existing.id == act.id)) {
        all.add(act);
      }
    }

    return all;
  }

  /// Saves a newly created custom activity and persists it in SharedPreferences.
  Future<void> saveCustomActivity(JournalActivity activity) async {
    final prefs = await _getPrefs();
    final existingCustom = await loadCustomActivities();

    existingCustom.removeWhere((item) => item.id == activity.id);
    existingCustom.add(activity);
    _cachedActivities[activity.id.toLowerCase()] = activity;

    final encoded = existingCustom.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Resolves an activity by its ID from presets or custom storage.
  Future<JournalActivity?> findActivity(String id) async {
    final all = await getAllActivities();
    final normalized = id.trim().toLowerCase();
    for (final act in all) {
      if (act.id.toLowerCase() == normalized) return act;
    }
    return null;
  }
}
