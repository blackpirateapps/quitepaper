import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../ocr/ocr_models.dart';

/// Result of extracting embedded text layer from a PDF document.
@immutable
class PdfTextExtractionResult {
  const PdfTextExtractionResult({
    required this.hasUsableText,
    this.pages = const [],
    this.extractedText = '',
  });

  /// Whether a usable text layer was present in the PDF.
  /// If `false`, callers should fall back to on-device OCR.
  final bool hasUsableText;

  /// Structured pages extracted from PDF text streams.
  final List<OcrPage> pages;

  /// Combined plain text across all pages.
  final String extractedText;
}

/// Abstract contract for inspecting and extracting embedded text layers from PDF files.
abstract class PdfTextExtractor {
  Future<PdfTextExtractionResult> extractText(Uint8List pdfBytes);
}

/// Default PDF text extractor that parses PDF text streams, fonts, and layout operators.
class DefaultPdfTextExtractor implements PdfTextExtractor {
  const DefaultPdfTextExtractor();

  @override
  Future<PdfTextExtractionResult> extractText(Uint8List pdfBytes) async {
    try {
      final pdfString = latin1.decode(pdfBytes, allowInvalid: true);

      // Check if PDF has text markers (BT ... ET, Tj, TJ, /Font, Text)
      if (!pdfString.contains('/Font') &&
          !pdfString.contains('BT') &&
          !pdfString.contains('Tj') &&
          !pdfString.contains('TJ')) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      // Split into approximate page objects
      final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(pdfString).toList();
      final pageCount = pageMatches.isEmpty ? 1 : pageMatches.length;

      final pages = <OcrPage>[];
      final fullTextBuffer = StringBuffer();

      // Extract text segments from text blocks between BT and ET
      final btEtRegex = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
      final tjRegex = RegExp(r'\((.*?)\)\s*Tj');
      final arrayTjRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);

      final matches = btEtRegex.allMatches(pdfString).toList();

      if (matches.isEmpty) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      final extractedLines = <String>[];

      for (final match in matches) {
        final blockContent = match.group(1) ?? '';

        // Extract simple (text) Tj
        for (final tj in tjRegex.allMatches(blockContent)) {
          final raw = tj.group(1);
          if (raw != null && raw.trim().isNotEmpty) {
            extractedLines.add(_unescapePdfString(raw));
          }
        }

        // Extract array [(text) 120 (more)] TJ
        for (final arrayMatch in arrayTjRegex.allMatches(blockContent)) {
          final inner = arrayMatch.group(1) ?? '';
          final strRegex = RegExp(r'\((.*?)\)');
          final parts = <String>[];
          for (final sm in strRegex.allMatches(inner)) {
            final part = sm.group(1);
            if (part != null && part.isNotEmpty) {
              parts.add(_unescapePdfString(part));
            }
          }
          if (parts.isNotEmpty) {
            extractedLines.add(parts.join(' '));
          }
        }
      }

      final cleanLines = extractedLines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.length > 1)
          .toList();

      if (cleanLines.isEmpty || cleanLines.join(' ').length < 10) {
        return const PdfTextExtractionResult(hasUsableText: false);
      }

      // Distribute extracted lines across estimated pages
      final linesPerPage = (cleanLines.length / pageCount).ceil().clamp(1, 9999);

      for (var p = 0; p < pageCount; p++) {
        final pageNum = p + 1;
        final startIdx = p * linesPerPage;
        if (startIdx >= cleanLines.length && p > 0) break;

        final endIdx = (startIdx + linesPerPage).clamp(0, cleanLines.length);
        final pageLines = cleanLines.sublist(startIdx, endIdx);
        if (pageLines.isEmpty) continue;

        final pageBlocks = <OcrBlock>[];
        final ocrLines = <OcrLine>[];

        for (var i = 0; i < pageLines.length; i++) {
          final lineText = pageLines[i];
          final normY = (i / pageLines.length).clamp(0.05, 0.90);
          final normH = (1.0 / (pageLines.length + 2)).clamp(0.02, 0.08);

          final words = lineText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          final ocrWords = <OcrWord>[];

          for (var w = 0; w < words.length; w++) {
            final word = words[w];
            final wordX = (w / words.length).clamp(0.05, 0.85);
            final wordW = (1.0 / (words.length + 1)).clamp(0.04, 0.3);

            ocrWords.add(
              OcrWord(
                text: word,
                bounds: NormalizedRect(
                  x: wordX,
                  y: normY,
                  width: wordW,
                  height: normH,
                ),
                confidence: 0.99,
              ),
            );
          }

          ocrLines.add(
            OcrLine(
              text: lineText,
              bounds: NormalizedRect(
                x: 0.05,
                y: normY,
                width: 0.90,
                height: normH,
              ),
              words: ocrWords,
            ),
          );
        }

        pageBlocks.add(
          OcrBlock(
            text: pageLines.join('\n'),
            bounds: const NormalizedRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90),
            lines: ocrLines,
          ),
        );

        final pagePlainText = pageLines.join('\n');
        fullTextBuffer.writeln(pagePlainText);

        pages.add(
          OcrPage(
            pageNumber: pageNum,
            plainText: pagePlainText,
            width: 1000,
            height: 1414,
            source: OcrSource.embeddedPdfText,
            blocks: pageBlocks,
          ),
        );
      }

      final combined = fullTextBuffer.toString().trim();
      return PdfTextExtractionResult(
        hasUsableText: pages.isNotEmpty && combined.isNotEmpty,
        pages: pages,
        extractedText: combined,
      );
    } catch (e) {
      debugPrint('PdfTextExtractor parsing error: $e');
      return const PdfTextExtractionResult(hasUsableText: false);
    }
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }
}
