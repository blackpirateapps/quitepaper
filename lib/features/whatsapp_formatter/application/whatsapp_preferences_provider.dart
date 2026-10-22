import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/application/settings_provider.dart';
import '../domain/whatsapp_format_options.dart';

const String _kWhatsAppOptionsPrefKey = 'quietpaper_whatsapp_format_options_v1';

/// Provider for managing and persisting WhatsApp formatting preferences.
final whatsappFormatOptionsProvider =
    StateNotifierProvider<WhatsAppFormatOptionsNotifier, WhatsAppFormatOptions>(
  (ref) {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return WhatsAppFormatOptionsNotifier(prefs);
    } catch (_) {
      return WhatsAppFormatOptionsNotifier(null);
    }
  },
);

class WhatsAppFormatOptionsNotifier
    extends StateNotifier<WhatsAppFormatOptions> {
  WhatsAppFormatOptionsNotifier(this._prefs) : super(_loadInitial(_prefs));

  final SharedPreferences? _prefs;

  static WhatsAppFormatOptions _loadInitial(SharedPreferences? prefs) {
    if (prefs == null) return const WhatsAppFormatOptions();
    try {
      final raw = prefs.getString(_kWhatsAppOptionsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return WhatsAppFormatOptions.fromJson(decoded);
      }
    } catch (_) {}
    return const WhatsAppFormatOptions();
  }

  Future<void> toggleShowSenderNames() async {
    state = state.copyWith(showSenderNames: !state.showSenderNames);
    await _persist();
  }

  Future<void> togglePreserveTimestamps() async {
    state = state.copyWith(preserveTimestamps: !state.preserveTimestamps);
    await _persist();
  }

  Future<void> toggleGroupConsecutiveMessages() async {
    state = state.copyWith(
      groupConsecutiveMessages: !state.groupConsecutiveMessages,
    );
    await _persist();
  }

  Future<void> setOptions(WhatsAppFormatOptions newOptions) async {
    state = newOptions;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _kWhatsAppOptionsPrefKey,
        jsonEncode(state.toJson()),
      );
    } catch (_) {}
  }
}
