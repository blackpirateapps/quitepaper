import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/tag_icon_registry.dart';

/// Riverpod provider for [TagIconPreferencesService].
final tagIconPreferencesServiceProvider = Provider<TagIconPreferencesService>((ref) {
  return TagIconPreferencesService();
});

/// Service for managing locally persisted Recent Tag Icons and Favorite Tag Icons.
class TagIconPreferencesService {
  TagIconPreferencesService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  SharedPreferences? _prefs;

  static const String _recentsKey = 'tag_icon_recents_v1';
  static const String _favoritesKey = 'tag_icon_favorites_v1';
  static const int maxRecents = 12;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Retrieves list of recently used icon IDs in MRU order.
  Future<List<String>> getRecentIconIds() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_recentsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => TagIconRegistry.cleanId(e.toString()))
            .whereType<String>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Adds an icon ID to the MRU recents list.
  Future<void> addRecentIcon(String rawKey) async {
    final id = TagIconRegistry.cleanId(rawKey);
    if (id == null) return;

    final current = await getRecentIconIds();
    current.remove(id);
    current.insert(0, id);

    if (current.length > maxRecents) {
      current.removeRange(maxRecents, current.length);
    }

    final prefs = await _getPrefs();
    await prefs.setString(_recentsKey, jsonEncode(current));
  }

  /// Alias for addRecentIcon.
  Future<void> recordRecentIcon(String rawKey) => addRecentIcon(rawKey);

  /// Clears the recent icons list.
  Future<void> clearRecents() async {
    final prefs = await _getPrefs();
    await prefs.remove(_recentsKey);
  }

  /// Alias for clearRecents.
  Future<void> clearRecentIcons() => clearRecents();

  /// Retrieves set of favorite icon IDs.
  Future<Set<String>> getFavoriteIconIds() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => TagIconRegistry.cleanId(e.toString()))
            .whereType<String>()
            .toSet();
      }
    } catch (_) {}
    return {};
  }

  /// Checks if an icon ID is marked as favorite.
  Future<bool> isFavorite(String rawKey) async {
    final id = TagIconRegistry.cleanId(rawKey);
    if (id == null) return false;
    final favorites = await getFavoriteIconIds();
    return favorites.contains(id);
  }

  /// Toggles favorite status for an icon ID. Returns new favorite state.
  Future<bool> toggleFavorite(String rawKey) async {
    final id = TagIconRegistry.cleanId(rawKey);
    if (id == null) return false;

    final favorites = await getFavoriteIconIds();
    final isFav = favorites.contains(id);
    if (isFav) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }

    final prefs = await _getPrefs();
    await prefs.setString(_favoritesKey, jsonEncode(favorites.toList()));
    return !isFav;
  }

  /// Adds an icon ID to favorites.
  Future<void> addFavorite(String rawKey) async {
    final id = TagIconRegistry.cleanId(rawKey);
    if (id == null) return;

    final favorites = await getFavoriteIconIds();
    favorites.add(id);

    final prefs = await _getPrefs();
    await prefs.setString(_favoritesKey, jsonEncode(favorites.toList()));
  }

  /// Removes an icon ID from favorites.
  Future<void> removeFavorite(String rawKey) async {
    final id = TagIconRegistry.cleanId(rawKey);
    if (id == null) return;

    final favorites = await getFavoriteIconIds();
    favorites.remove(id);

    final prefs = await _getPrefs();
    await prefs.setString(_favoritesKey, jsonEncode(favorites.toList()));
  }
}
