import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.selection,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.tagBackground,
    required this.tagText,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color selection;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color tagBackground;
  final Color tagText;
  final Color success;
  final Color warning;
  final Color error;

  static const light = AppColors(
    background: Color(0xFFF7F6F2),
    surface: Color(0xFFFBFAF7),
    elevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF292824),
    textSecondary: Color(0xFF77736C),
    textTertiary: Color(0xFFA6A29B),
    divider: Color(0xFFE8E5DF),
    selection: Color(0xFFE8DDD9),
    accent: Color(0xFFD65F55),
    accentDark: Color(0xFFB94B43),
    accentSoft: Color(0xFFF1DAD6),
    tagBackground: Color(0xFFECE9E3),
    tagText: Color(0xFF68645D),
    success: Color(0xFF6F9275),
    warning: Color(0xFFC18A4A),
    error: Color(0xFFC95D57),
  );

  static const dark = AppColors(
    background: Color(0xFF1D1C1A),
    surface: Color(0xFF242320),
    elevated: Color(0xFF2B2926),
    textPrimary: Color(0xFFE8E5DE),
    textSecondary: Color(0xFFAAA69E),
    textTertiary: Color(0xFF77736C),
    divider: Color(0xFF37342F),
    selection: Color(0xFF463A36),
    accent: Color(0xFFE4776D),
    accentDark: Color(0xFFD26259),
    accentSoft: Color(0xFF3D2926),
    tagBackground: Color(0xFF302E2A),
    tagText: Color(0xFFB8B3AA),
    success: Color(0xFF86A88A),
    warning: Color(0xFFD09A58),
    error: Color(0xFFDF7169),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? selection,
    Color? accent,
    Color? accentDark,
    Color? accentSoft,
    Color? tagBackground,
    Color? tagText,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      selection: selection ?? this.selection,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentSoft: accentSoft ?? this.accentSoft,
      tagBackground: tagBackground ?? this.tagBackground,
      tagText: tagText ?? this.tagText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      tagBackground: Color.lerp(tagBackground, other.tagBackground, t)!,
      tagText: Color.lerp(tagText, other.tagText, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension BuildContextAppColors on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
