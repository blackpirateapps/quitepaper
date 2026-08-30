import 'package:flutter/material.dart';

/// Central semantic color tokens for Quiet Paper.
/// Provides complete theme tokens for all application surfaces, states, and typography.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.surfaceSubtle,
    required this.elevated,
    required this.divider,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconMuted,
    required this.selection,
    required this.focus,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.accentSoft,
    required this.scrollbar,
    required this.scrollbarActive,
    required this.sidebarBackground,
    required this.sidebarSelected,
    required this.editorBackground,
    required this.previewBackground,
    required this.codeBackground,
    required this.codeBorder,
    required this.codeText,
    required this.link,
    required this.searchHighlight,
    required this.searchHighlightActive,
    required this.tagBackground,
    required this.tagText,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  // Base Surfaces
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color surfaceSubtle;
  final Color elevated;

  // Borders & Dividers
  final Color divider;
  final Color borderSubtle;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // Icons
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconMuted;

  // Interactive & Selection
  final Color selection;
  final Color focus;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color accentSoft;

  // Scrollbar
  final Color scrollbar;
  final Color scrollbarActive;

  // 3-Pane Navigation & Sidebar
  final Color sidebarBackground;
  final Color sidebarSelected;

  // Editor & Preview
  final Color editorBackground;
  final Color previewBackground;
  final Color codeBackground;
  final Color codeBorder;
  final Color codeText;
  final Color link;
  final Color searchHighlight;
  final Color searchHighlightActive;

  // Tags & Metadata
  final Color tagBackground;
  final Color tagText;

  // Status & Feedback
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Semantic Getters
  Color get border => divider;
  Color get textMuted => textTertiary;
  Color get accentStrong => accentDark;
  Color get surfaceElevated => elevated;
  bool get isDark => background.computeLuminance() < 0.5;

  /// Readable text color placed on top of [searchHighlight].
  Color get searchHighlightText => searchHighlight.computeLuminance() > 0.4
      ? const Color(0xFF1A1810)
      : const Color(0xFFF1F2F4);

  /// Readable text color placed on top of [searchHighlightActive].
  Color get searchHighlightActiveText =>
      searchHighlightActive.computeLuminance() > 0.4
      ? const Color(0xFF1A1810)
      : const Color(0xFFF1F2F4);

  // ==========================================
  // Canonical Presets
  // ==========================================

  /// Classic Paper — Light (Preserved original aesthetic)
  static const classicLight = AppColors(
    background: Color(0xFFF7F6F2),
    surface: Color(0xFFFBFAF7),
    surfaceSecondary: Color(0xFFF2EFE9),
    surfaceSubtle: Color(0xFFECE9E3),
    elevated: Color(0xFFFFFFFF),
    divider: Color(0xFFE8E5DF),
    borderSubtle: Color(0xFFEFECE6),
    textPrimary: Color(0xFF292824),
    textSecondary: Color(0xFF77736C),
    textTertiary: Color(0xFFA6A29B),
    textDisabled: Color(0xFFBFBBB4),
    iconPrimary: Color(0xFF292824),
    iconSecondary: Color(0xFF77736C),
    iconMuted: Color(0xFFA6A29B),
    selection: Color(0xFFE8DDD9),
    focus: Color(0xFFD65F55),
    accent: Color(0xFFD65F55),
    accentLight: Color(0xFFF1DAD6),
    accentDark: Color(0xFFB94B43),
    accentSoft: Color(0xFFF1DAD6),
    scrollbar: Color(0xFFA6A29B),
    scrollbarActive: Color(0xFFD65F55),
    sidebarBackground: Color(0xFFFBFAF7),
    sidebarSelected: Color(0xFFECE9E3),
    editorBackground: Color(0xFFF7F6F2),
    previewBackground: Color(0xFFF7F6F2),
    codeBackground: Color(0xFFECE9E3),
    codeBorder: Color(0xFFE8E5DF),
    codeText: Color(0xFF292824),
    link: Color(0xFFD65F55),
    searchHighlight: Color(0xFFFFE066),
    searchHighlightActive: Color(0xFFF59E0B),
    tagBackground: Color(0xFFECE9E3),
    tagText: Color(0xFF68645D),
    success: Color(0xFF6F9275),
    warning: Color(0xFFC18A4A),
    error: Color(0xFFC95D57),
    info: Color(0xFF5B8DEF),
  );

  /// Classic Paper — Dark (Preserved original aesthetic)
  static const classicDark = AppColors(
    background: Color(0xFF1D1C1A),
    surface: Color(0xFF242320),
    surfaceSecondary: Color(0xFF201F1D),
    surfaceSubtle: Color(0xFF282724),
    elevated: Color(0xFF2B2926),
    divider: Color(0xFF37342F),
    borderSubtle: Color(0xFF2C2A26),
    textPrimary: Color(0xFFE8E5DE),
    textSecondary: Color(0xFFAAA69E),
    textTertiary: Color(0xFF77736C),
    textDisabled: Color(0xFF58554F),
    iconPrimary: Color(0xFFE8E5DE),
    iconSecondary: Color(0xFFAAA69E),
    iconMuted: Color(0xFF77736C),
    selection: Color(0xFF463A36),
    focus: Color(0xFFE4776D),
    accent: Color(0xFFE4776D),
    accentLight: Color(0xFF3D2926),
    accentDark: Color(0xFFD26259),
    accentSoft: Color(0xFF3D2926),
    scrollbar: Color(0xFF77736C),
    scrollbarActive: Color(0xFFE4776D),
    sidebarBackground: Color(0xFF1D1C1A),
    sidebarSelected: Color(0xFF302E2A),
    editorBackground: Color(0xFF1D1C1A),
    previewBackground: Color(0xFF1D1C1A),
    codeBackground: Color(0xFF242320),
    codeBorder: Color(0xFF37342F),
    codeText: Color(0xFFE8E5DE),
    link: Color(0xFFE4776D),
    searchHighlight: Color(0xFF7A5C1E),
    searchHighlightActive: Color(0xFFFBBF24),
    tagBackground: Color(0xFF302E2A),
    tagText: Color(0xFFB8B3AA),
    success: Color(0xFF86A88A),
    warning: Color(0xFFD09A58),
    error: Color(0xFFDF7169),
    info: Color(0xFF6BA3F5),
  );

  /// Backward-compatible aliases for existing references
  static const light = classicLight;
  static const dark = classicDark;

  /// Warm Paper — Light (Canonical warm editorial palette with serene slate blue accent)
  static const warmPaperLight = AppColors(
    background: Color(0xFFF2F1EE),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFFBFAF8),
    surfaceSubtle: Color(0xFFF5F4F1),
    elevated: Color(0xFFFFFFFF),
    divider: Color(0xFFE5E3DF),
    borderSubtle: Color(0xFFECEBE7),
    textPrimary: Color(0xFF202124),
    textSecondary: Color(0xFF414141),
    textTertiary: Color(0xFF777777),
    textDisabled: Color(0xFF9A9994),
    iconPrimary: Color(0xFF202124),
    iconSecondary: Color(0xFF414141),
    iconMuted: Color(0xFF777777),
    selection: Color(0xFFDBEAFE),
    focus: Color(0xFF3B82F6),
    accent: Color(0xFF3B82F6),
    accentLight: Color(0xFFDBEAFE),
    accentDark: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF6FF),
    scrollbar: Color(0xFF9DA1AA),
    scrollbarActive: Color(0xFF60646D),
    sidebarBackground: Color(0xFF202329),
    sidebarSelected: Color(0xFF353A43),
    editorBackground: Color(0xFFF2F1EE),
    previewBackground: Color(0xFFF2F1EE),
    codeBackground: Color(0xFFF5F4F1),
    codeBorder: Color(0xFFE5E3DF),
    codeText: Color(0xFF202124),
    link: Color(0xFF2563EB),
    searchHighlight: Color(0xFFFFE082),
    searchHighlightActive: Color(0xFF3B82F6),
    tagBackground: Color(0xFFF5F4F1),
    tagText: Color(0xFF414141),
    success: Color(0xFF4E9A51),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF3B82F6),
  );

  /// Midnight Paper — Dark (Canonical dark slate blue palette)
  static const midnightPaperDark = AppColors(
    background: Color(0xFF11151A),
    surface: Color(0xFF171C22),
    surfaceSecondary: Color(0xFF1D232B),
    surfaceSubtle: Color(0xFF222932),
    elevated: Color(0xFF1D232B),
    divider: Color(0xFF303741),
    borderSubtle: Color(0xFF282F3A),
    textPrimary: Color(0xFFF1F2F4),
    textSecondary: Color(0xFFC5C8CE),
    textTertiary: Color(0xFF8D939D),
    textDisabled: Color(0xFF5E6573),
    iconPrimary: Color(0xFFF1F2F4),
    iconSecondary: Color(0xFFC5C8CE),
    iconMuted: Color(0xFF8D939D),
    selection: Color(0xFF1E3A5F),
    focus: Color(0xFF60A5FA),
    accent: Color(0xFF60A5FA),
    accentLight: Color(0xFF93C5FD),
    accentDark: Color(0xFF3B82F6),
    accentSoft: Color(0xFF1E293B),
    scrollbar: Color(0xFF777D88),
    scrollbarActive: Color(0xFF93C5FD),
    sidebarBackground: Color(0xFF11151A),
    sidebarSelected: Color(0xFF1F2630),
    editorBackground: Color(0xFF11151A),
    previewBackground: Color(0xFF11151A),
    codeBackground: Color(0xFF171C22),
    codeBorder: Color(0xFF303741),
    codeText: Color(0xFFF1F2F4),
    link: Color(0xFF60A5FA),
    searchHighlight: Color(0xFF594519),
    searchHighlightActive: Color(0xFF60A5FA),
    tagBackground: Color(0xFF222932),
    tagText: Color(0xFFC5C8CE),
    success: Color(0xFF5CB85C),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF60A5FA),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? surfaceSubtle,
    Color? elevated,
    Color? divider,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? iconMuted,
    Color? selection,
    Color? focus,
    Color? accent,
    Color? accentLight,
    Color? accentDark,
    Color? accentSoft,
    Color? scrollbar,
    Color? scrollbarActive,
    Color? sidebarBackground,
    Color? sidebarSelected,
    Color? editorBackground,
    Color? previewBackground,
    Color? codeBackground,
    Color? codeBorder,
    Color? codeText,
    Color? link,
    Color? searchHighlight,
    Color? searchHighlightActive,
    Color? tagBackground,
    Color? tagText,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      elevated: elevated ?? this.elevated,
      divider: divider ?? this.divider,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconMuted: iconMuted ?? this.iconMuted,
      selection: selection ?? this.selection,
      focus: focus ?? this.focus,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDark: accentDark ?? this.accentDark,
      accentSoft: accentSoft ?? this.accentSoft,
      scrollbar: scrollbar ?? this.scrollbar,
      scrollbarActive: scrollbarActive ?? this.scrollbarActive,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      editorBackground: editorBackground ?? this.editorBackground,
      previewBackground: previewBackground ?? this.previewBackground,
      codeBackground: codeBackground ?? this.codeBackground,
      codeBorder: codeBorder ?? this.codeBorder,
      codeText: codeText ?? this.codeText,
      link: link ?? this.link,
      searchHighlight: searchHighlight ?? this.searchHighlight,
      searchHighlightActive:
          searchHighlightActive ?? this.searchHighlightActive,
      tagBackground: tagBackground ?? this.tagBackground,
      tagText: tagText ?? this.tagText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      scrollbar: Color.lerp(scrollbar, other.scrollbar, t)!,
      scrollbarActive: Color.lerp(scrollbarActive, other.scrollbarActive, t)!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      sidebarSelected: Color.lerp(sidebarSelected, other.sidebarSelected, t)!,
      editorBackground: Color.lerp(
        editorBackground,
        other.editorBackground,
        t,
      )!,
      previewBackground: Color.lerp(
        previewBackground,
        other.previewBackground,
        t,
      )!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      codeBorder: Color.lerp(codeBorder, other.codeBorder, t)!,
      codeText: Color.lerp(codeText, other.codeText, t)!,
      link: Color.lerp(link, other.link, t)!,
      searchHighlight: Color.lerp(searchHighlight, other.searchHighlight, t)!,
      searchHighlightActive: Color.lerp(
        searchHighlightActive,
        other.searchHighlightActive,
        t,
      )!,
      tagBackground: Color.lerp(tagBackground, other.tagBackground, t)!,
      tagText: Color.lerp(tagText, other.tagText, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension BuildContextAppColors on BuildContext {
  /// Resolves the current theme's [AppColors] extension.
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.classicDark
          : AppColors.classicLight);

  /// Semantic alias for [appColors].
  AppColors get quietPaperTheme => appColors;
}
