import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

void main() {
  group('OCR Adaptive Lower-Resolution Enhancement Tests', () {
    test('DartImageProcessor.enhanceForOcr clamps oversized image to maxDimension 1600', () async {
      // Create a 2400x3200 test image (portrait, oversized)
      final rawImage = img.Image(width: 2400, height: 3200);
      img.fill(rawImage, color: img.ColorRgb8(255, 255, 255));
      // Draw some black text-like pixels
      for (var y = 1000; y < 1100; y++) {
        for (var x = 500; x < 1900; x++) {
          rawImage.setPixel(x, y, img.ColorRgb8(0, 0, 0));
        }
      }

      final rawBytes = Uint8List.fromList(img.encodePng(rawImage));
      expect(rawImage.width, 2400);
      expect(rawImage.height, 3200);

      final enhancedBytes = await const DartImageProcessor().enhanceForOcr(
        rawBytes,
        maxDimension: PdfRasterPolicy.maxOcrDimension,
      );

      final enhancedImage = img.decodeImage(enhancedBytes);
      expect(enhancedImage, isNotNull);
      // Longest dimension must be clamped to 1600
      expect(enhancedImage!.height, equals(1600));
      // Width must scale proportionally: 2400 * (1600 / 3200) = 1200
      expect(enhancedImage.width, equals(1200));
    });

    test('DartImageProcessor.enhanceForOcr preserves smaller image dimensions without upscaling', () async {
      // Create an 800x1000 image (already smaller than 1600)
      final rawImage = img.Image(width: 800, height: 1000);
      img.fill(rawImage, color: img.ColorRgb8(255, 255, 255));
      final rawBytes = Uint8List.fromList(img.encodePng(rawImage));

      final enhancedBytes = await const DartImageProcessor().enhanceForOcr(
        rawBytes,
        maxDimension: 1600,
      );

      final enhancedImage = img.decodeImage(enhancedBytes);
      expect(enhancedImage, isNotNull);
      expect(enhancedImage!.width, equals(800));
      expect(enhancedImage.height, equals(1000));
    });

    test('PdfRasterPolicy assigns 90 DPI for large PDFs (>8MB) and 150 DPI for small PDFs', () {
      final smallPdf = Uint8List(5 * 1024 * 1024); // 5MB
      final largePdf = Uint8List(12 * 1024 * 1024); // 12MB

      expect(PdfRasterPolicy.isLarge(smallPdf), isFalse);
      expect(PdfRasterPolicy.ocrDpi(smallPdf), equals(150.0));

      expect(PdfRasterPolicy.isLarge(largePdf), isTrue);
      expect(PdfRasterPolicy.ocrDpi(largePdf), equals(90.0));
    });
  });
}
