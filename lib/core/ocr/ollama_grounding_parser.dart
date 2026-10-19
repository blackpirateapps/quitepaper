import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
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
/// `<tag>[[xmin, ymin, xmax, ymax]]` normalized to a `[0, 1000]` integer grid.
///
/// This parser:
/// 1. Extracts spatial bounding boxes for text blocks, lines, and words.
/// 2. Records detected image / diagram regions (`image[[...]]`).
/// 3. Generates clean Markdown free of machine coordinate tags for notes.
/// 4. Converts raw HTML tables into GFM Markdown pipe tables for native rendering.
/// 5. Falls back gracefully for models returning standard Markdown without tags.
class OllamaGroundingParser {
  const OllamaGroundingParser._();

  static final RegExp _tagRegex = RegExp(
    r'([a-zA-Z0-9_\-]+)\[\[\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]\]',
  );

  static final RegExp _tableRegex = RegExp(
    r'<table[^>]*>([\s\S]*?)<\/table>',
    caseSensitive: false,
  );

  /// Converts any HTML `<table>...</table>` elements within [input] to standard GFM Markdown pipe tables.
  ///
  /// Preserves cell contents while stripping HTML wrappers, formatting columns and separator rows
  /// so that Quiet Paper's native Markdown table components and preview render the table correctly.
  static String convertHtmlTablesToMarkdown(String input) {
    if (!input.toLowerCase().contains('<table')) {
      return input;
    }

    return input.replaceAllMapped(_tableRegex, (match) {
      final fullMatch = match.group(0)!;
      return _convertSingleHtmlTable(fullMatch);
    });
  }

  static String _convertSingleHtmlTable(String tableHtml) {
    final fragment = html_parser.parseFragment(tableHtml);
    final tableEl = fragment.querySelector('table');
    if (tableEl == null) {
      return tableHtml.replaceAll(RegExp(r'</?table[^>]*>', caseSensitive: false), '').trim();
    }

    final rows = tableEl.querySelectorAll('tr');
    if (rows.isEmpty) {
      final innerText = (fragment.text ?? '').trim();
      if (innerText.isNotEmpty) {
        return innerText;
      }
      return tableHtml.replaceAll(RegExp(r'</?table[^>]*>', caseSensitive: false), '').trim();
    }

    final tableData = <List<String>>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('th, td');
      if (cells.isEmpty) continue;
      final rowData = cells.map((cell) {
        var text = cell.text.replaceAll(_tagRegex, '').trim();
        text = text.replaceAll('\n', ' ').replaceAll('|', r'\|').trim();
        return text;
      }).toList();
      tableData.add(rowData);
    }

    if (tableData.isEmpty) {
      final innerText = tableEl.text.trim();
      return innerText;
    }

    final maxCols = tableData.fold<int>(0, (max, r) => r.length > max ? r.length : max);
    if (maxCols == 0) return '';

    final buf = StringBuffer('\n');

    // Header row (first row)
    final header = tableData.first;
    buf.write('|');
    for (var i = 0; i < maxCols; i++) {
      final val = i < header.length ? header[i] : '';
      buf.write(' ${val.isNotEmpty ? val : " "} |');
    }
    buf.writeln();

    // Separator row
    buf.write('|');
    for (var i = 0; i < maxCols; i++) {
      buf.write(' --- |');
    }
    buf.writeln();

    // Data rows
    if (tableData.length == 1) {
      buf.write('|');
      for (var i = 0; i < maxCols; i++) {
        buf.write('   |');
      }
      buf.writeln();
    } else {
      for (var r = 1; r < tableData.length; r++) {
        final row = tableData[r];
        buf.write('|');
        for (var i = 0; i < maxCols; i++) {
          final val = i < row.length ? row[i] : '';
          buf.write(' ${val.isNotEmpty ? val : " "} |');
        }
        buf.writeln();
      }
    }
    buf.writeln();

