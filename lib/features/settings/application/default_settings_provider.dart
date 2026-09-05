import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/default_settings.dart';
import 'settings_provider.dart';

class DefaultSettingsNotifier extends StateNotifier<DefaultSettings> {
  DefaultSettingsNotifier(this._prefs) : super(_loadSettings(_prefs));

  final SharedPreferences? _prefs;

  static const String swipeToSearchEditorKey = 'setting_swipe_to_search_editor';
  static const String swipeDownToSearchNotesKey =
      'setting_swipe_down_to_search_notes';

  static DefaultSettings _loadSettings(SharedPreferences? prefs) {
    if (prefs == null) {
      return const DefaultSettings();
    }
    final swipeEditor = prefs.getBool(swipeToSearchEditorKey) ?? true;
    final swipeNotes = prefs.getBool(swipeDownToSearchNotesKey) ?? true;

    return DefaultSettings(
      swipeToSearchEditor: swipeEditor,
      swipeDownToSearchNotes: swipeNotes,
    );
  }

  Future<void> setSwipeToSearchEditor(bool value) async {
    state = state.copyWith(swipeToSearchEditor: value);
    await _prefs?.setBool(swipeToSearchEditorKey, value);
  }

  Future<void> setSwipeDownToSearchNotes(bool value) async {
    state = state.copyWith(swipeDownToSearchNotes: value);
    await _prefs?.setBool(swipeDownToSearchNotesKey, value);
  }
}

final defaultSettingsProvider =
    StateNotifierProvider<DefaultSettingsNotifier, DefaultSettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // If not provided in a test scope, fallback to in-memory defaults
  }
  return DefaultSettingsNotifier(prefs);
});
