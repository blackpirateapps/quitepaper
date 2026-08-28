import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../settings/application/settings_provider.dart';
import '../domain/notes_query.dart';
import '../domain/saved_filter.dart';

const String _savedFiltersPrefKey = 'quietpaper_saved_filters_v1';

class SavedFiltersService {
  SavedFiltersService(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();

  List<SavedFilter> loadSavedFilters() {
    final rawJson = _prefs.getString(_savedFiltersPrefKey);
    if (rawJson == null || rawJson.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return SavedFilter.fromJson(item);
                } else if (item is Map) {
                  return SavedFilter.fromJson(Map<String, dynamic>.from(item));
                }
              } catch (_) {}
              return null;
            })
            .whereType<SavedFilter>()
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _persist(List<SavedFilter> filters) async {
    final encoded = jsonEncode(filters.map((f) => f.toJson()).toList());
    await _prefs.setString(_savedFiltersPrefKey, encoded);
  }

  Future<SavedFilter> createSavedFilter({
    required String name,
    required NotesQuery query,
  }) async {
    final current = loadSavedFilters();
    final now = DateTime.now();
    final newFilter = SavedFilter(
      id: _uuid.v4(),
      name: name.trim().isNotEmpty ? name.trim() : 'Smart View',
      query: query.copyWith(clearCursor: true, generation: 0),
      createdAt: now,
      updatedAt: now,
    );

    final updated = List<SavedFilter>.of(current)..add(newFilter);
    await _persist(updated);
    return newFilter;
  }

  Future<void> renameSavedFilter(String id, String newName) async {
    final current = loadSavedFilters();
    final idx = current.indexWhere((f) => f.id == id);
    if (idx != -1) {
      final updated = List<SavedFilter>.of(current);
      updated[idx] = updated[idx].copyWith(
        name: newName.trim().isNotEmpty ? newName.trim() : updated[idx].name,
        updatedAt: DateTime.now(),
      );
      await _persist(updated);
    }
  }

  Future<void> deleteSavedFilter(String id) async {
    final current = loadSavedFilters();
    final updated = current.where((f) => f.id != id).toList();
    await _persist(updated);
  }
}

final savedFiltersServiceProvider = Provider<SavedFiltersService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SavedFiltersService(prefs);
});

final savedFiltersProvider =
    StateNotifierProvider<SavedFiltersNotifier, List<SavedFilter>>((ref) {
  final service = ref.watch(savedFiltersServiceProvider);
  return SavedFiltersNotifier(service);
});

class SavedFiltersNotifier extends StateNotifier<List<SavedFilter>> {
  SavedFiltersNotifier(this._service) : super(_service.loadSavedFilters());

  final SavedFiltersService _service;

  Future<SavedFilter> create({
    required String name,
    required NotesQuery query,
  }) async {
    final created = await _service.createSavedFilter(name: name, query: query);
    state = _service.loadSavedFilters();
    return created;
  }

  Future<void> rename(String id, String newName) async {
    await _service.renameSavedFilter(id, newName);
    state = _service.loadSavedFilters();
  }

  Future<void> delete(String id) async {
    await _service.deleteSavedFilter(id);
    state = _service.loadSavedFilters();
  }
}
