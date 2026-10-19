import 'package:flutter/foundation.dart';
import 'ocr_models.dart';

/// Structured result returned by [OllamaGroundingParser].
@immutable
class ParsedOcrResult {
  const ParsedOcrResult({
    required this.cleanPlainText,
    required this.blocks,
    this.detectedImages = const [],
  });

  /// Clean Markdown / plain text with visual grounding tags stripped.
  final String cleanPlainText;

  /// Structured recognized blocks with normalized bounds, lines, and words.
  final List<OcrBlock> blocks;

  /// Normalized bounding boxes of detected images/diagrams.
  final List<NormalizedRect> detectedImages;
}

/// Parser for Ollama / DeepSeek-OCR visual grounding output.
///
/// DeepSeek-OCR produces grounded transcriptions with coordinate tags:
/// `<tag>[[ymin, xmin, ymax, xmax]]` normalized to a `[0, 1000]` integer grid.
///
/// This parser:
/// 1. Extracts spatial bounding boxes for text blocks, lines, and words.
/// 2. Records detected image / diagram regions (`image[[...]]`).
/// 3. Generates clean Markdown free of machine coordinate tags for notes.
/// 4. Falls back gracefully for models returning standard Markdown without tags.
class OllamaGroundingParser {
  const OllamaGroundingParser._();

  static final RegExp _tagRegex = RegExp(
    r'([a-zA-Z0-9_\-]+)\[\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]\]',
  );

  /// Parses [rawResponse] into structured [ParsedOcrResult].
  static ParsedOcrResult parse(String rawResponse) {
    final text = rawResponse.trim();
    if (text.isEmpty) {
      return const ParsedOcrResult(
        cleanPlainText: '',
        blocks: [],
        detectedImages: [],
      );
    }

    final matches = _tagRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return _parseNonGroundedMarkdown(text);
    }

