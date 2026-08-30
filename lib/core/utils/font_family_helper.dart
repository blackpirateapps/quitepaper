import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../fonts/font_cache_manager.dart';

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
  static TextStyle getTextStyle({
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
