import 'package:flutter/foundation.dart';

/// Supported OCR recognition languages.
///
/// Designed to be extensible so future languages (e.g. Spanish, French, German)
/// can be added without restructuring database or OCR pipeline.
enum OcrLanguage {
  /// English (default and canonical for initial release).
  english('en', 'English');

  const OcrLanguage(this.code, this.displayName);

  /// Stable ISO-style language code (e.g. 'en').
  final String code;

  /// User-facing display title (e.g. 'English').
  final String displayName;

  static OcrLanguage fromCode(String? code) {
    if (code == null) return OcrLanguage.english;
    final clean = code.trim().toLowerCase();
    for (final lang in OcrLanguage.values) {
      if (lang.code == clean || lang.name.toLowerCase() == clean) {
        return lang;
      }
    }
    return OcrLanguage.english;
  }
}

/// Source method used to obtain text for a document page.
enum OcrSource {
  /// Extracted directly from embedded text layer within original PDF.
  embeddedPdfText('embedded_pdf_text'),

  /// Recognized using on-device ML/computer vision OCR engine.
  onDeviceOcr('on_device_ocr');

  const OcrSource(this.identifier);
  final String identifier;

  static OcrSource fromIdentifier(String? id) {
    if (id == null) return OcrSource.onDeviceOcr;
    for (final src in OcrSource.values) {
      if (src.identifier == id || src.name == id) return src;
    }
    return OcrSource.onDeviceOcr;
  }
}