    return _parseGroundedResponse(text, matches);
  }

  static ParsedOcrResult _parseGroundedResponse(
    String fullText,
    List<RegExpMatch> matches,
  ) {
    final blocks = <OcrBlock>[];
    final detectedImages = <NormalizedRect>[];
    final cleanTextParts = <String>[];

    // Check for any text preceding the first grounding tag
    if (matches.first.start > 0) {
      final prefixText = fullText.substring(0, matches.first.start).trim();
      if (prefixText.isNotEmpty) {
        cleanTextParts.add(prefixText);
        blocks.add(
          _createBlock(
            text: prefixText,
            bounds: const NormalizedRect(
              x: 0.05,
              y: 0.02,
              width: 0.90,
              height: 0.10,
            ),
          ),
        );
      }
    }

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final tag = match.group(1)!.toLowerCase();
      final xmin = int.tryParse(match.group(2)!) ?? 0;
      final ymin = int.tryParse(match.group(3)!) ?? 0;
      final xmax = int.tryParse(match.group(4)!) ?? 1000;
      final ymax = int.tryParse(match.group(5)!) ?? 1000;

      final normRect = _toNormalizedRect(
        xmin: xmin,
        ymin: ymin,
        xmax: xmax,
        ymax: ymax,
      );

      final contentStart = match.end;
      final contentEnd = (i + 1 < matches.length) ? matches[i + 1].start : fullText.length;
      final content = fullText.substring(contentStart, contentEnd).trim();

      if (tag == 'image' || tag == 'figure') {
        detectedImages.add(normRect);
      }

      if (content.isNotEmpty) {
        cleanTextParts.add(content);
        blocks.add(
          _createBlock(
            text: content,
            bounds: normRect,
          ),
        );
      }
    }

    final cleanPlainText = cleanTextParts.join('\n\n').trim();

    return ParsedOcrResult(
      cleanPlainText: cleanPlainText,
      blocks: blocks,
      detectedImages: detectedImages,
    );
  }

  static ParsedOcrResult _parseNonGroundedMarkdown(String text) {
    final paragraphs = text.split(RegExp(r'\n{2,}'));
    final nonEmpties = paragraphs.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    if (nonEmpties.isEmpty) {
      return ParsedOcrResult(
        cleanPlainText: text,
        blocks: const [],
        detectedImages: const [],
      );
    }

    final blocks = <OcrBlock>[];
    const topMargin = 0.05;
    const bottomMargin = 0.05;
    final usableHeight = 1.0 - (topMargin + bottomMargin);
    final blockHeight = (usableHeight / nonEmpties.length).clamp(0.02, 0.90);

    for (var i = 0; i < nonEmpties.length; i++) {
      final para = nonEmpties[i];
      final blockY = topMargin + (i * blockHeight);
      final blockBounds = NormalizedRect(
        x: 0.05,
        y: _round(blockY),
        width: 0.90,
        height: _round(blockHeight.clamp(0.02, 1.0 - blockY)),
      );

      blocks.add(
        _createBlock(
          text: para,
          bounds: blockBounds,
        ),
      );
    }

    return ParsedOcrResult(
      cleanPlainText: text,
      blocks: blocks,
      detectedImages: const [],
    );
  }

  static OcrBlock _createBlock({
    required String text,
    required NormalizedRect bounds,
  }) {
    final rawLines = text.split('\n');
    final lineStrings = rawLines
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lineStrings.isEmpty) {
      return OcrBlock(
        text: text,
        bounds: bounds,
        lines: const [],
      );
    }

    final ocrLines = <OcrLine>[];
    final lineHeight = (bounds.height / lineStrings.length).clamp(0.005, bounds.height);

    for (var i = 0; i < lineStrings.length; i++) {
      final lineStr = lineStrings[i];
      final lineY = bounds.y + (i * lineHeight);
      final lineBounds = NormalizedRect(
        x: bounds.x,
        y: _round(lineY),
        width: bounds.width,
        height: _round(lineHeight.clamp(0.005, 1.0 - lineY)),
      );

      final words = lineStr
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      final ocrWords = <OcrWord>[];
      if (words.isNotEmpty) {
        final totalChars = words.fold<int>(0, (sum, w) => sum + w.length);
        var currentX = lineBounds.x;

        for (var w = 0; w < words.length; w++) {
          final word = words[w];
          final fraction = totalChars > 0
              ? (word.length / totalChars)
              : (1.0 / words.length);
          final wordWidth = (lineBounds.width * fraction).clamp(0.005, lineBounds.width);
          final wordBounds = NormalizedRect(
            x: _round(currentX),
            y: lineBounds.y,
            width: _round(wordWidth.clamp(0.005, 1.0 - currentX)),
            height: lineBounds.height,
          );

          ocrWords.add(
            OcrWord(
              text: word,
              bounds: wordBounds,
              confidence: 0.95,
            ),
          );

          currentX = (currentX + wordWidth).clamp(0.0, 1.0);
        }
      }

      ocrLines.add(
        OcrLine(
          text: lineStr,
          bounds: lineBounds,
          words: ocrWords,
        ),
      );
    }

    return OcrBlock(
      text: text,
      bounds: bounds,
      lines: ocrLines,
    );
  }

  static NormalizedRect _toNormalizedRect({
    required int xmin,
    required int ymin,
    required int xmax,
    required int ymax,
  }) {
    final x1 = xmin < xmax ? xmin : xmax;
    final x2 = xmin < xmax ? xmax : xmin;
    final y1 = ymin < ymax ? ymin : ymax;
    final y2 = ymin < ymax ? ymax : ymin;

    final normX = (x1 / 1000.0).clamp(0.0, 1.0);
    final normY = (y1 / 1000.0).clamp(0.0, 1.0);
    final normW = ((x2 - x1) / 1000.0).clamp(0.005, 1.0 - normX);
    final normH = ((y2 - y1) / 1000.0).clamp(0.005, 1.0 - normY);

    return NormalizedRect(
      x: _round(normX),
      y: _round(normY),
      width: _round(normW),
      height: _round(normH),
    );
  }

  static double _round(double val) {
    return (val * 10000).round() / 10000;
  }
}
