import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../pdf/pdf_page_renderer.dart';
import 'ocr_models.dart';
import 'ocr_service.dart';
import 'ollama_grounding_parser.dart';

/// Implementation of [OcrService] powered by a local Ollama daemon running DeepSeek-OCR.
///
/// Converts document images and PDF pages directly into clean structured Markdown
/// using local inference via Ollama's REST API (`POST /api/generate`), preserving
/// 100% zero-knowledge offline privacy.
class OllamaOcrService implements OcrService {
  const OllamaOcrService({
    this.endpoint = defaultEndpoint,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 180),
    this.httpClient,
    PdfPageRenderer? pageRenderer,
  })  : _pageRenderer = pageRenderer ?? const DefaultPdfPageRenderer();

  static const String defaultEndpoint = 'http://127.0.0.1:11434';
  static const String defaultModel = 'deepseek-ocr';

  /// Standard prompt instructing DeepSeek-OCR to transcribe the page into Markdown.
  static const String defaultPrompt = '<|grounding|>Convert the document to markdown.';

  final String endpoint;
  final String model;
  final Duration timeout;
  final http.Client? httpClient;
  final PdfPageRenderer _pageRenderer;

  @override
  Future<OcrPage> recognizePage(
    Uint8List imageBytes, {
    required int pageNumber,
    required OcrLanguage language,
  }) async {
    debugPrint('[QuietPaper Ollama OCR] Recognizing page $pageNumber using $model at $endpoint...');

    final decoded = img.decodeImage(imageBytes);
    final width = decoded?.width ?? 1000;
    final height = decoded?.height ?? 1414;

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final base64Image = base64Encode(imageBytes);
      final uri = Uri.parse('$endpoint/api/generate');

      final payload = jsonEncode({
        'model': model,
        'prompt': defaultPrompt,
        'images': [base64Image],
        'stream': false,
      });

      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw OllamaOcrException(
          'Ollama returned HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = (jsonResponse['response'] as String? ?? '').trim();

      debugPrint('[QuietPaper Ollama OCR] Page $pageNumber recognition completed (${rawText.length} chars).');

      final parsed = OllamaGroundingParser.parse(rawText);

      return OcrPage(
        pageNumber: pageNumber,
        plainText: parsed.cleanPlainText,
        width: width,
        height: height,
        source: OcrSource.onDeviceOcr,
        blocks: parsed.blocks,
      );
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
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
      engine: 'ollama_deepseek_ocr',
      engineVersion: model,
      schemaVersion: 1,
      processedAt: DateTime.now(),
      pages: ocrPages,
    );
  }
}

/// Structured exception thrown when Ollama OCR request fails.
class OllamaOcrException implements Exception {
  const OllamaOcrException(this.message);
  final String message;

  @override
  String toString() => 'OllamaOcrException: $message';
}
