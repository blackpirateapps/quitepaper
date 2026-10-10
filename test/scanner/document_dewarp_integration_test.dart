import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/scan_mode.dart';

Uint8List _pageOnDarkBg({int size = 600}) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  for (final p in image) {
    p.setRgb(28, 28, 28);
  }
  // A bright inset "page" from 15%..85%.
  final lo = (size * 0.15).round();
  final hi = (size * 0.85).round();
  for (var y = lo; y < hi; y++) {
    for (var x = lo; x < hi; x++) {
      image.setPixelRgb(x, y, 235, 235, 235);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  const processor = DartImageProcessor();

  group('ImageProcessor corner-detection / dewarp integration', () {
    test('detectDocumentQuad finds the inset page with confidence', () async {
      final result = await processor.detectDocumentQuad(_pageOnDarkBg());
      expect(result.confidence, greaterThan(0.3));
      expect(result.quad.isFullFrame, isFalse);
      final bounds = result.quad.boundingRect;
      expect(bounds.x, greaterThan(0.03));
      expect(bounds.width, lessThan(0.97));
    });

    test('processHighResolution dewarps a non-full quad to its own rectangle', () async {
      final bytes = _pageOnDarkBg(size: 800);
      // A skewed quad (keystone): top edge narrower than bottom.
      const quad = NormalizedQuad(
        topLeft: NormalizedPoint(0.25, 0.15),
        topRight: NormalizedPoint(0.75, 0.15),
        bottomRight: NormalizedPoint(0.9, 0.85),
        bottomLeft: NormalizedPoint(0.1, 0.85),
      );

      final warped = await processor.processHighResolution(
        bytes,
        ImageAdjustments.neutral,
        documentQuad: quad,
      );
      final full = await processor.processHighResolution(
        bytes,
        ImageAdjustments.neutral,
      );

      final warpedImg = img.decodeImage(warped.imageBytes);
      expect(warpedImg, isNotNull);
      expect(warped.width, greaterThan(0));
      // Dewarp crops to the quad, so output differs in size from the full frame.
      expect(warped.width != full.width || warped.height != full.height, isTrue);
    });

    test('dewarp composes with a capture mode', () async {
      final bytes = _pageOnDarkBg(size: 700);
      const quad = NormalizedQuad(
        topLeft: NormalizedPoint(0.2, 0.2),
        topRight: NormalizedPoint(0.8, 0.18),
        bottomRight: NormalizedPoint(0.82, 0.8),
        bottomLeft: NormalizedPoint(0.18, 0.82),
      );
      final result = await processor.processHighResolution(
        bytes,
        ImageAdjustments.neutral,
        mode: ScanMode.blackAndWhite,
        documentQuad: quad,
      );
      expect(img.decodeImage(result.imageBytes), isNotNull);
      expect(result.width, greaterThan(0));
    });

    test('full-frame quad is treated as no dewarp', () async {
      final bytes = _pageOnDarkBg(size: 500);
      final full = await processor.processHighResolution(
        bytes,
        ImageAdjustments.neutral,
        documentQuad: NormalizedQuad.full,
      );
      expect(full.imageBytes, isNotEmpty);
    });
  });
}
