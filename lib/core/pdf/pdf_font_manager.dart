import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled typography theme holding resolved embedded TrueType [pw.Font] instances.
class PdfTypographyTheme {
  const PdfTypographyTheme({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.mono,
    required this.monoBold,
    required this.monoItalic,
    required this.themeData,
    this.fontFamilyName = 'Inter',
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;
  final pw.Font mono;
  final pw.Font monoBold;
  final pw.Font monoItalic;
  final pw.ThemeData themeData;
  final String fontFamilyName;
}

/// Manager for loading, caching, and fallback resolution of embedded TrueType fonts.
class PdfFontManager {
  static final Map<String, ByteData> _byteDataCache = {};
  static final Map<String, pw.Font> _fontCache = {};

  /// Checks whether [bytes] is a genuine TrueType or OpenType font (not WOFF/WOFF2).
  static bool isTrueTypeFont(ByteData bytes) {
    if (bytes.lengthInBytes < 4) return false;
    final b0 = bytes.getUint8(0);
    final b1 = bytes.getUint8(1);
    final b2 = bytes.getUint8(2);
    final b3 = bytes.getUint8(3);

    // 0x00010000 (TrueType 1.0) or 'true' (0x74727565) or 'OTTO' (0x4F54544F)
    final isTrueType1 = (b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00);
    final isTrueTypeStr = (b0 == 0x74 && b1 == 0x72 && b2 == 0x75 && b3 == 0x65);
    final isOpenType = (b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F);

    return isTrueType1 || isTrueTypeStr || isOpenType;
  }

  /// Loads binary [ByteData] for an asset from `rootBundle` or file system fallback.
  static Future<ByteData> loadAssetByteData(String assetPath) async {
    if (_byteDataCache.containsKey(assetPath)) {
      return _byteDataCache[assetPath]!;
    }

    // 1. Try rootBundle (Flutter app runtime and test widgets with assets)
    try {
      final data = await rootBundle.load(assetPath);
      _byteDataCache[assetPath] = data;
      return data;
    } catch (_) {}

    // 2. Try file system fallback for pure CLI unit tests
    final candidatePaths = [
      assetPath,
      if (!assetPath.startsWith('assets/')) 'assets/$assetPath',
      assetPath.replaceFirst(RegExp(r'^assets/'), ''),
    ];

    for (final candidate in candidatePaths) {
      final file = File(candidate);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
        _byteDataCache[assetPath] = data;
        return data;
      }
    }

    throw StateError('Could not load font asset: $assetPath');
  }

  /// Loads a [pw.Font] from the given asset path if it is a valid TrueType font.
  static Future<pw.Font?> loadFontOrNull(String assetPath) async {
    if (_fontCache.containsKey(assetPath)) {
      return _fontCache[assetPath]!;
    }
    try {
      final data = await loadAssetByteData(assetPath);
      if (!isTrueTypeFont(data)) {
        return null;
      }
      final font = pw.Font.ttf(data);
      _fontCache[assetPath] = font;
      return font;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a full [PdfTypographyTheme] for document generation.
  /// Defaults to embedded Inter (body/headings) and JetBrains Mono (code).
  static Future<PdfTypographyTheme> resolveTypographyTheme({
    String? requestedBodyFamily,
    String? requestedCodeFamily,
  }) async {
    // Determine body font asset family
    String bodyPrefix;
    switch (requestedBodyFamily?.toLowerCase()) {
      case 'roboto':
        bodyPrefix = 'assets/fonts/Roboto';
        break;
      case 'lora':
        bodyPrefix = 'assets/fonts/Lora';
        break;
      case 'merriweather':
        bodyPrefix = 'assets/fonts/Merriweather';
        break;
      case 'open sans':
      case 'opensans':
        bodyPrefix = 'assets/fonts/OpenSans';
        break;
      case 'lato':
        bodyPrefix = 'assets/fonts/Lato';
        break;
      case 'inter':
      default:
        bodyPrefix = 'assets/fonts/Inter';
        break;
    }

    // Determine monospace code font asset family
    String codePrefix;
    switch (requestedCodeFamily?.toLowerCase()) {
      case 'fira code':
      case 'firacode':
        codePrefix = 'assets/fonts/FiraCode';
        break;
      case 'jetbrains mono':
      case 'jetbrainsmono':
      default:
        codePrefix = 'assets/fonts/JetBrainsMono';
        break;
    }

    // 1. Resolve Body Regular
    pw.Font? bodyRegular = await loadFontOrNull('$bodyPrefix-Regular.ttf');
    bodyRegular ??= await loadFontOrNull('assets/fonts/Inter-Regular.ttf');
    bodyRegular ??= await loadFontOrNull('assets/fonts/Roboto-Regular.ttf');

    if (bodyRegular == null) {
      throw StateError('Failed to load any embedded TrueType body font');
    }

    // 2. Resolve Body Bold
    pw.Font? bodyBold = await loadFontOrNull('$bodyPrefix-Bold.ttf');
    if (bodyBold == null && bodyPrefix != 'assets/fonts/Roboto') {
      bodyBold = await loadFontOrNull('assets/fonts/Roboto-Bold.ttf');
    }
    bodyBold ??= bodyRegular;

    // 3. Resolve Body Italic
    pw.Font? bodyItalic = await loadFontOrNull('$bodyPrefix-Italic.ttf');
    bodyItalic ??= await loadFontOrNull('assets/fonts/Inter-Italic.ttf');
    bodyItalic ??= bodyRegular;

    final bodyBoldItalic = bodyBold;

    // 4. Resolve Code Regular
    pw.Font? codeRegular = await loadFontOrNull('$codePrefix-Regular.ttf');
    codeRegular ??= await loadFontOrNull('assets/fonts/JetBrainsMono-Regular.ttf');
    codeRegular ??= await loadFontOrNull('assets/fonts/FiraCode-Regular.ttf');
    codeRegular ??= bodyRegular;

    // 5. Resolve Code Bold
    pw.Font? codeBold = await loadFontOrNull('$codePrefix-Bold.ttf');
    codeBold ??= codeRegular;

    // 6. Resolve Code Italic
    pw.Font? codeItalic = await loadFontOrNull('$codePrefix-Italic.ttf');
    codeItalic ??= await loadFontOrNull('assets/fonts/JetBrainsMono-Italic.ttf');
    codeItalic ??= codeRegular;

    final themeData = pw.ThemeData.withFont(
      base: bodyRegular,
      bold: bodyBold,
      italic: bodyItalic,
      boldItalic: bodyBoldItalic,
      fontFallback: [bodyRegular, bodyBold, bodyItalic, codeRegular],
    );

    return PdfTypographyTheme(
      regular: bodyRegular,
      bold: bodyBold,
      italic: bodyItalic,
      boldItalic: bodyBoldItalic,
      mono: codeRegular,
      monoBold: codeBold,
      monoItalic: codeItalic,
      themeData: themeData,
      fontFamilyName: requestedBodyFamily ?? 'Inter',
    );
  }

  /// Clears the in-memory font cache (e.g. for low-memory environments).
  static void clearCache() {
    _byteDataCache.clear();
    _fontCache.clear();
  }
}
