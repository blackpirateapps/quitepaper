import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import 'theme_family.dart';

/// Central theme resolver for Quiet Paper.
/// Maps user-configured [ThemeFamily] and [AppearanceMode] plus platform brightness
/// into concrete [ResolvedTheme], [AppColors], and [ThemeData].
abstract final class ThemeResolver {
  /// Resolves the concrete [ResolvedTheme] given the family, appearance mode, and OS brightness.
  static ResolvedTheme resolve({
    required ThemeFamily family,
    required AppearanceMode appearance,
    required Brightness platformBrightness,
  }) {
    final effectiveDark = appearance == AppearanceMode.dark ||
        (appearance == AppearanceMode.system &&
            platformBrightness == Brightness.dark);

    switch (family) {
      case ThemeFamily.classicPaper:
        return effectiveDark
            ? ResolvedTheme.classicPaperDark
            : ResolvedTheme.classicPaperLight;
      case ThemeFamily.warmPaper:
        return effectiveDark
            ? ResolvedTheme.midnightPaper
            : ResolvedTheme.warmPaperLight;
    }
  }

  /// Resolves the semantic [AppColors] for the given family and darkness.
  static AppColors resolveColors({
    required ThemeFamily family,
    required bool isDark,
  }) {
    switch (family) {
      case ThemeFamily.classicPaper:
        return isDark ? AppColors.classicDark : AppColors.classicLight;
      case ThemeFamily.warmPaper:
        return isDark ? AppColors.midnightPaperDark : AppColors.warmPaperLight;
    }
  }

  /// Resolves the [ThemeData] for the given family and darkness.
  static ThemeData resolveThemeData({
    required ThemeFamily family,
    required bool isDark,
  }) {
    return isDark
        ? AppTheme.dark(family: family)
        : AppTheme.light(family: family);
  }
}
