import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/pdf/pdf_generator.dart';
import 'package:quitepaper/features/scanner/application/pdf_builder.dart';
import 'package:quitepaper/features/scanner/domain/scanned_page.dart';
// Inspect actual MediaBox dimensions produced by both generators.
// ignore: depend_on_referenced_packages
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('IS-07 both PDF generators preserve every page aspect ratio', () async {
    final pages = [for (final size in [(240,160), (300,100), (100,200), (160,160)])
      ScannedPage(id: '$size', width: size.$1, height: size.$2,
        pageNumber: 1, imageBytes: Uint8List.fromList(img.encodeJpg(
          img.Image(width: size.$1, height: size.$2))))];
    for (final bytes in [
      await const DefaultPdfGenerator().generatePdf(pages),
      await const PdfBuilder().buildPdfFromPages(pages),
    ]) {
      final pdf = PdfDocument(inputBytes: bytes);
      try {
        expect(pdf.pages.count, pages.length);
        for (var i = 0; i < pages.length; i++) {
          final size = pdf.pages[i].size;
          expect(size.width / size.height, closeTo(pages[i].width / pages[i].height, .0001));
        }
      } finally {
        pdf.dispose();
      }
    }
  });
}
