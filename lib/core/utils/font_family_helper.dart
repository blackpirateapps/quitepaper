import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../fonts/font_cache_manager.dart';

/// Bundled Bengali display font (Kalpurush, Regular-only, Bengali-only subset).
/// Always the final, always-offline resort of the Bengali fallback chain.
const String kBengaliFallbackFamily = 'Kalpurush';

/// The user-selected Bengali content font (a CDN-hosted Bengali family), or null
/// to render Bengali in the bundled [kBengaliFallbackFamily] only. Mutated by the
/// typography notifier whenever the "Bengali font" setting loads or changes.
String? _activeBengaliContentFont;

/// Sets the active user-selected Bengali content font. Pass null/empty (or the
/// bundled family itself) to clear it and fall back to bundled Kalpurush only.
void setActiveBengaliContentFont(String? family) {
  final clean = (family == null || family.trim().isEmpty) ? null : family.trim();
  _activeBengaliContentFont = (clean == kBengaliFallbackFamily) ? null : clean;
}

/// The active user-selected Bengali content font, or null when using Kalpurush.
String? get activeBengaliContentFont => _activeBengaliContentFont;

/// Shared fallback chain appended to every note-content [TextStyle] so Bengali
/// runs render in the chosen Bengali font (when one is selected and loaded),
/// then fall through to the bundled Kalpurush, under any chosen Latin/code font.
List<String> get kContentFontFallback => <String>[
      ?_activeBengaliContentFont,
      kBengaliFallbackFamily,
    ];

/// Helper utility for resolving font families across backend-hosted fonts, system fonts,
/// Google Fonts, and custom user-imported fonts.
class FontFamilyHelper {
  /// Font families available on-demand from the backend.
  static const Set<String> hostedFonts = {
    'San Francisco',
    'Inter',
    'Roboto',
    'Lora',
    'Merriweather',
    'Open Sans',
    'Lato',
    'JetBrains Mono',
    'Fira Code',
    'iA Writer Quattro',
    'Quattro',
    ...bengaliFonts,
  };

  /// CDN-hosted Bengali display faces, offered as a dedicated "Bengali font"
  /// content fallback (they do not render Latin — Latin stays on the chosen
  /// Latin family). The bundled [kBengaliFallbackFamily] is the offline default.
  static const Set<String> bengaliFonts = {
    'Kolpona',
    'Byomgraphy Koushali',
    'Purno Pran',
    'Samsung Bengali',
  };

  /// Backwards-compatibility alias for hosted fonts
  static const Set<String> bundledFonts = hostedFonts;

  /// Resolves the effective font family to use for headings, titles, and display elements.
  /// When [family] is 'San Francisco' or 'SF Pro', resolves to 'SF Pro Display'.
  static String? resolveHeadingFontFamily(String? family) {
    if (family == null || family.isEmpty || family == 'System Sans') {
      return null;
    }
    final lower = family.toLowerCase().trim();
    if (lower == 'san francisco' ||
        lower == 'sf pro' ||
        lower == 'sf' ||
        lower == 'sf pro display' ||
        lower == 'san francisco display') {
      return 'SF Pro Display';
    }
    if (lower == 'ia writer quattro' ||
        lower == 'iawriterquattro' ||
        lower == 'quattro') {
      return 'iA Writer Quattro';
    }
    if (lower == 'system serif' || lower == 'serif') {
      return 'serif';
    }
    return family;
  }

  /// Resolves the effective font family to use for body text, blockquotes, lists, and tables.
  /// When [family] is 'San Francisco' or 'SF Pro', resolves to 'SF Pro Text'.
  static String? resolveBodyFontFamily(String? family) {
    if (family == null || family.isEmpty || family == 'System Sans') {
      return null;
    }
    final lower = family.toLowerCase().trim();
    if (lower == 'san francisco' ||
        lower == 'sf pro' ||
        lower == 'sf' ||
        lower == 'sf pro text' ||
        lower == 'san francisco text') {
      return 'SF Pro Text';
    }
    if (lower == 'ia writer quattro' ||
        lower == 'iawriterquattro' ||
        lower == 'quattro') {
      return 'iA Writer Quattro';
    }
    if (lower == 'system serif' || lower == 'serif') {
      return 'serif';
    }
    return family;
  }

