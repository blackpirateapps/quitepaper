import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

void main() {
  const processor = DartImageProcessor();
  test('IS-01 crop and quad select source pixels before every rotation', () async {
    final source = img.Image(width: 240, height: 160);
    for (final p in source) {
      p.setRgb(p.x < 120 && p.y < 80 ? 255 : 0, 0, p.y >= 80 ? 255 : 0);
    }
    final bytes = Uint8List.fromList(img.encodePng(source));
    const crop = NormalizedRect(x: .05, y: .05, width: .4, height: .4);
    for (var turns = 0; turns < 4; turns++) {
      final adjustment = ImageAdjustments(crop: crop, rotationQuarterTurns: turns);
      final results = [
        await processor.process(bytes, adjustment),
        (await processor.processHighResolution(bytes, adjustment)).imageBytes,
        (await processor.processHighResolution(bytes,
          ImageAdjustments(rotationQuarterTurns: turns),
          documentQuad: NormalizedQuad.fromRect(crop))).imageBytes,
      ];
      for (final result in results) {
        final decoded = img.decodeImage(result)!;
        final pixel = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
        expect(pixel.r, greaterThan(230));
        expect(pixel.b, lessThan(20));
        expect(decoded.width > decoded.height, turns.isEven);
      }
    }
  });
}
