import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import '../fonts/font_cache_manager.dart';

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

  /// Loads binary [ByteData] for an asset from `rootBundle`, FontCacheManager, or file system fallback.
  static Future<ByteData> loadAssetByteData(String assetPath) async {
    if (_byteDataCache.containsKey(assetPath)) {
      return _byteDataCache[assetPath]!;
    }

    // 1. Try FontCacheManager local disk storage
    final filename = p.basenameWithoutExtension(assetPath);
    final parts = filename.split('-');
    final family = parts.first;
    final variant = parts.length > 1 ? parts.last.toLowerCase() : 'regular';

    final cachedFile = FontCacheManager.instance.getCachedFontFile(family, variant: variant);
    if (cachedFile != null && cachedFile.existsSync()) {
      final bytes = await cachedFile.readAsBytes();
      final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
      _byteDataCache[assetPath] = data;
      return data;
    }

    // 2. Try rootBundle (Flutter app runtime if assets are bundled)
    try {
      final data = await rootBundle.load(assetPath);
      _byteDataCache[assetPath] = data;
      return data;
    } catch (_) {}

    // 3. Try file system fallback for pure CLI unit tests and backend paths
    final candidatePaths = [
      assetPath,
      'backend/public/fonts/$family/$filename.ttf',
      'backend/public/fonts/$family/$filename.otf',
      'backend/public/fonts/$filename.ttf',
      'backend/public/fonts/$filename.otf',
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
  /// Defaults to embedded TrueType fonts if available, and gracefully falls back to standard PDF fonts.
  static Future<PdfTypographyTheme> resolveTypographyTheme({
    String? requestedBodyFamily,
    String? requestedCodeFamily,
  }) async {
    final isSerif = requestedBodyFamily?.toLowerCase() == 'lora' ||
        requestedBodyFamily?.toLowerCase() == 'merriweather' ||
        requestedBodyFamily?.toLowerCase() == 'serif';

    // Determine body font asset family
    String bodyPrefix;
    switch (requestedBodyFamily?.toLowerCase()) {
      case 'san francisco':
      case 'sf pro':
      case 'sanfrancisco':
        bodyPrefix = 'SanFrancisco';
        break;
      case 'roboto':
        bodyPrefix = 'Roboto';
        break;
      case 'lora':
        bodyPrefix = 'Lora';
        break;
      case 'merriweather':
        bodyPrefix = 'Merriweather';
        break;
      case 'open sans':
      case 'opensans':
        bodyPrefix = 'OpenSans';
        break;
      case 'lato':
        bodyPrefix = 'Lato';
        break;
      case 'ia writer quattro':
      case 'iawriterquattro':
      case 'quattro':
        bodyPrefix = 'iAWriterQuattro';
        break;
      case 'inter':
      default:
        bodyPrefix = 'Inter';
        break;
    }

    // Determine monospace code font asset family
    String codePrefix;
    switch (requestedCodeFamily?.toLowerCase()) {
      case 'fira code':
      case 'firacode':
        codePrefix = 'FiraCode';
        break;
      case 'ia writer quattro':
      case 'iawriterquattro':
      case 'quattro':
        codePrefix = 'iAWriterQuattro';
        break;
      case 'jetbrains mono':
      case 'jetbrainsmono':
      default:
        codePrefix = 'JetBrainsMono';
        break;
    }

    // 1. Resolve Body Regular
    pw.Font? bodyRegular = await loadFontOrNull('$bodyPrefix-Regular.ttf');
    bodyRegular ??= await loadFontOrNull('$bodyPrefix-TextRegular.otf');
    bodyRegular ??= await loadFontOrNull('SF-Pro-Text-Regular.otf');
    bodyRegular ??= await loadFontOrNull('Inter-Regular.ttf');
    bodyRegular ??= await loadFontOrNull('Roboto-Regular.ttf');
    bodyRegular ??= (isSerif ? pw.Font.times() : pw.Font.helvetica());

    // 2. Resolve Body Bold
    pw.Font? bodyBold = await loadFontOrNull('$bodyPrefix-Bold.ttf');
    bodyBold ??= await loadFontOrNull('$bodyPrefix-TextBold.otf');
    bodyBold ??= await loadFontOrNull('SF-Pro-Text-Bold.otf');
    if (bodyBold == null && bodyPrefix != 'Roboto') {
      bodyBold = await loadFontOrNull('Roboto-Bold.ttf');
    }
    bodyBold ??= (isSerif ? pw.Font.timesBold() : pw.Font.helveticaBold());

    // 3. Resolve Body Italic
    pw.Font? bodyItalic = await loadFontOrNull('$bodyPrefix-Italic.ttf');
    bodyItalic ??= await loadFontOrNull('$bodyPrefix-TextItalic.otf');
    bodyItalic ??= await loadFontOrNull('SF-Pro-Text-RegularItalic.otf');
    bodyItalic ??= await loadFontOrNull('Inter-Italic.ttf');
    bodyItalic ??= (isSerif ? pw.Font.timesItalic() : pw.Font.helveticaOblique());

    pw.Font? bodyBoldItalic = await loadFontOrNull('$bodyPrefix-BoldItalic.ttf');
    bodyBoldItalic ??= await loadFontOrNull('$bodyPrefix-TextBoldItalic.otf');
    bodyBoldItalic ??= (isSerif ? pw.Font.timesBoldItalic() : pw.Font.helveticaBoldOblique());

    // 4. Resolve Code Regular
    pw.Font? codeRegular = await loadFontOrNull('$codePrefix-Regular.ttf');
    codeRegular ??= await loadFontOrNull('JetBrainsMono-Regular.ttf');
    codeRegular ??= await loadFontOrNull('FiraCode-Regular.ttf');
    codeRegular ??= pw.Font.courier();

    // 5. Resolve Code Bold
    pw.Font? codeBold = await loadFontOrNull('$codePrefix-Bold.ttf');
    codeBold ??= pw.Font.courierBold();

    // 6. Resolve Code Italic
    pw.Font? codeItalic = await loadFontOrNull('$codePrefix-Italic.ttf');
    codeItalic ??= await loadFontOrNull('JetBrainsMono-Italic.ttf');
    codeItalic ??= pw.Font.courierOblique();

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

