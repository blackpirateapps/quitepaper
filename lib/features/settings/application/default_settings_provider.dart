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
  static const String interactiveChecklistsInPreviewKey =
      'setting_interactive_checklists_in_preview';
  static const String imageCompressionActionKey =
      'setting_image_compression_action';
  static const String imageCompressionPresetKey =
      'setting_image_compression_preset';

  static DefaultSettings _loadSettings(SharedPreferences? prefs) {
    if (prefs == null) {
      return const DefaultSettings();
    }
    final swipeEditor = prefs.getBool(swipeToSearchEditorKey) ?? true;
    final swipeNotes = prefs.getBool(swipeDownToSearchNotesKey) ?? true;
    final interactiveChecklists =
        prefs.getBool(interactiveChecklistsInPreviewKey) ?? true;
    final actionString = prefs.getString(imageCompressionActionKey);
    final presetString = prefs.getString(imageCompressionPresetKey);

    return DefaultSettings(
      swipeToSearchEditor: swipeEditor,
      swipeDownToSearchNotes: swipeNotes,
      interactiveChecklistsInPreview: interactiveChecklists,
      imageCompressionAction: ImageCompressionAction.fromIdentifier(actionString),
      imageCompressionPreset: ImageCompressionPreset.fromIdentifier(presetString),
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

  Future<void> setInteractiveChecklistsInPreview(bool value) async {
    state = state.copyWith(interactiveChecklistsInPreview: value);
    await _prefs?.setBool(interactiveChecklistsInPreviewKey, value);
  }

  Future<void> setImageCompressionAction(ImageCompressionAction action) async {
    state = state.copyWith(imageCompressionAction: action);
    await _prefs?.setString(imageCompressionActionKey, action.identifier);
  }

  Future<void> setImageCompressionPreset(ImageCompressionPreset preset) async {
    state = state.copyWith(imageCompressionPreset: preset);
    await _prefs?.setString(imageCompressionPresetKey, preset.identifier);
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
