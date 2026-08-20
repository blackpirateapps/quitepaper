import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/features/scanner/application/pdf_builder.dart';
import 'package:quitepaper/features/scanner/domain/scanned_page.dart';

void main() {
  group('PdfBuilder Tests', () {
    const pdfBuilder = PdfBuilder();

    Uint8List createSampleImage(int width, int height) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      return Uint8List.fromList(img.encodeJpg(image));
    }

    test('Compiles multi-page PDF preserving page sequence and dimensions', () async {
      final img1 = createSampleImage(300, 400);
      final img2 = createSampleImage(300, 400);

      final pages = [
        ScannedPage(
          id: 'page-1',
          imageBytes: img1,
          width: 300,
          height: 400,
          pageNumber: 1,
        ),
        ScannedPage(
          id: 'page-2',
          imageBytes: img2,
          width: 300,
          height: 400,
          pageNumber: 2,
        ),
      ];

      final pdfBytes = await pdfBuilder.buildPdfFromPages(pages);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));

      // PDF files always begin with '%PDF-'
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('Throws ArgumentError when attempting to build PDF from empty pages', () async {
      expect(
        () => pdfBuilder.buildPdfFromPages([]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
