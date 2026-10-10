import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/document_detector.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';

void main() {
  group('DocumentDetector.detect', () {
    test('finds a bright page inset in a dark background', () {
      const size = 400;
      final image = img.Image(width: size, height: size);
      // Dark background.
      img.fill(image, color: img.ColorRgb8(30, 30, 30));
      // Bright page inset from 15%..85% (axis-aligned).
      final lo = (size * 0.15).round();
      final hi = (size * 0.85).round();
      for (var y = lo; y <= hi; y++) {
        for (var x = lo; x <= hi; x++) {
          image.setPixelRgb(x, y, 235, 235, 235);
        }
      }

      final result = DocumentDetector.detect(image);

      expect(result.confidence, greaterThan(0.3));

      final rect = result.quad.boundingRect;
      // Clearly inset from the full frame.
      expect(rect.x, greaterThan(0.03));
      expect(rect.y, greaterThan(0.03));
      expect(rect.width, lessThan(0.97));
      expect(rect.height, lessThan(0.97));
      // Roughly matches the 15%..85% inset (tolerant bounds).
      expect(rect.x, closeTo(0.15, 0.08));
      expect(rect.y, closeTo(0.15, 0.08));
      expect(rect.width, closeTo(0.70, 0.12));
      expect(rect.height, closeTo(0.70, 0.12));
      expect(result.quad.isConvex, isTrue);
    });

    test('finds a slightly rotated bright page', () {
      const size = 400;
      final image = img.Image(width: size, height: size);
      img.fill(image, color: img.ColorRgb8(25, 25, 25));
      // A rotated square (~12 degrees) centered in the frame.
      const cx = size / 2.0;
      const cy = size / 2.0;
      const half = size * 0.33;
      const angle = 0.21; // radians
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final dx = x - cx;
          final dy = y - cy;
          final rx = dx * cosA + dy * sinA;
          final ry = -dx * sinA + dy * cosA;
          if (rx.abs() <= half && ry.abs() <= half) {
            image.setPixelRgb(x, y, 230, 230, 230);
          }
        }
      }

      final result = DocumentDetector.detect(image);

      expect(result.confidence, greaterThan(0.3));
      expect(result.quad.isConvex, isTrue);
      final rect = result.quad.boundingRect;
      expect(rect.x, greaterThan(0.03));
      expect(rect.width, lessThan(0.97));
    });

    test('returns full frame with no confidence for a blank image', () {
      final image = img.Image(width: 300, height: 300);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));

      final result = DocumentDetector.detect(image);

      expect(result.confidence, lessThan(0.35));
      expect(result.quad, equals(NormalizedQuad.full));
    });

    test('returns low confidence for pure random noise', () {
      final image = img.Image(width: 300, height: 300);
      // Deterministic pseudo-random noise (seeded for stability).
      var seed = 12345;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          final v = seed % 256;
          image.setPixelRgb(x, y, v, v, v);
        }
      }

      final result = DocumentDetector.detect(image);

      expect(result.confidence, lessThan(0.35));
      // Noise covers the whole frame, so the quad should be (near) full-frame.
      expect(result.quad.isFullFrame, isTrue);
    });

    test('never throws on a 1x1 image', () {
      final image = img.Image(width: 1, height: 1);
      img.fill(image, color: img.ColorRgb8(200, 200, 200));

      late ({NormalizedQuad quad, double confidence}) result;
      expect(() => result = DocumentDetector.detect(image), returnsNormally);
      expect(result.confidence, equals(0.0));
      expect(result.quad, equals(NormalizedQuad.full));
    });
  });
}
