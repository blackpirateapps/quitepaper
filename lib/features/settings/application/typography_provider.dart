import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/typography_settings.dart';
import 'settings_provider.dart';

/// Available curated font presets for convenient selection.
class CuratedFonts {
  static const systemSans = 'System Sans';
  static const systemSerif = 'System Serif';
  static const systemMono = 'Monospace';

  static const List<String> headingPresets = [
    'System Sans',
    'System Serif',
    'Inter',
    'Roboto',
    'Lora',
    'Merriweather',
    'Playfair Display',
    'Poppins',
    'Montserrat',
    'Source Serif 4',
  ];

  static const List<String> bodyPresets = [
    'System Sans',
    'System Serif',
    'Inter',
    'Roboto',
    'Lora',
    'Merriweather',
    'Open Sans',
    'Lato',
    'Source Sans 3',
    'Source Serif 4',
  ];

  static const List<String> codePresets = [
    'Monospace',
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Inconsolata',
    'Roboto Mono',
    'Courier Prime',
  ];
}

class TypographySettingsNotifier extends StateNotifier<TypographySettings> {
  TypographySettingsNotifier([this._prefs]) : super(_loadInitialSettings(_prefs)) {
    _initCustomFonts();
  }

  final SharedPreferences? _prefs;
  static const String _key = 'typography_settings_v1';
  static final Set<String> _loadedFontFamilies = {};

  static TypographySettings _loadInitialSettings(SharedPreferences? prefs) {
    if (prefs == null) return TypographySettings.defaultSettings;
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) {
      return TypographySettings.defaultSettings;
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TypographySettings.fromJson(map);
    } catch (e) {
      debugPrint('Error loading typography settings: $e');
      return TypographySettings.defaultSettings;
    }
  }

  Future<void> _persist(TypographySettings settings) async {
    state = settings;
    if (_prefs != null) {
      try {
        final jsonStr = jsonEncode(settings.toJson());
        await _prefs.setString(_key, jsonStr);
      } catch (e) {
        debugPrint('Error saving typography settings: $e');
      }
    }
  }

  void _initCustomFonts() {
    // If any custom font paths were previously persisted in SharedPreferences or app documents, re-register them
    if (_prefs == null) return;
    for (final fontName in state.customFonts) {
      final savedPath = _prefs.getString('custom_font_path_$fontName');
      if (savedPath != null) {
        final file = File(savedPath);
        if (file.existsSync()) {
          loadCustomFontFromFile(savedPath, fontName: fontName);
        }
      }
    }
  }

  Future<void> setHeadingFontFamily(String? family) async {
    final clean = (family == null || family == CuratedFonts.systemSans)
        ? null
        : (family == CuratedFonts.systemSerif ? 'serif' : family);
    await _persist(state.copyWith(
      headingFontFamily: clean,
      clearHeadingFont: clean == null,
    ));
  }

  Future<void> setBodyFontFamily(String? family) async {
    final clean = (family == null || family == CuratedFonts.systemSans)
        ? null
        : (family == CuratedFonts.systemSerif ? 'serif' : family);
    await _persist(state.copyWith(
      bodyFontFamily: clean,
      clearBodyFont: clean == null,
    ));
  }

  Future<void> setCodeFontFamily(String? family) async {
    final clean = (family == null || family == CuratedFonts.systemMono)
        ? 'monospace'
        : family;
    await _persist(state.copyWith(
      codeFontFamily: clean,
      clearCodeFont: clean == 'monospace',
    ));
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(12.0, 32.0);
    await _persist(state.copyWith(fontSize: clamped));
  }

  Future<void> setLineHeight(double height) async {
    final clamped = height.clamp(1.0, 2.5);
    await _persist(state.copyWith(lineHeight: clamped));
  }

  Future<void> setLetterSpacing(double spacing) async {
    final clamped = spacing.clamp(-1.0, 2.0);
    await _persist(state.copyWith(letterSpacing: clamped));
  }

  Future<void> setParagraphWidth(ParagraphWidth width) async {
    await _persist(state.copyWith(paragraphWidth: width));
  }

  Future<void> setParagraphIndent(double indent) async {
    final clamped = indent.clamp(0.0, 40.0);
    await _persist(state.copyWith(paragraphIndent: clamped));
  }

  /// Dynamically loads a custom `.ttf` or `.otf` font from local disk into Flutter's FontLoader.
  Future<String?> loadCustomFontFromFile(
    String filePath, {
    String? fontName,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final family = fontName ??
          file.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '');

      if (_loadedFontFamilies.contains(family)) {
        return family;
      }

      final bytes = await file.readAsBytes();
      final fontLoader = FontLoader(family);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
      _loadedFontFamilies.add(family);

      final updatedCustomFonts = List<String>.from(state.customFonts);
      if (!updatedCustomFonts.contains(family)) {
        updatedCustomFonts.add(family);
      }
      await _prefs?.setString('custom_font_path_$family', filePath);
      await _persist(state.copyWith(customFonts: updatedCustomFonts));

      return family;
    } catch (e) {
      debugPrint('Failed to load custom font from file: $e');
      return null;
    }
  }

  /// Downloads and registers a font dynamically from Google Fonts or public web font CDN.
  Future<bool> fetchGoogleFont(String fontName) async {
    try {
      if (_loadedFontFamilies.contains(fontName)) return true;

      // Download from Google Fonts TTF repository
      final sanitized = fontName.replaceAll(' ', '+');
      final url = Uri.parse(
        'https://fonts.googleapis.com/css2?family=$sanitized:wght@400;700&display=swap',
      );

      final cssResponse = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (cssResponse.statusCode == 200) {
        final fontUrlMatch = RegExp(r'url\((https://[^)]+)\)').firstMatch(cssResponse.body);
        if (fontUrlMatch != null) {
          final downloadUrl = fontUrlMatch.group(1)!;
          final fontResponse = await http
              .get(Uri.parse(downloadUrl))
              .timeout(const Duration(seconds: 10));

          if (fontResponse.statusCode == 200) {
            final fontLoader = FontLoader(fontName);
            fontLoader.addFont(
              Future.value(ByteData.view(fontResponse.bodyBytes.buffer)),
            );
            await fontLoader.load();
            _loadedFontFamilies.add(fontName);

            final updatedCustomFonts = List<String>.from(state.customFonts);
            if (!updatedCustomFonts.contains(fontName)) {
              updatedCustomFonts.add(fontName);
            }
            await _persist(state.copyWith(customFonts: updatedCustomFonts));
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error fetching Google Font $fontName: $e');
      return false;
    }
  }

  /// Resets all typography preferences to factory defaults.
  Future<void> resetToDefault() async {
    await _persist(TypographySettings.defaultSettings.copyWith(
      customFonts: state.customFonts,
    ));
  }
}

final typographySettingsProvider =
    StateNotifierProvider<TypographySettingsNotifier, TypographySettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // If not provided in a test scope, fallback to in-memory defaults
  }
  return TypographySettingsNotifier(prefs);
});