  /// Curated list of popular Google Fonts with display names and categories.
  static const List<GoogleFontEntry> popularGoogleFonts = [
    GoogleFontEntry('Inter', 'Sans-serif'),
    GoogleFontEntry('Roboto', 'Sans-serif'),
    GoogleFontEntry('Open Sans', 'Sans-serif'),
    GoogleFontEntry('Lato', 'Sans-serif'),
    GoogleFontEntry('Poppins', 'Sans-serif'),
    GoogleFontEntry('Montserrat', 'Sans-serif'),
    GoogleFontEntry('Nunito', 'Sans-serif'),
    GoogleFontEntry('Raleway', 'Sans-serif'),
    GoogleFontEntry('Ubuntu', 'Sans-serif'),
    GoogleFontEntry('Work Sans', 'Sans-serif'),
    GoogleFontEntry('DM Sans', 'Sans-serif'),
    GoogleFontEntry('Rubik', 'Sans-serif'),
    GoogleFontEntry('Plus Jakarta Sans', 'Sans-serif'),
    GoogleFontEntry('Source Sans 3', 'Sans-serif'),
    GoogleFontEntry('Lora', 'Serif'),
    GoogleFontEntry('Merriweather', 'Serif'),
    GoogleFontEntry('Playfair Display', 'Serif'),
    GoogleFontEntry('PT Serif', 'Serif'),
    GoogleFontEntry('Source Serif 4', 'Serif'),
    GoogleFontEntry('EB Garamond', 'Serif'),
    GoogleFontEntry('Cinzel', 'Serif'),
    GoogleFontEntry('Bitter', 'Serif'),
    GoogleFontEntry('Cormorant Garamond', 'Serif'),
    GoogleFontEntry('Bodoni Moda', 'Serif'),
    GoogleFontEntry('Fraunces', 'Serif'),
    GoogleFontEntry('Newsreader', 'Serif'),
    GoogleFontEntry('JetBrains Mono', 'Monospace'),
    GoogleFontEntry('Fira Code', 'Monospace'),
    GoogleFontEntry('Source Code Pro', 'Monospace'),
    GoogleFontEntry('Inconsolata', 'Monospace'),
    GoogleFontEntry('Roboto Mono', 'Monospace'),
    GoogleFontEntry('Space Mono', 'Monospace'),
    GoogleFontEntry('Courier Prime', 'Monospace'),
    GoogleFontEntry('IBM Plex Mono', 'Monospace'),
    GoogleFontEntry('Dancing Script', 'Handwriting'),
    GoogleFontEntry('Caveat', 'Handwriting'),
    GoogleFontEntry('Pacifico', 'Handwriting'),
    GoogleFontEntry('Great Vibes', 'Handwriting'),
    GoogleFontEntry('Satisfy', 'Handwriting'),
    GoogleFontEntry('Oswald', 'Display'),
    GoogleFontEntry('Bebas Neue', 'Display'),
    GoogleFontEntry('Cinzel Decorative', 'Display'),
    GoogleFontEntry('Abril Fatface', 'Display'),
    GoogleFontEntry('Comfortaa', 'Display'),
    GoogleFontEntry('Lobster', 'Display'),
  ];

  /// Resolves an effective [TextStyle] with the requested [fontFamily].
  ///
  /// Every return path carries [kContentFontFallback] so Bengali runs fall
  /// through to Kalpurush under whatever Latin/code family is chosen.
  static TextStyle getTextStyle({
    required String? fontFamily,
    required TextStyle baseStyle,
  }) {
    return _withBengaliFallback(
      _resolveTextStyle(fontFamily: fontFamily, baseStyle: baseStyle),
    );
  }

  /// Appends [kBengaliFallbackFamily] to [style]'s existing fallback chain
  /// (idempotent — a style already carrying Kalpurush is returned unchanged).
  static TextStyle _withBengaliFallback(TextStyle style) {
    final existing = style.fontFamilyFallback;
    if (existing != null && existing.contains(kBengaliFallbackFamily)) {
      return style;
    }
    return style.copyWith(
      fontFamilyFallback: <String>[
        ...?existing,
        ...kContentFontFallback,
      ],
    );
  }

  static TextStyle _resolveTextStyle({
    required String? fontFamily,
    required TextStyle baseStyle,
  }) {
    if (fontFamily == null || fontFamily.isEmpty || fontFamily == 'System Sans') {
      return baseStyle;
    }
    if (fontFamily == 'System Serif' || fontFamily == 'serif') {
      return baseStyle.copyWith(fontFamily: 'serif');
    }
    if (fontFamily == 'Monospace' || fontFamily == 'monospace') {
      return baseStyle.copyWith(fontFamily: 'monospace');
    }

    final lower = fontFamily.toLowerCase().trim();
    if (lower == 'san francisco' || lower == 'sf pro') {
      if (FontCacheManager.instance.registeredFamilies.contains('SF Pro Text') ||
          FontCacheManager.instance.isFontCached('San Francisco')) {
        return baseStyle.copyWith(fontFamily: 'SF Pro Text');
      }
    }

    if (lower == 'ia writer quattro' || lower == 'quattro') {
      if (FontCacheManager.instance.registeredFamilies.contains('iA Writer Quattro') ||
          FontCacheManager.instance.registeredFamilies.contains('Quattro') ||
          FontCacheManager.instance.isFontCached('iA Writer Quattro')) {
        return baseStyle.copyWith(fontFamily: 'iA Writer Quattro');
      }
    }

    if (FontCacheManager.instance.registeredFamilies.contains(fontFamily) ||
        FontCacheManager.instance.isFontCached(fontFamily)) {
      return baseStyle.copyWith(fontFamily: fontFamily);
    }
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: baseStyle);
    } catch (_) {
      return baseStyle.copyWith(fontFamily: fontFamily);
    }
  }
}


class GoogleFontEntry {
  const GoogleFontEntry(this.name, this.category);
  final String name;
  final String category;
}
