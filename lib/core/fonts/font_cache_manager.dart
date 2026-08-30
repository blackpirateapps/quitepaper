import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// Represents a specific variant of a hosted font (e.g. Regular, Italic, Bold).
@immutable
class HostedFontVariant {
  const HostedFontVariant({
    required this.variant,
    required this.weight,
    required this.style,
    required this.file,
    required this.size,
  });

  final String variant; // 'regular', 'bold', 'italic'
  final int weight; // 400, 700
  final String style; // 'normal', 'italic'
  final String file; // e.g. 'Inter/Inter-Regular.ttf'
  final int size; // bytes

  Map<String, dynamic> toJson() => {
        'variant': variant,
        'weight': weight,
        'style': style,
        'file': file,
        'size': size,
      };

  factory HostedFontVariant.fromJson(Map<String, dynamic> json) {
    return HostedFontVariant(
      variant: json['variant'] as String? ?? 'regular',
      weight: (json['weight'] as num?)?.toInt() ?? 400,
      style: json['style'] as String? ?? 'normal',
      file: json['file'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Represents a font family available for on-demand download from the backend.
@immutable
class HostedFontEntry {
  const HostedFontEntry({
    required this.family,
    required this.category,
    required this.variants,
  });

  final String family;
  final String category;
  final List<HostedFontVariant> variants;

  int get totalSize => variants.fold(0, (sum, v) => sum + v.size);

  String get formattedSize {
    final bytes = totalSize;
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  HostedFontVariant? getVariant(String variantName) {
    try {
      return variants.firstWhere(
        (v) => v.variant.toLowerCase() == variantName.toLowerCase(),
      );
    } catch (_) {
      return variants.isNotEmpty ? variants.first : null;
    }
  }

  Map<String, dynamic> toJson() => {
        'family': family,
        'category': category,
        'variants': variants.map((v) => v.toJson()).toList(),
      };

  factory HostedFontEntry.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as List<dynamic>? ?? [];
    return HostedFontEntry(
      family: json['family'] as String? ?? '',
      category: json['category'] as String? ?? 'Sans-serif',
      variants: rawVariants
          .map((e) => HostedFontVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Status of a font family in the local cache.
enum FontDownloadStatus {
  notDownloaded,
  downloading,
  cached,
  error,
}

/// Core manager for local font caching, on-demand downloading from the backend,
/// and dynamic runtime registration into Flutter's FontLoader.
class FontCacheManager {
  FontCacheManager({
    String? baseUrl,
    this.customStorageDir,
    http.Client? httpClient,
  })  : _baseUrl = (baseUrl ?? 'https://quitepaper.vercel.app')
            .trim()
            .replaceAll(RegExp(r'/+$'), ''),
        _httpClient = httpClient ?? http.Client();

  static final FontCacheManager instance = FontCacheManager();

  String _baseUrl;
  final Directory? customStorageDir;
  final http.Client _httpClient;


  final Set<String> _registeredFamilies = {};
  final Map<String, FontDownloadStatus> _downloadStatuses = {};
  Directory? _resolvedFontsDir;

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Set<String> get registeredFamilies => Set.unmodifiable(_registeredFamilies);

  /// Built-in catalog of hosted fonts available on the backend.
  static const List<HostedFontEntry> defaultHostedFonts = [
    HostedFontEntry(
      family: 'Inter',
      category: 'Sans-serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'Inter/Inter-Regular.ttf', size: 876576),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'Inter/Inter-Italic.ttf', size: 906596),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'Inter/Inter-Bold.ttf', size: 24356),
      ],
    ),
    HostedFontEntry(
      family: 'Roboto',
      category: 'Sans-serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'Roboto/Roboto-Regular.ttf', size: 515100),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'Roboto/Roboto-Italic.ttf', size: 533388),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'Roboto/Roboto-Bold.ttf', size: 514260),
      ],
    ),
    HostedFontEntry(
      family: 'Lora',
      category: 'Serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'Lora/Lora-Regular.ttf', size: 212196),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'Lora/Lora-Italic.ttf', size: 221232),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'Lora/Lora-Bold.ttf', size: 21044),
      ],
    ),
    HostedFontEntry(
      family: 'Merriweather',
      category: 'Serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'Merriweather/Merriweather-Regular.ttf', size: 4628080),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'Merriweather/Merriweather-Italic.ttf', size: 4591168),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'Merriweather/Merriweather-Bold.ttf', size: 48660),
      ],
    ),
    HostedFontEntry(
      family: 'Open Sans',
      category: 'Sans-serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'OpenSans/OpenSans-Regular.ttf', size: 532636),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'OpenSans/OpenSans-Italic.ttf', size: 583992),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'OpenSans/OpenSans-Bold.ttf', size: 18204),
      ],
    ),
    HostedFontEntry(
      family: 'Lato',
      category: 'Sans-serif',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'Lato/Lato-Regular.ttf', size: 656568),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'Lato/Lato-Italic.ttf', size: 722900),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'Lato/Lato-Bold.ttf', size: 656544),
      ],
    ),
    HostedFontEntry(
      family: 'JetBrains Mono',
      category: 'Monospace',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'JetBrainsMono/JetBrainsMono-Regular.ttf', size: 187208),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'JetBrainsMono/JetBrainsMono-Italic.ttf', size: 191556),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'JetBrainsMono/JetBrainsMono-Bold.ttf', size: 21908),
      ],
    ),
    HostedFontEntry(
      family: 'Fira Code',
      category: 'Monospace',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'FiraCode/FiraCode-Regular.ttf', size: 260364),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'FiraCode/FiraCode-Bold.ttf', size: 23040),
      ],
    ),
    HostedFontEntry(
      family: 'San Francisco',
      category: 'Sans-serif',
      variants: [
        HostedFontVariant(variant: 'displayRegular', weight: 400, style: 'normal', file: 'SanFrancisco/SF-Pro-Display-Regular.otf', size: 298944),
        HostedFontVariant(variant: 'displayBold', weight: 700, style: 'normal', file: 'SanFrancisco/SF-Pro-Display-Bold.otf', size: 334728),
        HostedFontVariant(variant: 'displayItalic', weight: 400, style: 'italic', file: 'SanFrancisco/SF-Pro-Display-RegularItalic.otf', size: 148740),
        HostedFontVariant(variant: 'textRegular', weight: 400, style: 'normal', file: 'SanFrancisco/SF-Pro-Text-Regular.otf', size: 310148),
        HostedFontVariant(variant: 'textBold', weight: 700, style: 'normal', file: 'SanFrancisco/SF-Pro-Text-Bold.otf', size: 341844),
        HostedFontVariant(variant: 'textItalic', weight: 400, style: 'italic', file: 'SanFrancisco/SF-Pro-Text-RegularItalic.otf', size: 168992),
      ],
    ),
    HostedFontEntry(
      family: 'iA Writer Quattro',
      category: 'Hybrid',
      variants: [
        HostedFontVariant(variant: 'regular', weight: 400, style: 'normal', file: 'iAWriterQuattro/iAWriterQuattro-Regular.ttf', size: 119772),
        HostedFontVariant(variant: 'italic', weight: 400, style: 'italic', file: 'iAWriterQuattro/iAWriterQuattro-Italic.ttf', size: 105028),
        HostedFontVariant(variant: 'bold', weight: 700, style: 'normal', file: 'iAWriterQuattro/iAWriterQuattro-Bold.ttf', size: 120404),
        HostedFontVariant(variant: 'boldItalic', weight: 700, style: 'italic', file: 'iAWriterQuattro/iAWriterQuattro-BoldItalic.ttf', size: 104520),
      ],
    ),
  ];

  /// Resolves the local fonts storage directory.
  Future<Directory> getFontsDirectory() async {
    if (_resolvedFontsDir != null) return _resolvedFontsDir!;
    if (customStorageDir != null) {
      _resolvedFontsDir = customStorageDir;
    } else {

      try {
        final docDir = await getApplicationDocumentsDirectory();
        _resolvedFontsDir = Directory(p.join(docDir.path, 'fonts'));
      } catch (_) {
        _resolvedFontsDir = Directory('.quietpaper_fonts');
      }
    }
    if (!await _resolvedFontsDir!.exists()) {
      await _resolvedFontsDir!.create(recursive: true);
    }
    return _resolvedFontsDir!;
  }

  /// Synchronously gets the resolved directory if initialized.
  Directory? get resolvedFontsDirectory => _resolvedFontsDir;

  /// Initializes the font cache manager on application startup.
  /// Discovers and registers all locally cached fonts into Flutter's FontLoader.
  Future<void> initialize() async {
    try {
      final dir = await getFontsDirectory();
      if (!await dir.exists()) return;

      final entities = await dir.list(recursive: true).toList();
      final fontFiles = entities.whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ext == '.ttf' || ext == '.otf';
      }).toList();

      final groupedByFamily = <String, List<File>>{};
      for (final file in fontFiles) {
        final filename = p.basenameWithoutExtension(file.path);
        // Normalize name, e.g. "Inter-Regular" or "Lora-Bold" or "JetBrainsMono-Regular" or "SanFrancisco-DisplayRegular"
        final parts = filename.split('-');
        final family = _normalizeFamilyName(parts.first);
        groupedByFamily.putIfAbsent(family, () => []).add(file);
      }

      for (final entry in groupedByFamily.entries) {
        final family = entry.key;
        final files = entry.value;
        await _registerFilesIntoEngine(family, files);
        _registeredFamilies.add(family);
        _downloadStatuses[family] = FontDownloadStatus.cached;
      }
    } catch (e) {
      debugPrint('Error initializing cached fonts: $e');
    }
  }

  String _normalizeFamilyName(String raw) {
    switch (raw.toLowerCase()) {
      case 'jetbrainsmono':
        return 'JetBrains Mono';
      case 'firacode':
        return 'Fira Code';
      case 'opensans':
        return 'Open Sans';
      case 'sanfrancisco':
      case 'sfpro':
      case 'sfprodisplay':
      case 'sfprotext':
      case 'sf':
        return 'San Francisco';
      case 'iawriterquattro':
      case 'iawriterquattros':
      case 'quattro':
        return 'iA Writer Quattro';
      default:
        return raw;
    }
  }

  String _sanitizeFileName(String family, String variant, {String ext = '.ttf'}) {
    final cleanFamily = family.replaceAll(' ', '');
    final cleanVariant = variant.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final capitalized = cleanVariant.isNotEmpty
        ? cleanVariant[0].toUpperCase() + cleanVariant.substring(1)
        : 'Regular';
    final cleanExt = ext.startsWith('.') ? ext : '.$ext';
    return '$cleanFamily-$capitalized$cleanExt';
  }

  /// Checks if a font family is cached locally on disk.
  bool isFontCached(String family) {
    if (_registeredFamilies.contains(family)) return true;
    final dir = _resolvedFontsDir ?? customStorageDir;
    if (dir == null) return false;
    if (family.toLowerCase() == 'san francisco' || family.toLowerCase() == 'sf pro') {
      final sfDisplay = File(p.join(dir.path, _sanitizeFileName('San Francisco', 'displayRegular', ext: '.otf')));
      final sfText = File(p.join(dir.path, _sanitizeFileName('San Francisco', 'textRegular', ext: '.otf')));
      final sfDisplayAlt = File(p.join(dir.path, 'SanFrancisco-DisplayRegular.otf'));
      final sfTextAlt = File(p.join(dir.path, 'SanFrancisco-TextRegular.otf'));
      return (sfDisplay.existsSync() || sfDisplayAlt.existsSync()) &&
             (sfText.existsSync() || sfTextAlt.existsSync());
    }
    if (family.toLowerCase() == 'ia writer quattro' || family.toLowerCase() == 'quattro') {
      final qReg = File(p.join(dir.path, _sanitizeFileName('iA Writer Quattro', 'regular', ext: '.ttf')));
      final qRegAlt = File(p.join(dir.path, 'iAWriterQuattro-Regular.ttf'));
      final qRegS = File(p.join(dir.path, 'iAWriterQuattroS-Regular.ttf'));
      return qReg.existsSync() || qRegAlt.existsSync() || qRegS.existsSync();
    }
    final regularTtf = File(p.join(dir.path, _sanitizeFileName(family, 'regular', ext: '.ttf')));
    final regularOtf = File(p.join(dir.path, _sanitizeFileName(family, 'regular', ext: '.otf')));
    return regularTtf.existsSync() || regularOtf.existsSync();
  }

  /// Returns the download status of a font family.
  FontDownloadStatus getStatus(String family) {
    if (_downloadStatuses.containsKey(family)) {
      return _downloadStatuses[family]!;
    }
    if (isFontCached(family)) {
      return FontDownloadStatus.cached;
    }
    return FontDownloadStatus.notDownloaded;
  }

  HostedFontEntry? findHostedFont(String family) {
    try {
      return defaultHostedFonts.firstWhere(
        (f) => f.family.toLowerCase() == family.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the cached TrueType font file on local disk, if present.
  File? getCachedFontFile(String family, {String variant = 'regular'}) {
    final dir = _resolvedFontsDir ?? customStorageDir;
    if (dir == null) return null;

    for (final ext in ['.ttf', '.otf']) {
      final candidate = File(p.join(dir.path, _sanitizeFileName(family, variant, ext: ext)));
      if (candidate.existsSync()) return candidate;

      // Try alternate subdirectory structure
      final subCandidate = File(p.join(dir.path, family.replaceAll(' ', ''), '$family-$variant$ext'));
      if (subCandidate.existsSync()) return subCandidate;

      final fallbackRegular = File(p.join(dir.path, _sanitizeFileName(family, 'regular', ext: ext)));
      if (fallbackRegular.existsSync()) return fallbackRegular;
    }

    if (family.toLowerCase() == 'san francisco' || family.toLowerCase() == 'sf pro') {
      final isDisplay = variant.toLowerCase().contains('display');
      final isBold = variant.toLowerCase().contains('bold');
      final isItalic = variant.toLowerCase().contains('italic');

      String targetVariant;
      if (isDisplay) {
        if (isBold) {
          targetVariant = 'DisplayBold';
        } else if (isItalic) {
          targetVariant = 'DisplayItalic';
        } else {
          targetVariant = 'DisplayRegular';
        }
      } else {
        if (isBold) {
          targetVariant = 'TextBold';
        } else if (isItalic) {
          targetVariant = 'TextItalic';
        } else {
          targetVariant = 'TextRegular';
        }
      }
      final sfFile = File(p.join(dir.path, 'SanFrancisco-$targetVariant.otf'));
      if (sfFile.existsSync()) return sfFile;
    }

    if (family.toLowerCase() == 'ia writer quattro' || family.toLowerCase() == 'quattro') {
      final isBold = variant.toLowerCase().contains('bold');
      final isItalic = variant.toLowerCase().contains('italic');
      String variantName;
      if (isBold && isItalic) {
        variantName = 'BoldItalic';
      } else if (isBold) {
        variantName = 'Bold';
      } else if (isItalic) {
        variantName = 'Italic';
      } else {
        variantName = 'Regular';
      }
      for (final name in [
        'iAWriterQuattro-$variantName.ttf',
        'iAWriterQuattroS-$variantName.ttf',
        'iAWriterQuattro-Regular.ttf',
        'iAWriterQuattroS-Regular.ttf',
      ]) {
        final f = File(p.join(dir.path, name));
        if (f.existsSync()) return f;
      }
    }

    return null;
  }

  /// Retrieves the ByteData of a cached font on disk.
  Future<ByteData?> getCachedFontByteData(String family, {String variant = 'regular'}) async {
    final file = getCachedFontFile(family, variant: variant);
    if (file == null) return null;
    try {
      final bytes = await file.readAsBytes();
      return ByteData.view(bytes.buffer);
    } catch (_) {
      return null;
    }
  }

  /// Downloads all variants for [family] from the backend, caches them on disk,
  /// and dynamically registers the font into Flutter's FontLoader.
  Future<bool> downloadAndRegisterFont(
    String family, {
    void Function(double progress)? onProgress,
  }) async {
    if (_registeredFamilies.contains(family)) {
      onProgress?.call(1.0);
      return true;
    }

    final entry = findHostedFont(family);
    if (entry == null) {
      // Not in hosted catalog, attempt fallback to Google Fonts
      return false;
    }

    _downloadStatuses[family] = FontDownloadStatus.downloading;
    onProgress?.call(0.05);

    try {
      final dir = await getFontsDirectory();
      final downloadedFiles = <File>[];
      final totalVariants = entry.variants.length;
      var completedVariants = 0;

      for (final variant in entry.variants) {
        final ext = p.extension(variant.file).isNotEmpty ? p.extension(variant.file) : '.ttf';
        final targetFileName = _sanitizeFileName(family, variant.variant, ext: ext);
        final targetFile = File(p.join(dir.path, targetFileName));

        if (!await targetFile.exists()) {
          final url = Uri.parse('$_baseUrl/fonts/${variant.file}');
          final response = await _httpClient.get(url).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            await targetFile.writeAsBytes(response.bodyBytes, flush: true);
            downloadedFiles.add(targetFile);
          } else {
            throw HttpException(
              'Failed to download font ${variant.file}: HTTP ${response.statusCode}',
              uri: url,
            );
          }
        } else {
          downloadedFiles.add(targetFile);
        }

        completedVariants++;
        onProgress?.call(completedVariants / totalVariants);
      }

      // Register all variant binaries into Flutter engine
      await _registerFilesIntoEngine(family, downloadedFiles);
      _registeredFamilies.add(family);
      _downloadStatuses[family] = FontDownloadStatus.cached;
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      debugPrint('Failed to download font $family: $e');
      _downloadStatuses[family] = FontDownloadStatus.error;
      return false;
    }
  }

  /// Registers a list of font files into Flutter's FontLoader under [family].
  Future<void> _registerFilesIntoEngine(String family, List<File> files) async {
    if (files.isEmpty) return;
    try {
      if (family.toLowerCase() == 'san francisco' ||
          family.toLowerCase() == 'sf pro' ||
          family.toLowerCase() == 'sanfrancisco') {
        final displayFiles = files.where((f) {
          final name = p.basename(f.path).toLowerCase();
          return name.contains('display');
        }).toList();
        final textFiles = files.where((f) {
          final name = p.basename(f.path).toLowerCase();
          return name.contains('text') || !name.contains('display');
        }).toList();

        if (displayFiles.isNotEmpty) {
          final displayLoader = FontLoader('SF Pro Display');
          for (final file in displayFiles) {
            final bytes = await file.readAsBytes();
            displayLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
          }
          await displayLoader.load();
          _registeredFamilies.add('SF Pro Display');
          _registeredFamilies.add('San Francisco Display');
        }

        if (textFiles.isNotEmpty) {
          final textLoader = FontLoader('SF Pro Text');
          for (final file in textFiles) {
            final bytes = await file.readAsBytes();
            textLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
          }
          await textLoader.load();

          final sfLoader = FontLoader('San Francisco');
          for (final file in textFiles) {
            final bytes = await file.readAsBytes();
            sfLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
          }
          await sfLoader.load();

          _registeredFamilies.add('SF Pro Text');
          _registeredFamilies.add('San Francisco Text');
          _registeredFamilies.add('San Francisco');
          _registeredFamilies.add('SF Pro');
        }
        return;
      }

      if (family.toLowerCase() == 'ia writer quattro' ||
          family.toLowerCase() == 'iawriterquattro' ||
          family.toLowerCase() == 'quattro') {
        final quattroLoader = FontLoader('iA Writer Quattro');
        for (final file in files) {
          final bytes = await file.readAsBytes();
          quattroLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        }
        await quattroLoader.load();

        final aliasLoader = FontLoader('Quattro');
        for (final file in files) {
          final bytes = await file.readAsBytes();
          aliasLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        }
        await aliasLoader.load();

        _registeredFamilies.add('iA Writer Quattro');
        _registeredFamilies.add('Quattro');
        return;
      }

      final fontLoader = FontLoader(family);
      for (final file in files) {
        final bytes = await file.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await fontLoader.load();
    } catch (e) {
      debugPrint('FontLoader registration error for $family: $e');
    }
  }

  /// Registers a custom user font directly from a local file path.
  Future<String?> loadCustomFontFromFile(String filePath, {String? fontName}) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) return null;

      final family = fontName ??
          p.basenameWithoutExtension(filePath).replaceAll(RegExp(r'\.[^.]+$'), '');

      final dir = await getFontsDirectory();
      final destination = File(p.join(dir.path, '$family.ttf'));
      await sourceFile.copy(destination.path);

      await _registerFilesIntoEngine(family, [destination]);
      _registeredFamilies.add(family);
      _downloadStatuses[family] = FontDownloadStatus.cached;
      return family;
    } catch (e) {
      debugPrint('Failed to load custom font file: $e');
      return null;
    }
  }
}

final fontCacheManagerProvider = Provider<FontCacheManager>((ref) {
  return FontCacheManager.instance;
});
