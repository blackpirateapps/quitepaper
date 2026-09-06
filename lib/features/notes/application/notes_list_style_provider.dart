import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/application/settings_provider.dart';
import '../domain/notes_list_style.dart';

class NotesListStyleNotifier extends StateNotifier<NotesListStyle> {
  NotesListStyleNotifier(this._prefs) : super(_loadStyle(_prefs));

  final SharedPreferences? _prefs;
  static const String _storageKey = 'app_notes_list_style';

  static NotesListStyle _loadStyle(SharedPreferences? prefs) {
    if (prefs == null) return NotesListStyle.quietPaper;
    final val = prefs.getString(_storageKey);
    return NotesListStyle.fromString(val);
  }

  Future<void> setStyle(NotesListStyle style) async {
    if (state == style) return;
    state = style;
    await _prefs?.setString(_storageKey, style.storageKey);
  }
}

final notesListStyleProvider =
    StateNotifierProvider<NotesListStyleNotifier, NotesListStyle>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NotesListStyleNotifier(prefs);
});