    return buf.toString();
  }

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
      final cleanPrefix = convertHtmlTablesToMarkdown(prefixText).trim();
      if (cleanPrefix.isNotEmpty) {
        cleanTextParts.add(cleanPrefix);
        blocks.add(
          _createBlock(
            text: cleanPrefix,
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
      final cleanContent = convertHtmlTablesToMarkdown(content).trim();

      if (tag == 'image' || tag == 'figure') {
        detectedImages.add(normRect);
      }

      if (cleanContent.isNotEmpty) {
        cleanTextParts.add(cleanContent);
        blocks.add(
          _createBlock(
            text: cleanContent,
            bounds: normRect,
          ),
        );
      }
    }

    final cleanPlainText = convertHtmlTablesToMarkdown(cleanTextParts.join('\n\n')).trim();

    return ParsedOcrResult(
      cleanPlainText: cleanPlainText,
      blocks: blocks,
      detectedImages: detectedImages,
    );
  }

  static ParsedOcrResult _parseNonGroundedMarkdown(String text) {
    final convertedText = convertHtmlTablesToMarkdown(text);
    final paragraphs = convertedText.split(RegExp(r'\n{2,}'));
    final nonEmpties = paragraphs.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    if (nonEmpties.isEmpty) {
      return ParsedOcrResult(
        cleanPlainText: convertedText.trim(),
        blocks: const [],
        detectedImages: const [],
      );
    }

    final blocks = <OcrBlock>[];
    const topMargin = 0.05;
    const bottomMargin = 0.05;
    final usableHeight = 1.0 - (topMargin + bottomMargin);
    final rawBlockHeight = usableHeight / nonEmpties.length;
    final blockHeight = rawBlockHeight.clamp(0.0, 0.90);

    for (var i = 0; i < nonEmpties.length; i++) {
      final para = nonEmpties[i];
      final rawBlockY = topMargin + (i * blockHeight);
      final blockY = rawBlockY.clamp(0.0, 1.0);
      final maxAvailableH = (1.0 - blockY).clamp(0.0, 1.0);
      final effectiveBlockH = blockHeight.clamp(0.0, maxAvailableH);

      final roundedBlockY = _round(blockY).clamp(0.0, 1.0);
      var roundedBlockH = _round(effectiveBlockH);
      if (roundedBlockH == 0.0 && effectiveBlockH > 0.0 && maxAvailableH > 0.0) {
        roundedBlockH = maxAvailableH < 0.0001 ? maxAvailableH : 0.0001;
      }
      roundedBlockH = roundedBlockH.clamp(0.0, 1.0 - roundedBlockY);

      final blockBounds = NormalizedRect(
        x: 0.05,
        y: roundedBlockY,
        width: 0.90,
        height: roundedBlockH,
      );

      blocks.add(
        _createBlock(
          text: para,
          bounds: blockBounds,
        ),
      );
    }

    return ParsedOcrResult(
      cleanPlainText: convertedText.trim(),
      blocks: blocks,
      detectedImages: const [],
    );
  }

  static OcrBlock _createBlock({
    required String text,
    required NormalizedRect bounds,
  }) {
    final rawParagraphs = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawParagraphs.isEmpty) {
      return OcrBlock(
        text: text,
        bounds: bounds,
        lines: const [],
      );
    }

    final wBox = bounds.width;
    // Standard document line across full page width (1.0) holds ~85 characters.
    final singleLineCapacity = (wBox * 85).clamp(25.0, 100.0);

    // 1. Partition each raw paragraph into visual lines of words
    final allVisualLinesOfWords = <List<String>>[];

    for (final pText in rawParagraphs) {
      final words = pText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) continue;

      int numLines = (pText.length / singleLineCapacity).round();
      if (numLines < 1) numLines = 1;
      if (numLines > words.length) numLines = words.length;

      final pVisualLines = <List<String>>[];
      if (numLines <= 1 || words.length <= 1) {
        pVisualLines.add(words);
      } else {
        final targetCharsPerLine = (pText.length / numLines).ceil();
        var curLine = <String>[];
        var curChars = 0;

        for (var w = 0; w < words.length; w++) {
          final word = words[w];
          final wordLen = word.length + (curLine.isNotEmpty ? 1 : 0);
          final remainingLines = numLines - pVisualLines.length;
          final remainingWords = words.length - w;

          final shouldWrap = pVisualLines.length < numLines - 1 &&
              curLine.isNotEmpty &&
              ((curChars + wordLen > targetCharsPerLine * 1.15) || remainingWords <= remainingLines);

          if (shouldWrap) {
            pVisualLines.add(curLine);
            curLine = [word];
            curChars = word.length;
          } else {
            curLine.add(word);
            curChars += wordLen;
          }
        }
        if (curLine.isNotEmpty) {
          pVisualLines.add(curLine);
        }
      }
      allVisualLinesOfWords.addAll(pVisualLines);
    }

    if (allVisualLinesOfWords.isEmpty) {
      return OcrBlock(
        text: text,
        bounds: bounds,
        lines: const [],
      );
    }

    // 2. Uniform line height across all visual lines in the block
    final totalLines = allVisualLinesOfWords.length;
    final lineHeight = (bounds.height / totalLines).clamp(0.0, bounds.height);
    final ocrLines = <OcrLine>[];

    for (var l = 0; l < totalLines; l++) {
      final lineWords = allVisualLinesOfWords[l];
      final lineStr = lineWords.join(' ');
      final rawLineY = bounds.y + (l * lineHeight);
      final lineY = rawLineY.clamp(0.0, 1.0);
      final maxAvailableH = (1.0 - lineY).clamp(0.0, 1.0);
      final lineH = lineHeight.clamp(0.0, maxAvailableH);

      final roundedLineY = _round(lineY).clamp(0.0, 1.0);
      var roundedLineH = _round(lineH);
      if (roundedLineH == 0.0 && lineH > 0.0 && maxAvailableH > 0.0) {
        roundedLineH = maxAvailableH < 0.0001 ? maxAvailableH : 0.0001;
      }
      roundedLineH = roundedLineH.clamp(0.0, 1.0 - roundedLineY);

      final roundedLineX = _round(bounds.x).clamp(0.0, 1.0);
      var roundedLineW = _round(bounds.width);
      if (roundedLineW == 0.0 && bounds.width > 0.0) {
        roundedLineW = (1.0 - roundedLineX) < 0.0001 ? (1.0 - roundedLineX) : 0.0001;
      }
      roundedLineW = roundedLineW.clamp(0.0, 1.0 - roundedLineX);

      final lineBounds = NormalizedRect(
        x: roundedLineX,
        y: roundedLineY,
        width: roundedLineW,
        height: roundedLineH,
      );

      final ocrWords = <OcrWord>[];
      final lineCharsCount = lineWords.fold<int>(0, (sum, w) => sum + w.length);
      var currentX = lineBounds.x;

      for (var w = 0; w < lineWords.length; w++) {
        final word = lineWords[w];
        final fraction = lineCharsCount > 0
            ? (word.length / lineCharsCount)
            : (1.0 / lineWords.length);
        final rawWordWidth = lineBounds.width * fraction;

        final wordX = currentX.clamp(0.0, 1.0);
        final maxWordW = (1.0 - wordX).clamp(0.0, 1.0);
        final wordW = rawWordWidth.clamp(0.0, maxWordW);

        final roundedWordX = _round(wordX).clamp(0.0, 1.0);
        var roundedWordW = _round(wordW);
        if (roundedWordW == 0.0 && wordW > 0.0 && maxWordW > 0.0) {
          roundedWordW = maxWordW < 0.0001 ? maxWordW : 0.0001;
        }
        roundedWordW = roundedWordW.clamp(0.0, 1.0 - roundedWordX);

        final wordBounds = NormalizedRect(
          x: roundedWordX,
          y: lineBounds.y,
          width: roundedWordW,
          height: lineBounds.height,
        );

        ocrWords.add(
          OcrWord(
            text: word,
            bounds: wordBounds,
            confidence: 0.95,
          ),
        );

        currentX = (wordX + wordW).clamp(0.0, 1.0);
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

    final normX1 = (x1 / 1000.0).clamp(0.0, 1.0);
    final normX2 = (x2 / 1000.0).clamp(0.0, 1.0);
    final normY1 = (y1 / 1000.0).clamp(0.0, 1.0);
    final normY2 = (y2 / 1000.0).clamp(0.0, 1.0);

    var normX = normX1;
    var normW = normX2 - normX1;
    if (normW < 0.005) {
      normW = 0.005;
    }
    if (normX + normW > 1.0) {
      normX = (1.0 - normW).clamp(0.0, 1.0);
      normW = (1.0 - normX).clamp(0.0, 1.0);
    }

    var normY = normY1;
    var normH = normY2 - normY1;
    if (normH < 0.005) {
      normH = 0.005;
    }
    if (normY + normH > 1.0) {
      normY = (1.0 - normH).clamp(0.0, 1.0);
      normH = (1.0 - normY).clamp(0.0, 1.0);
    }

    final roundedX = _round(normX).clamp(0.0, 1.0);
    final roundedW = _round(normW).clamp(0.0, 1.0 - roundedX);
    final roundedY = _round(normY).clamp(0.0, 1.0);
    final roundedH = _round(normH).clamp(0.0, 1.0 - roundedY);

    return NormalizedRect(
      x: roundedX,
      y: roundedY,
      width: roundedW,
      height: roundedH,
    );
  }

  static double _round(double val) {
    return (val * 10000).round() / 10000;
  }
}
