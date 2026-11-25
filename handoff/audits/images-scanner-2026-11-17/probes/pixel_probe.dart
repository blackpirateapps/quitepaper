// Historical characterization probes: these assert the defects at the audited
// baseline, not the desired fixed behavior. Run explicitly with flutter test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_compression_service.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/scan_geometry.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/pdf/pdf_generator.dart';
import 'package:quitepaper/features/scanner/domain/scanned_page.dart';
// Use the PDF viewer's existing transitive parser to inspect real PDF MediaBox.
// ignore: depend_on_referenced_packages
import 'package:syncfusion_flutter_pdf/pdf.dart';

Uint8List jpeg(img.Image image) =>
    Uint8List.fromList(img.encodeJpg(image, quality: 95));

img.Image quadrants() {
  final image = img.Image(width: 240, height: 160);
  for (final p in image) {
    if (p.y < 80) {
      p.setRgb(p.x < 120 ? 255 : 0, p.x < 120 ? 0 : 255, 0);
    } else {
      p.setRgb(p.x < 120 ? 0 : 255, p.x < 120 ? 0 : 255, 255);
    }
  }
  return image;
}

List<int> center(img.Image image) {
  final p = image.getPixel(image.width ~/ 2, image.height ~/ 2);
  return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const processor = DartImageProcessor();
  const crop = NormalizedRect(x: 0.05, y: 0.05, width: 0.4, height: 0.4);

  test(
    'IS-01 rotated rectangle exports blue instead of selected red',
    () async {
      final result = await processor.processHighResolution(
        jpeg(quadrants()),
        const ImageAdjustments(crop: crop, rotationQuarterTurns: 1),
      );
      final actual = center(img.decodeImage(result.imageBytes)!);
      debugPrint('IS-01 rectangle center=$actual; expected red [255,0,0]');
      expect(actual[2], greaterThan(230));
      expect(actual[0], lessThan(20));
    },
  );

  test('IS-01 rotated quad exports blue instead of selected red', () async {
    final result = await processor.processHighResolution(
      jpeg(quadrants()),
      const ImageAdjustments(rotationQuarterTurns: 1),
      documentQuad: NormalizedQuad.fromRect(crop),
    );
    final actual = center(img.decodeImage(result.imageBytes)!);
    final selected = ScanGeometry.dewarp(
      quadrants(),
      NormalizedQuad.fromRect(crop),
    );
    expect(center(selected)[0], 255);
    debugPrint('IS-01 quad center=$actual; expected rotated red');
    expect(actual[2], greaterThan(230));
    expect(actual[0], lessThan(20));
  });

  test(
    'IS-03 brightness preview lifts black, exported bitmap stays black',
    () async {
      final source = img.Image(width: 80, height: 80);
      const adjustment = ImageAdjustments(brightness: 1);
      final expected = adjustment.toColorMatrix()[4];
      final result = await processor.processHighResolution(
        jpeg(source),
        adjustment,
      );
      final actual = center(img.decodeImage(result.imageBytes)!)[0];
      debugPrint('IS-03 preview black=$expected, exported black=$actual');
      expect(expected, 128);
      expect(actual, lessThan(5));
    },
  );

  test('IS-05 synchronous preview preparation blocks queued callbacks', () async {
    // Fixture creation is outside the measured region. JPEG has real blocks,
    // paper shading and text-like stripes; input is 12 MP camera-sized.
    final source = img.Image(width: 4000, height: 3000);
    for (final p in source) {
      final v = (p.y % 37 < 4 && p.x % 100 < 80) ? 35 : 170 + p.x % 70;
      p.setRgb(v, v, v);
    }
    final bytes = jpeg(source);
    await processor.createPageRepresentations(jpeg(quadrants())); // warm-up
    final samples = <Map<String, Object>>[];
    for (var i = 0; i < 3; i++) {
      var callbackRan = false;
      final queued = Timer(Duration.zero, () => callbackRan = true);
      final sw = Stopwatch()..start();
      final future = processor.createPageRepresentations(bytes);
      final syncMs = sw.elapsedMicroseconds / 1000;
      final ranBeforeReturn = callbackRan;
      final reps = await future;
      sw.stop();
      queued.cancel();
      samples.add({
        'sync_ms': syncMs,
        'total_ms': sw.elapsedMicroseconds / 1000,
        'callback_before_return': ranBeforeReturn,
        'source_bytes': bytes.length,
        'preview_bytes': reps.previewBytes.length,
        'thumbnail_bytes': reps.thumbnailBytes.length,
      });
      expect(ranBeforeReturn, isFalse);
      expect(img.decodeJpg(reps.previewBytes)!.width, 600);
      expect(img.decodeJpg(reps.thumbnailBytes)!.width, 200);
    }
    debugPrint('IS-05 ${jsonEncode(samples)}');
    // Record measurements, not a machine-dependent timing gate.
    File(
      'handoff/audits/images-scanner-2026-11-17/evidence/flutter-preparation.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(samples));
  });

  test('landscape PDF page geometry measurement', () async {
    final source = quadrants();
    final pdf = await const DefaultPdfGenerator().generatePdf([
      ScannedPage(
        id: 'landscape',
        imageBytes: jpeg(source),
        width: 240,
        height: 160,
        pageNumber: 1,
      ),
    ]);
    final document = PdfDocument(inputBytes: pdf);
    final size = document.pages[0].size;
    debugPrint(
      'Landscape source aspect=1.5, PDF aspect=${size.width / size.height}, size=$size',
    );
    expect((size.width / size.height - 1.5).abs(), greaterThan(0.05));
    document.dispose();
  });

  test('animated GIF compression frame count measurement', () async {
    final first = img.Image(width: 120, height: 120);
    img.fill(first, color: img.ColorRgb8(255, 0, 0));
    final second = img.Image(width: 120, height: 120);
    img.fill(second, color: img.ColorRgb8(0, 255, 0));
    first.addFrame(second);
    final bytes = Uint8List.fromList(img.encodeGif(first));
    expect(img.decodeGif(bytes)!.numFrames, 2);
    final result = await const DefaultImageCompressionService().compressImage(
      rawBytes: bytes,
      fileName: 'animated.gif',
      force: true,
    );
    final output = img.decodeImage(result.bytes)!;
    debugPrint(
      'GIF input=${bytes.length} output=${result.bytes.length} compressed=${result.wasCompressed} '
      'mime=${result.mimeType} frames=${output.numFrames}',
    );
    // This solid-color fixture may hit the size safeguard; a larger fixture is
    // used separately if needed. Here always require valid decodable output.
    expect(output.width, 120);
  });
  test('IS-08 eligible GIF loses animation without force', () async {
    final random = math.Random(42);
    final animation = img.Image(width: 400, height: 400);
    for (var frameIndex = 0; frameIndex < 4; frameIndex++) {
      final frame = frameIndex == 0
          ? animation
          : img.Image(width: 400, height: 400);
      for (final pixel in frame) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      if (frameIndex != 0) animation.addFrame(frame);
    }
    final bytes = Uint8List.fromList(img.encodeGif(animation));
    expect(bytes.length, greaterThan(500 * 1024));
    expect(img.decodeGif(bytes)!.numFrames, 4);
    final result = await const DefaultImageCompressionService().compressImage(
      rawBytes: bytes,
      fileName: 'eligible-animation.gif',
    );
    expect(result.wasCompressed, isTrue);
    expect(img.decodeImage(result.bytes)!.numFrames, 1);
    debugPrint(
      'IS-08 normal eligible GIF: input=${bytes.length} output=${result.bytes.length} frames=4 -> 1',
    );
  });
}
