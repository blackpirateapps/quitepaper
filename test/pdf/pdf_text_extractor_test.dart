import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/pdf/pdf_text_extractor.dart';

void main() {
  group('PdfTextExtractor Embedded Text Layer Heuristic Tests', () {
    late DefaultPdfTextExtractor extractor;

    setUp(() {
      extractor = const DefaultPdfTextExtractor();
    });

    test('Returns hasUsableText: false for raw raster binary with no text layer', () async {
      final rasterFakePdf = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final result = await extractor.extractText(rasterFakePdf);

      expect(result.hasUsableText, isFalse);
      expect(result.pages, isEmpty);
    });

    test('Extracts text streams and constructs structured OcrPages when text is present', () async {
      const mockPdfStream = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
5 0 obj
<< /Length 100 >>
stream
BT
/F1 12 Tf
(Quiet Paper Private Encrypted Note) Tj
(Second line of confidential document) Tj
ET
endstream
endobj
%%EOF
''';

      final pdfBytes = Uint8List.fromList(utf8.encode(mockPdfStream));
      final result = await extractor.extractText(pdfBytes);

      expect(result.hasUsableText, isTrue);
      expect(result.pages.isNotEmpty, isTrue);
      expect(result.extractedText, contains('Quiet Paper Private Encrypted Note'));
      expect(result.extractedText, contains('Second line of confidential document'));
    });
  });
}
