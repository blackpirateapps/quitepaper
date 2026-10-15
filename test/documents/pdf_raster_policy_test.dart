import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

void main() {
  group('PdfRasterPolicy', () {
    test('limits raster DPI for oversized pages', () {
      final pdf = _pdfWithPage(2550, 3510);

      expect(PdfRasterPolicy.safeDpi(pdf, 150), lessThan(50));
      expect(PdfRasterPolicy.shouldSkipOcr(pdf), isTrue);
    });

    test('allows OCR for a small PDF page', () {
      final pdf = _pdfWithPage(612, 792);

      expect(PdfRasterPolicy.safeDpi(pdf, 150), 150);
      expect(PdfRasterPolicy.shouldSkipOcr(pdf), isFalse);
    });

    test('skips OCR when the source PDF exceeds the byte limit', () {
      final pdf = Uint8List(8 * 1024 * 1024 + 1);

      expect(PdfRasterPolicy.shouldSkipOcr(pdf), isTrue);
    });
  });
}

Uint8List _pdfWithPage(int width, int height) => Uint8List.fromList(
  utf8.encode('''
%PDF-1.4
1 0 obj
<< /Type /Page /MediaBox [0 0 $width $height] >>
endobj
'''),
);