/// Normalized bounding box in canonical Quiet Paper document coordinate space.
///
/// Origin is top-left `(0.0, 0.0)`, with `x` and `y` increasing rightwards and downwards.
/// All values (`x`, `y`, `width`, `height`) are strictly normalized in `[0.0, 1.0]`.
@immutable
class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Normalized X coordinate of the left edge (0.0 to 1.0).
  final double x;

  /// Normalized Y coordinate of the top edge (0.0 to 1.0).
  final double y;

  /// Normalized width (0.0 to 1.0).
  final double width;

  /// Normalized height (0.0 to 1.0).
  final double height;

  /// Normalized right coordinate.
  double get right => (x + width).clamp(0.0, 1.0);

  /// Normalized bottom coordinate.
  double get bottom => (y + height).clamp(0.0, 1.0);

  /// Normalized center point.
  double get centerX => x + width / 2.0;
  double get centerY => y + height / 2.0;

  /// Default full-page bounding box covering (0,0) to (1,1).
  static const full = NormalizedRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0);

  /// Zero-size box at origin.
  static const zero = NormalizedRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0);

  /// Creates a normalized bounding box from raw pixel dimensions against [sourceWidth] and [sourceHeight].
  factory NormalizedRect.fromPixels({
    required double pixelX,
    required double pixelY,
    required double pixelWidth,
    required double pixelHeight,
    required double sourceWidth,
    required double sourceHeight,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return NormalizedRect.full;
    }

    final normX = (pixelX / sourceWidth).clamp(0.0, 1.0);
    final normY = (pixelY / sourceHeight).clamp(0.0, 1.0);
    final normW = (pixelWidth / sourceWidth).clamp(0.0, 1.0 - normX);
    final normH = (pixelHeight / sourceHeight).clamp(0.0, 1.0 - normY);

    return NormalizedRect(
      x: _round(normX),
      y: _round(normY),
      width: _round(normW),
      height: _round(normH),
    );
  }

  /// Converts this normalized rectangle back to absolute pixel coordinates on a canvas of [targetWidth] x [targetHeight].
  ({double x, double y, double width, double height}) toPixels({
    required double targetWidth,
    required double targetHeight,
  }) {
    return (
      x: x * targetWidth,
      y: y * targetHeight,
      width: width * targetWidth,
      height: height * targetHeight,
    );
  }

  /// Checks if a normalized point `(px, py)` is inside this bounding box.
  bool contains(double px, double py) {
    return px >= x && px <= right && py >= y && py <= bottom;
  }

  /// Checks if this rectangle intersects with another normalized rectangle.
  bool intersects(NormalizedRect other) {
    return x < other.right &&
        right > other.x &&
        y < other.bottom &&
        bottom > other.y;
  }

  static double _round(double val) {
    // Round to 5 decimal places for clean storage precision
    return (val * 100000).round() / 100000;
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory NormalizedRect.fromJson(Map<String, dynamic> json) {
    final x = (json['x'] as num?)?.toDouble() ?? 0.0;
    final y = (json['y'] as num?)?.toDouble() ?? 0.0;
    final width = (json['width'] as num?)?.toDouble() ?? 1.0;
    final height = (json['height'] as num?)?.toDouble() ?? 1.0;

    return NormalizedRect(
      x: x.clamp(0.0, 1.0),
      y: y.clamp(0.0, 1.0),
      width: width.clamp(0.0, 1.0),
      height: height.clamp(0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedRect &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 0.0001 &&
          (y - other.y).abs() < 0.0001 &&
          (width - other.width).abs() < 0.0001 &&
          (height - other.height).abs() < 0.0001;

  @override
  int get hashCode => Object.hash(
        (x * 10000).round(),
        (y * 10000).round(),
        (width * 10000).round(),
        (height * 10000).round(),
      );

  @override
  String toString() =>
      'NormalizedRect(x: ${x.toStringAsFixed(4)}, y: ${y.toStringAsFixed(4)}, w: ${width.toStringAsFixed(4)}, h: ${height.toStringAsFixed(4)})';
}

/// A recognized single word with normalized geometry and optional confidence.
@immutable
class OcrWord {
  const OcrWord({
    required this.text,
    required this.bounds,
    this.confidence,
  });

  /// Recognized word string.
  final String text;

  /// Normalized bounding box.
  final NormalizedRect bounds;

  /// Optional engine confidence score `[0.0 - 1.0]`.
  final double? confidence;

  Map<String, dynamic> toJson() => {
        'text': text,
        'bounds': bounds.toJson(),
        if (confidence != null) 'confidence': confidence,
      };

  factory OcrWord.fromJson(Map<String, dynamic> json) {
    return OcrWord(
      text: json['text'] as String? ?? '',
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedRect.fromJson(json['bounds'] as Map<String, dynamic>)
          : NormalizedRect.full,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// A line of recognized words with normalized geometry.
@immutable
class OcrLine {
  const OcrLine({
    required this.text,
    required this.bounds,
    this.words = const [],
  });

  /// Complete line text.
  final String text;

  /// Normalized bounding box of the line.
  final NormalizedRect bounds;

  /// Child words composing this line.
  final List<OcrWord> words;

  Map<String, dynamic> toJson() => {
        'text': text,
        'bounds': bounds.toJson(),
        if (words.isNotEmpty) 'words': words.map((w) => w.toJson()).toList(),
      };

  factory OcrLine.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'] as List? ?? [];
    return OcrLine(
      text: json['text'] as String? ?? '',
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedRect.fromJson(json['bounds'] as Map<String, dynamic>)
          : NormalizedRect.full,
      words: rawWords
          .whereType<Map>()
          .map((w) => OcrWord.fromJson(Map<String, dynamic>.from(w)))
          .toList(),
    );
  }
}

/// A coherent block/paragraph of recognized lines with normalized geometry.
@immutable
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.bounds,
    this.lines = const [],
  });

  /// Complete block text.
  final String text;

  /// Normalized bounding box of the block.
  final NormalizedRect bounds;

  /// Child lines in this block.
  final List<OcrLine> lines;

  Map<String, dynamic> toJson() => {
        'text': text,
        'bounds': bounds.toJson(),
        if (lines.isNotEmpty) 'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory OcrBlock.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? [];
    return OcrBlock(
      text: json['text'] as String? ?? '',
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedRect.fromJson(json['bounds'] as Map<String, dynamic>)
          : NormalizedRect.full,
      lines: rawLines
          .whereType<Map>()
          .map((l) => OcrLine.fromJson(Map<String, dynamic>.from(l)))
          .toList(),
    );
  }
}

/// Recognized text and structured hierarchy for a single document page.
@immutable
class OcrPage {
  const OcrPage({
    required this.pageNumber,
    required this.plainText,
    required this.width,
    required this.height,
    this.blocks = const [],
    this.source = OcrSource.onDeviceOcr,
  });

  /// 1-based page sequence number.
  final int pageNumber;

  /// Clean, search-indexed plain text representation with preserved paragraph/line breaks.
  final String plainText;

  /// Source pixel width of the processed page.
  final int width;

  /// Source pixel height of the processed page.
  final int height;

  /// Structured recognized blocks.
  final List<OcrBlock> blocks;

  /// Whether text was extracted from PDF text layer or recognized via ML OCR.
  final OcrSource source;

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'plainText': plainText,
        'width': width,
        'height': height,
        'source': source.identifier,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory OcrPage.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List? ?? [];
    return OcrPage(
      pageNumber: json['pageNumber'] as int? ?? 1,
      plainText: json['plainText'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      source: OcrSource.fromIdentifier(json['source'] as String?),
      blocks: rawBlocks
          .whereType<Map>()
          .map((b) => OcrBlock.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

/// Complete document OCR dataset containing all pages and metadata.
@immutable
class OcrDocument {
  const OcrDocument({
    required this.documentId,
    this.language = OcrLanguage.english,
    this.engine = 'quietpaper_ocr_v1',
    this.engineVersion = '1.0.0',
    this.schemaVersion = 1,
    required this.processedAt,
    this.pages = const [],
    this.sourceDocumentSha256,
  });

  /// Canonical document UUID.
  final String documentId;

  /// Language used during OCR.
  final OcrLanguage language;

  /// Name of OCR engine/implementation.
  final String engine;

  /// Version of OCR engine.
  final String engineVersion;

  /// Version of OCR schema.
  final int schemaVersion;

  /// Timestamp when OCR was completed.
  final DateTime processedAt;

  /// Ordered page OCR results.
  final List<OcrPage> pages;

  /// Optional SHA-256 hash of canonical PDF source to bind OCR and detect stale data.
  final String? sourceDocumentSha256;

  /// Returns full plain text across all pages concatenated with double newlines.
  String get fullPlainText =>
      pages.map((p) => p.plainText.trim()).where((t) => t.isNotEmpty).join('\n\n');

  /// Formatted text output suitable for copying the entire document OCR text with stable page headers.
  String get formattedCopyText {
    if (pages.isEmpty) return '';
    if (pages.length == 1) {
      return 'Page 1\n================================\n\n${pages.first.plainText.trim()}';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) buffer.writeln('\n');
      buffer.writeln('Page ${pages[i].pageNumber}');
      buffer.writeln('================================\n');
      buffer.writeln(pages[i].plainText.trim());
    }
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'language': language.code,
        'engine': engine,
        'engineVersion': engineVersion,
        'schemaVersion': schemaVersion,
        'processedAt': processedAt.toIso8601String(),
        if (sourceDocumentSha256 != null)
          'sourceDocumentSha256': sourceDocumentSha256,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory OcrDocument.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List? ?? [];
    return OcrDocument(
      documentId: json['documentId'] as String? ?? '',
      language: OcrLanguage.fromCode(json['language'] as String?),
      engine: json['engine'] as String? ?? 'quietpaper_ocr_v1',
      engineVersion: json['engineVersion'] as String? ?? '1.0.0',
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      processedAt: DateTime.tryParse(json['processedAt'] as String? ?? '') ??
          DateTime.now(),
      sourceDocumentSha256: json['sourceDocumentSha256'] as String?,
      pages: rawPages
          .whereType<Map>()
          .map((p) => OcrPage.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}
