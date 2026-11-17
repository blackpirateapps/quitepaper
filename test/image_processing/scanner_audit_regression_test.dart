import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:quitepaper/core/image_processing/image_compression_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

void main() {
  const processor = DartImageProcessor();
  test('IS-08 forced and threshold GIF compression preserve animation bytes', () async {
    final random = Random(42);
    for (final large in [false, true]) {
      final animation = img.Image(width: large ? 400 : 120, height: large ? 400 : 120);
      for (var i = 0; i < 4; i++) {
        final frame = i == 0 ? animation : img.Image(width: animation.width, height: animation.height);
        frame.frameDuration = (i + 1) * 100;
        for (final pixel in frame) {
          pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
        }
        if (i != 0) animation.addFrame(frame);
      }
      final bytes = Uint8List.fromList(img.encodeGif(animation));
      if (large) { expect(bytes.length, greaterThan(500 * 1024)); }
      final result = await const DefaultImageCompressionService().compressImage(
        rawBytes: bytes, fileName: 'animation.gif', force: !large);
      expect(result.bytes, bytes);
      expect(result.wasCompressed, isFalse);
      expect(result.mimeType, 'image/gif');
      expect(result.fileName, 'animation.gif');
      expect(img.decodeGif(result.bytes)!.numFrames, 4);
    }
  });
  test('IS-05 preparation and neutral export yield while workers run', () async {
    final source = img.Image(width: 1400, height: 1000);
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    var ticks = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => ticks++);
    try {
      final reps = await Future.wait(List.generate(3, (_) => processor.createPageRepresentations(bytes)));
      expect(ticks, greaterThan(0));
      expect(reps.first.width, 1400);
      expect(img.decodeImage(reps.first.previewBytes)!.width, 600);
      expect(img.decodeImage(reps.first.thumbnailBytes)!.width, 200);
      ticks = 0;
      final result = await processor.processHighResolution(bytes, ImageAdjustments.neutral);
      expect(ticks, greaterThan(0));
      expect(result.imageBytes, bytes);
      expect(result.width, 1400);
    } finally {
      timer.cancel();
    }
  });
  test('IS-03 both export paths match the preview color matrix', () async {
    for (final rgb in [[0, 0, 0], [70, 120, 180], [240, 220, 200]]) {
      final source = img.Image(width: 40, height: 40);
      img.fill(source, color: img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
      final bytes = Uint8List.fromList(img.encodePng(source));
      for (final adjustment in [
        const ImageAdjustments(brightness: 1),
        const ImageAdjustments(brightness: -.3, contrast: .4, saturation: -.5),
        const ImageAdjustments(grayscale: true, contrast: -.5, brightness: .2),
      ]) {
        final matrix = adjustment.toColorMatrix();
        final expected = [for (final offset in [0, 5, 10])
          (matrix[offset] * rgb[0] + matrix[offset+1] * rgb[1] +
            matrix[offset+2] * rgb[2] + matrix[offset+4]).round().clamp(0,255)];
        final outputs = [await processor.process(bytes, adjustment),
          (await processor.processHighResolution(bytes, adjustment)).imageBytes];
        for (final output in outputs) {
          final p = img.decodeImage(output)!.getPixel(20, 20);
          for (var c = 0; c < 3; c++) {
            expect([p.r, p.g, p.b][c], closeTo(expected[c], 3));
          }
        }
      }
    }
  });
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
