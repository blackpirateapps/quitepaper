import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/theme_family.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main()');
});

/// Immutable model representing the user's theme family and appearance choices.
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.family = ThemeFamily.classicPaper,
    this.appearance = AppearanceMode.system,
  });

  final ThemeFamily family;
  final AppearanceMode appearance;

  ThemeSettings copyWith({
    ThemeFamily? family,
    AppearanceMode? appearance,
  }) {
    return ThemeSettings(
      family: family ?? this.family,
      appearance: appearance ?? this.appearance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings &&
          runtimeType == other.runtimeType &&
          family == other.family &&
          appearance == other.appearance;

  @override
  int get hashCode => Object.hash(family, appearance);
}

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  ThemeSettingsNotifier(this._prefs) : super(_loadThemeSettings(_prefs));

  final SharedPreferences _prefs;

  static const String _familyKey = 'app_theme_family';
  static const String _appearanceKey = 'app_appearance_mode';
  static const String _legacyModeKey = 'app_theme_mode';

  static ThemeSettings _loadThemeSettings(SharedPreferences prefs) {
    // 1. Load ThemeFamily (defaults to Classic Paper)
    final familyStr = prefs.getString(_familyKey);
    final family = ThemeFamily.fromString(familyStr);

    // 2. Load AppearanceMode with migration from legacy app_theme_mode
    final appearanceStr = prefs.getString(_appearanceKey);
    final AppearanceMode appearance;
    if (appearanceStr != null) {
      appearance = AppearanceMode.fromString(appearanceStr);
    } else {
      // Migrate from legacy app_theme_mode if present
      final legacyVal = prefs.getString(_legacyModeKey);
      appearance = AppearanceMode.fromString(legacyVal);
    }

    return ThemeSettings(
      family: family,
      appearance: appearance,
    );
  }

  Future<void> setThemeFamily(ThemeFamily family) async {
    state = state.copyWith(family: family);
    await _prefs.setString(_familyKey, family.storageKey);
  }

  Future<void> setAppearanceMode(AppearanceMode mode) async {
    state = state.copyWith(appearance: mode);
    await _prefs.setString(_appearanceKey, mode.storageKey);
    // Keep legacy key updated for backwards compatibility
    await _prefs.setString(_legacyModeKey, mode.storageKey);
  }

  /// Backward-compatible setter using Flutter's ThemeMode
  Future<void> setThemeMode(ThemeMode mode) async {
    switch (mode) {
      case ThemeMode.light:
        await setAppearanceMode(AppearanceMode.light);
        break;
      case ThemeMode.dark:
        await setAppearanceMode(AppearanceMode.dark);
        break;
      case ThemeMode.system:
        await setAppearanceMode(AppearanceMode.system);
        break;
    }
  }
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeSettingsNotifier(prefs);
});

final themeFamilyProvider = Provider<ThemeFamily>((ref) {
  return ref.watch(themeSettingsProvider).family;
});

final appearanceModeProvider = Provider<AppearanceMode>((ref) {
  return ref.watch(themeSettingsProvider).appearance;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeSettingsProvider).appearance.toThemeMode();
});

