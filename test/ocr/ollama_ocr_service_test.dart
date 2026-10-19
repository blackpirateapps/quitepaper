import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_service.dart';
import 'package:quitepaper/core/ocr/ollama_ocr_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

class _FakePdfPageRenderer implements PdfPageRenderer {
  const _FakePdfPageRenderer(this.pages);
  final List<RenderedPage> pages;

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    return pages;
  }

  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    if (pageIndex >= 0 && pageIndex < pages.length) {
      return pages[pageIndex];
    }
    return null;
  }
}

void main() {
  group('OllamaOcrService Tests', () {
    late Uint8List testImageBytes;

    setUp(() {
      // Create a minimal 50x50 PNG test image
      final image = img.Image(width: 50, height: 50);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      testImageBytes = Uint8List.fromList(img.encodePng(image));
    });

    test('defaultPrompt uses canonical DeepSeek-OCR grounding prompt without conversational instructions', () {
      expect(OllamaOcrService.defaultPrompt, '<|grounding|>Convert the document to markdown.');
    });

    test('recognizePage successfully queries Ollama /api/generate and returns structured OcrPage', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/generate');
        expect(request.method, 'POST');

        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-ocr');
        expect(body['prompt'], contains('Convert the document to markdown.'));
        expect(body['stream'], isFalse);
        expect(body['images'], isNotEmpty);

        return http.Response(
          json.encode({
            'model': 'deepseek-ocr',
            'response': '# Scanned Title\n\n- Item 1\n- Item 2\n\n| Col A | Col B |\n|---|---|\n| 1 | 2 |',
            'done': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = OllamaOcrService(
        httpClient: mockClient,
        endpoint: 'http://127.0.0.1:11434',
        model: 'deepseek-ocr',
      );

      final page = await service.recognizePage(
        testImageBytes,
        pageNumber: 1,
        language: OcrLanguage.english,
      );

      expect(page.pageNumber, 1);
      expect(page.source, OcrSource.onDeviceOcr);
      expect(page.plainText, contains('# Scanned Title'));
      expect(page.plainText, contains('| Col A | Col B |'));
      expect(page.blocks.length, 3);
      expect(page.blocks.first.text, '# Scanned Title');
      expect(page.blocks.first.bounds.width, 0.90);
      expect(page.blocks.first.lines, isNotEmpty);
      expect(page.blocks.first.lines.first.words, isNotEmpty);
    });

    test('recognizePage parses grounded DeepSeek-OCR output into clean plain text and structured blocks', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'model': 'deepseek-ocr',
            'response': '''
image[[22, 127, 452, 646]]
text[[4, 641, 450, 789]]
In cyclic quadrilateral (चक्रीय चतुर्भुज)
\\(a + c = b + d = 180^\\circ\\)
''',
            'done': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = OllamaOcrService(
        httpClient: mockClient,
        endpoint: 'http://127.0.0.1:11434',
        model: 'deepseek-ocr',
      );

      final page = await service.recognizePage(
        testImageBytes,
        pageNumber: 1,
        language: OcrLanguage.english,
      );

      expect(page.pageNumber, 1);
      expect(page.plainText, isNot(contains('image[[')));
      expect(page.plainText, isNot(contains('text[[')));
      expect(page.plainText, contains('In cyclic quadrilateral (चक्रीय चतुर्भुज)'));
      expect(page.plainText, contains(r'\(a + c = b + d = 180^\circ\)'));

      expect(page.blocks.length, 1);
      final block = page.blocks.first;
      expect(block.bounds.x, closeTo(0.004, 0.001));
      expect(block.bounds.y, closeTo(0.641, 0.001));
      expect(block.bounds.width, closeTo(0.446, 0.001));
      expect(block.bounds.height, closeTo(0.148, 0.001));
      expect(block.lines.length, 2);
      expect(block.lines.first.words, isNotEmpty);
    });

    test('recognizePage throws OllamaOcrException on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Model not found', 404);
      });

      final service = OllamaOcrService(
        httpClient: mockClient,
      );

      expect(
        () => service.recognizePage(
          testImageBytes,
          pageNumber: 1,
          language: OcrLanguage.english,
        ),
        throwsA(isA<OllamaOcrException>()),
      );
    });

    test('recognizeDocument renders all pages and assigns engine metadata', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'response': 'Recognized Page Text',
            'done': true,
          }),
          200,
        );
      });

      final fakeRenderer = _FakePdfPageRenderer([
        RenderedPage(
          pageNumber: 1,
          width: 50,
          height: 50,
          imageBytes: testImageBytes,
        ),
        RenderedPage(
          pageNumber: 2,
          width: 50,
          height: 50,
          imageBytes: testImageBytes,
        ),
      ]);

      final service = OllamaOcrService(
        httpClient: mockClient,
        pageRenderer: fakeRenderer,
        model: 'deepseek-ocr:latest',
      );

      final doc = await service.recognizeDocument(
        Uint8List(10),
        documentId: 'doc-123',
      );

      expect(doc.documentId, 'doc-123');
      expect(doc.engine, 'ollama_deepseek_ocr');
      expect(doc.engineVersion, 'deepseek-ocr:latest');
      expect(doc.pages.length, 2);
      expect(doc.pages[0].plainText, 'Recognized Page Text');
      expect(doc.pages[1].plainText, 'Recognized Page Text');
    });

    test('DefaultOcrService delegates to OllamaOcrService on desktop and falls back on error', () async {
      // 1. Successful delegation
      var calledOllama = false;
      final mockClient = MockClient((request) async {
        calledOllama = true;
        return http.Response(
          json.encode({
            'response': 'DeepSeek Extracted Content',
            'done': true,
          }),
          200,
        );
      });

      final ollamaService = OllamaOcrService(
        httpClient: mockClient,
      );

      final defaultService = DefaultOcrService(
        enableMlKit: false, // Ensure desktop/test fallback route
        ollamaOcrService: ollamaService,
      );

      final result = await defaultService.recognizePage(
        testImageBytes,
        pageNumber: 1,
        language: OcrLanguage.english,
      );

      // On Linux/Desktop runtime (where unit tests execute), it delegates to Ollama
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows)) {
        expect(calledOllama, isTrue);
        expect(result.plainText, 'DeepSeek Extracted Content');
      }

      // 2. Fallback when Ollama throws
      final failingClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final failingOllamaService = OllamaOcrService(
        httpClient: failingClient,
      );

      final fallbackService = DefaultOcrService(
        enableMlKit: false,
        ollamaOcrService: failingOllamaService,
      );

      final fallbackResult = await fallbackService.recognizePage(
        testImageBytes,
        pageNumber: 1,
        language: OcrLanguage.english,
      );

      // Successfully fell back to CV fallback without throwing exception
      expect(fallbackResult.pageNumber, 1);
    });
  });
}
