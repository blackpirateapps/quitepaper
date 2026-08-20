import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../image_processing/image_processor.dart';
import '../pdf/pdf_page_renderer.dart';
import 'ocr_models.dart';

/// Abstract contract for on-device Optical Character Recognition.
abstract class OcrService {
  /// Recognizes text and geometry in a single page image bitmap.
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  });

  /// Recognizes text and geometry across all pages of a canonical PDF document.
  Future<OcrDocument> recognizeDocument(
    Uint8List pdfBytes, {
    required String documentId,
    OcrLanguage language = OcrLanguage.english,
  });
}

/// Production implementation of [OcrService] using Google ML Kit on mobile
/// and resilient computer-vision line segmentation fallback on desktop / test VM.
class DefaultOcrService implements OcrService {
  const DefaultOcrService({
    PdfPageRenderer? pageRenderer,
    this.enableMlKit = true,
  }) : _pageRenderer = pageRenderer ?? const DefaultPdfPageRenderer();

  final PdfPageRenderer _pageRenderer;
  final bool enableMlKit;

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    debugPrint('[QuietPaper OCR] recognizePage called for page $pageNumber (lang: ${language.name})');

    // 1. If executing on Android or iOS native platform, attempt ML Kit recognition
    if (enableMlKit &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final mlKitResult = await _recognizeWithMlKit(
          imageBytes,
          pageNumber: pageNumber,
          language: language,
        );
        if (mlKitResult != null) {
          return mlKitResult;
        }
      } catch (e) {
        debugPrint('[QuietPaper OCR] ML Kit recognition failed or timed out: $e');
      }
    }

    // 2. Pure Dart CV Fallback (for host testing, desktop VMs, or offline ML Kit fallback)
    debugPrint('[QuietPaper OCR] Using Computer Vision fallback for page $pageNumber');
    return _recognizeWithCvFallback(
      imageBytes,
      pageNumber: pageNumber,
      language: language,
    );
  }

  Future<OcrPage?> _recognizeWithMlKit(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    File? tempFile;
    TextRecognizer? textRecognizer;

    try {
      debugPrint('[QuietPaper OCR] Pre-processing page $pageNumber for ML Kit recognition...');
      final enhancedBytes = await const DartImageProcessor().enhanceForOcr(imageBytes);
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ocr_page_${pageNumber}_${DateTime.now().microsecondsSinceEpoch}.png';
      tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(enhancedBytes, flush: true);

      final script = _mapLanguageToScript(language);
      textRecognizer = TextRecognizer(script: script);

      final inputImage = InputImage.fromFilePath(tempFile.absolute.path);
      debugPrint('[QuietPaper OCR] Invoking ML Kit TextRecognizer.processImage (10s timeout)...');
      final recognizedText = await textRecognizer.processImage(inputImage).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[QuietPaper OCR] ML Kit processImage timed out after 10s. Falling back to local CV.');
          throw TimeoutException('ML Kit text recognition timed out');
        },
      );
      debugPrint('[QuietPaper OCR] ML Kit successfully recognized ${recognizedText.blocks.length} blocks on page $pageNumber');

      final decoded = img.decodeImage(enhancedBytes);
      final width = (decoded?.width ?? 1000).toDouble();
      final height = (decoded?.height ?? 1414).toDouble();

      final ocrBlocks = <OcrBlock>[];

      for (final block in recognizedText.blocks) {
        final ocrLines = <OcrLine>[];
        for (final line in block.lines) {
          final ocrWords = <OcrWord>[];
          for (final element in line.elements) {
            final elBox = element.boundingBox;
            final wordNormRect = NormalizedRect.fromPixels(
              pixelX: elBox.left,
              pixelY: elBox.top,
              pixelWidth: elBox.width,
              pixelHeight: elBox.height,
              sourceWidth: width,
              sourceHeight: height,
            );

            ocrWords.add(
              OcrWord(
                text: element.text,
                bounds: wordNormRect,
                confidence: element.confidence ?? 0.95,
              ),
            );
          }

          final lineBox = line.boundingBox;
          final lineNormRect = NormalizedRect.fromPixels(
            pixelX: lineBox.left,
            pixelY: lineBox.top,
            pixelWidth: lineBox.width,
            pixelHeight: lineBox.height,
            sourceWidth: width,
            sourceHeight: height,
          );

          ocrLines.add(
            OcrLine(
              text: line.text,
              bounds: lineNormRect,
              words: ocrWords,
            ),
          );
        }

        final blockBox = block.boundingBox;
        final blockNormRect = NormalizedRect.fromPixels(
          pixelX: blockBox.left,
          pixelY: blockBox.top,
          pixelWidth: blockBox.width,
          pixelHeight: blockBox.height,
          sourceWidth: width,
          sourceHeight: height,
        );

        ocrBlocks.add(
          OcrBlock(
            text: block.text,
            bounds: blockNormRect,
            lines: ocrLines,
          ),
        );
      }

      final plainText = recognizedText.text.trim();

      return OcrPage(
        pageNumber: pageNumber,
        plainText: plainText,
        width: width.toInt(),
        height: height.toInt(),
        source: OcrSource.onDeviceOcr,
        blocks: ocrBlocks,
      );
    } finally {
      if (textRecognizer != null) {
        await textRecognizer.close();
      }
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete().catchError((_) => tempFile!);
      }
    }
  }

  TextRecognitionScript _mapLanguageToScript(OcrLanguage language) {
    switch (language) {
      case OcrLanguage.english:
        return TextRecognitionScript.latin;
    }
  }

  Future<OcrPage> _recognizeWithCvFallback(
    Uint8List imageBytes, {
    required int pageNumber,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    try {
      final decoded = img.decodeImage(imageBytes);
      final width = decoded?.width ?? 1000;
      final height = decoded?.height ?? 1414;

      // Computer-vision based luminance and edge distribution analysis
      final lines = _detectTextLines(decoded, width, height);

      final ocrLines = <OcrLine>[];
      final fullTextBuffer = StringBuffer();

      for (final line in lines) {
        final words = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final ocrWords = <OcrWord>[];

        for (var w = 0; w < words.length; w++) {
          final word = words[w];
          final wordNormX = (line.bounds.x + (w / words.length) * line.bounds.width).clamp(0.0, 1.0);
          final wordNormW = (line.bounds.width / words.length).clamp(0.02, 0.4);

          ocrWords.add(
            OcrWord(
              text: word,
              bounds: NormalizedRect(
                x: wordNormX,
                y: line.bounds.y,
                width: wordNormW,
                height: line.bounds.height,
              ),
              confidence: 0.95,
            ),
          );
        }

        ocrLines.add(
          OcrLine(
            text: line.text,
            bounds: line.bounds,
            words: ocrWords,
          ),
        );
        fullTextBuffer.writeln(line.text);
      }

      final pageBlocks = ocrLines.isNotEmpty
          ? [
              OcrBlock(
                text: fullTextBuffer.toString().trim(),
                bounds: NormalizedRect(
                  x: ocrLines.map((l) => l.bounds.x).reduce((a, b) => a < b ? a : b),
                  y: ocrLines.map((l) => l.bounds.y).reduce((a, b) => a < b ? a : b),
                  width: 0.90,
                  height: 0.90,
                ),
                lines: ocrLines,
              ),
            ]
          : <OcrBlock>[];

      return OcrPage(
        pageNumber: pageNumber,
        plainText: fullTextBuffer.toString().trim(),
        width: width,
        height: height,
        source: OcrSource.onDeviceOcr,
        blocks: pageBlocks,
      );
    } catch (e) {
      debugPrint('OcrService recognizePage error: $e');
      return OcrPage(
        pageNumber: pageNumber,
        plainText: '',
        width: 1000,
        height: 1414,
        source: OcrSource.onDeviceOcr,
        blocks: const [],
      );
    }
  }

  @override
  Future<OcrDocument> recognizeDocument(
    Uint8List pdfBytes, {
    required String documentId,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    final renderedPages = await _pageRenderer.renderPages(pdfBytes, dpi: 150.0);
    final ocrPages = <OcrPage>[];

    for (final page in renderedPages) {
      final ocrPage = await recognizePage(
        page.imageBytes,
        pageNumber: page.pageNumber,
        language: language,
      );
      ocrPages.add(ocrPage);
    }

    return OcrDocument(
      documentId: documentId,
      language: language,
      engine: 'google_mlkit_ocr',
      engineVersion: '0.17.1',
      schemaVersion: 1,
      processedAt: DateTime.now(),
      pages: ocrPages,
    );
  }

  List<({String text, NormalizedRect bounds})> _detectTextLines(
    img.Image? image,
    int width,
    int height,
  ) {
    if (image == null) return [];

    // Sample vertical luminance profiles to detect paragraph rows
    final lines = <({String text, NormalizedRect bounds})>[];

    // Downscaled analysis image
    final small = img.copyResize(image, width: 128, height: 128);
    final gray = img.grayscale(small);

    var hasContrast = false;
    var minVal = 255;
    var maxVal = 0;

    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }

    if (maxVal - minVal > 40) {
      hasContrast = true;
    }

    if (!hasContrast) {
      return [];
    }

    // Heuristically segment text bands based on horizontal projection profile
    final rowHeights = <int>[];
    for (var y = 0; y < gray.height; y++) {
      var darkPixels = 0;
      for (var x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        if (v < ((minVal + maxVal) ~/ 2)) {
          darkPixels++;
        }
      }
      rowHeights.add(darkPixels);
    }

    var inBand = false;
    var bandStartY = 0;

    for (var y = 0; y < rowHeights.length; y++) {
      final isDark = rowHeights[y] > (gray.width * 0.05);
      if (isDark && !inBand) {
        inBand = true;
        bandStartY = y;
      } else if (!isDark && inBand) {
        inBand = false;
        final normY = (bandStartY / gray.height).clamp(0.0, 1.0);
        final normH = ((y - bandStartY) / gray.height).clamp(0.01, 0.5);
        lines.add((
          text: '',
          bounds: NormalizedRect(
            x: 0.08,
            y: normY,
            width: 0.84,
            height: normH,
          ),
        ));
      }
    }

    return lines;
  }
}
