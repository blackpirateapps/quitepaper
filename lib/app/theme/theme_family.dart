import 'package:flutter/material.dart';

/// Available Theme Families for Quiet Paper.
enum ThemeFamily {
  classicPaper('classic_paper', 'Classic Paper', 'Soft paper editorial tones with warm terracotta coral accent.'),
  warmPaper('warm_paper', 'Warm Paper', 'Cozy warm ivory & midnight slate with serene slate blue accent.');

  const ThemeFamily(this.storageKey, this.displayName, this.description);

  final String storageKey;
  final String displayName;
  final String description;

  static ThemeFamily fromString(String? key) {
    if (key == 'warm_paper' || key == 'warmPaper') {
      return ThemeFamily.warmPaper;
    }
    return ThemeFamily.classicPaper;
  }
}

/// Appearance brightness preference mode.
enum AppearanceMode {
  system('system', 'System Default', Icons.brightness_auto_rounded),
  light('light', 'Light', Icons.light_mode_outlined),
  dark('dark', 'Dark', Icons.dark_mode_outlined);

  const AppearanceMode(this.storageKey, this.displayName, this.icon);

  final String storageKey;
  final String displayName;
  final IconData icon;

  static AppearanceMode fromString(String? key) {
    switch (key) {
      case 'light':
        return AppearanceMode.light;
      case 'dark':
        return AppearanceMode.dark;
      default:
        return AppearanceMode.system;
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppearanceMode.light:
        return ThemeMode.light;
      case AppearanceMode.dark:
        return ThemeMode.dark;
      case AppearanceMode.system:
        return ThemeMode.system;
    }
  }
}

/// Fully resolved concrete theme definition.
enum ResolvedTheme {
  classicPaperLight('Classic Paper Light', false),
  classicPaperDark('Classic Paper Dark', true),
  warmPaperLight('Warm Paper Light', false),
  midnightPaper('Midnight Paper', true);

  const ResolvedTheme(this.displayName, this.isDark);

  final String displayName;
  final bool isDark;
}
