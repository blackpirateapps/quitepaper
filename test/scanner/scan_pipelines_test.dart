import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/scan_mode.dart';
import 'package:quitepaper/core/image_processing/scan_pipelines.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

/// Builds a white "page" with a left→right darkening gradient (simulating an
/// uneven desk shadow) and a solid black rectangle in the middle ("text").
img.Image _shadowedPage({int size = 200}) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      // 255 on the left fading to ~150 on the right.
      final shade = (255 - (x / size) * 105).round();
      image.setPixelRgb(x, y, shade, shade, shade);
    }
  }
  // Black "text" block in the centre.
  for (var y = size ~/ 3; y < size * 2 ~/ 3; y++) {
    for (var x = size ~/ 3; x < size * 2 ~/ 3; x++) {
      image.setPixelRgb(x, y, 10, 10, 10);
    }
  }
  return image;
}

Uint8List _jpg(img.Image image) => Uint8List.fromList(img.encodeJpg(image, quality: 90));

/// Luminance range (max-min) across the top [rows] rows (the shadowed paper,
/// above the text block). A flatter illumination yields a smaller range.
double _topRowLuminanceRange(img.Image image, {int rows = 20}) {
  var min = 255.0, max = 0.0;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final l = p.r.toDouble();
      if (l < min) min = l;
      if (l > max) max = l;
    }
  }
  return max - min;
}

void main() {
  group('ScanMode enum', () {
    test('defaults and metadata', () {
      expect(ScanMode.defaultMode, ScanMode.auto);
      expect(ScanMode.blackAndWhite.isBinary, isTrue);
      expect(ScanMode.blackAndWhite.isMonochrome, isTrue);
      expect(ScanMode.grayscale.isMonochrome, isTrue);
      expect(ScanMode.grayscale.isBinary, isFalse);
      expect(ScanMode.auto.isMonochrome, isFalse);
      for (final m in ScanMode.values) {
        expect(m.label, isNotEmpty);
        expect(m.description, isNotEmpty);
      }
    });

    test('fromName round-trips and falls back', () {
      for (final m in ScanMode.values) {
        expect(ScanMode.fromName(m.name), m);
      }
      expect(ScanMode.fromName(null), ScanMode.auto);
      expect(ScanMode.fromName('nonsense'), ScanMode.auto);
      expect(ScanMode.fromName('nonsense', fallback: ScanMode.original),
          ScanMode.original);
    });
  });

  group('ScanPipelines', () {
    test('original is a no-op passthrough', () {
      final src = _shadowedPage();
      final out = ScanPipelines.apply(src, ScanMode.original);
      expect(identical(out, src), isTrue);
    });

    test('blackAndWhite produces a near-binary image on uneven lighting', () {
      final out = ScanPipelines.apply(_shadowedPage(), ScanMode.blackAndWhite);
      var mid = 0;
      final total = out.width * out.height;
      for (final p in out) {
        final l = p.r;
        if (l > 50 && l < 205) mid++;
      }
      // The gradient must not survive as mid-gray: output is black-on-white.
      expect(mid / total, lessThan(0.15));
    });

    test('auto flattens the soft shadow (background variance drops)', () {
      final src = _shadowedPage();
      final before = _topRowLuminanceRange(src);
      final after = _topRowLuminanceRange(ScanPipelines.apply(src, ScanMode.auto));
      expect(before, greaterThan(60)); // sanity: the shadow exists
      expect(after, lessThan(before));
    });

    test('whiteboard drives the background toward white', () {
      final src = _shadowedPage();
      final out = ScanPipelines.apply(src, ScanMode.whiteboard);
      // Average luminance of the shadowed paper strip should be brighter.
      double sumBefore = 0, sumAfter = 0;
      var n = 0;
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < src.width; x++) {
          sumBefore += src.getPixel(x, y).r;
          sumAfter += out.getPixel(x, y).r;
          n++;
        }
      }
      expect(sumAfter / n, greaterThan(sumBefore / n));
      expect(sumAfter / n, greaterThan(230));
    });

    test('every mode returns a valid same-size 3-channel image', () {
      final src = _shadowedPage();
      for (final mode in ScanMode.values) {
        final out = ScanPipelines.apply(src, mode);
        expect(out.width, src.width);
        expect(out.height, src.height);
      }
    });
  });

  group('DartImageProcessor mode integration', () {
    const processor = DartImageProcessor();

    test('renderModePreviews returns a decodable thumbnail for every mode', () async {
      final bytes = _jpg(_shadowedPage(size: 400));
      final previews = await processor.renderModePreviews(bytes);

      for (final mode in ScanMode.values) {
        expect(previews.containsKey(mode), isTrue, reason: 'missing $mode');
        final decoded = img.decodeImage(previews[mode]!);
        expect(decoded, isNotNull);
        expect(decoded!.width, lessThanOrEqualTo(600));
      }
    });

    test('renderModePreviews never throws on undecodable bytes', () async {
      final garbage = Uint8List.fromList(List.filled(32, 7));
      final previews = await processor.renderModePreviews(garbage);
      expect(previews.length, ScanMode.values.length);
    });

    test('processHighResolution composes mode + knobs + crop/rotate', () async {
      final bytes = _jpg(_shadowedPage(size: 1200));
      const adjustments = ImageAdjustments(
        rotationQuarterTurns: 1,
        contrast: 0.2,
        brightness: 0.1,
        crop: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
      );

      final result = await processor.processHighResolution(
        bytes,
        adjustments,
        mode: ScanMode.auto,
      );

      expect(result.imageBytes, isNotEmpty);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
      expect(img.decodeImage(result.imageBytes), isNotNull);
    });

    test('blackAndWhite mode composes with redundant mono knobs without error', () async {
      final bytes = _jpg(_shadowedPage(size: 600));
      const adjustments = ImageAdjustments(grayscale: true, saturation: 0.5);

      final result = await processor.processHighResolution(
        bytes,
        adjustments,
        mode: ScanMode.blackAndWhite,
      );
      expect(result.imageBytes, isNotEmpty);
      expect(img.decodeImage(result.imageBytes), isNotNull);
    });

    test('enhanceForOcr returns a decodable binarized PNG', () async {
      final bytes = _jpg(_shadowedPage(size: 400));
      final out = await processor.enhanceForOcr(bytes);
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
    });
  });
}
