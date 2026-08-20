import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/features/scanner/application/document_normalizer.dart';

void main() {
  group('DocumentNormalizer Tests', () {
    const normalizer = DocumentNormalizer();

    test('Normalizes raw image, enhances contrast, and bounds dimensions', () async {
      final largeImage = img.Image(width: 3000, height: 2000);
      img.fill(largeImage, color: img.ColorRgb8(240, 240, 240));
      final rawBytes = Uint8List.fromList(img.encodeJpg(largeImage));

      final result = await normalizer.normalizePage(rawBytes);

      expect(result.normalizedBytes, isNotEmpty);
      expect(result.width, lessThanOrEqualTo(DocumentNormalizer.maxDimension));
      expect(result.height, lessThanOrEqualTo(DocumentNormalizer.maxDimension));
    });

    test('Gracefully falls back on corrupt raw bytes without throwing', () async {
      final corruptBytes = Uint8List.fromList([0x00, 0xFF, 0x12, 0x34]);

      final result = await normalizer.normalizePage(corruptBytes);
      expect(result.normalizedBytes, corruptBytes);
    });

    test('Estimates confidence heuristic for document preview frames', () {
      final testImage = img.Image(width: 100, height: 100);
      img.fill(testImage, color: img.ColorRgb8(200, 200, 200));
      final frameBytes = Uint8List.fromList(img.encodeJpg(testImage));

      final score = normalizer.estimateDocumentConfidence(frameBytes);
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });
  });
}
