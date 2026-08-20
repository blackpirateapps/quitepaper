import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

void main() {
  group('ImageAdjustments Non-Destructive Editing Tests', () {
    test('Identifies neutral state correctly', () {
      const neutral = ImageAdjustments.neutral;
      expect(neutral.isNeutral, isTrue);
      expect(neutral.rotationQuarterTurns, equals(0));
      expect(neutral.brightness, equals(0.0));
      expect(neutral.contrast, equals(0.0));
      expect(neutral.saturation, equals(0.0));
      expect(neutral.grayscale, isFalse);
      expect(neutral.crop, isNull);
    });

    test('Rotation operations rotate in 90 degree increments', () {
      var adj = ImageAdjustments.neutral;

      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, equals(1));
      expect(adj.isNeutral, isFalse);

      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, equals(2));

      adj = adj.rotateLeft();
      expect(adj.rotationQuarterTurns, equals(1));

      adj = adj.rotateLeft();
      expect(adj.rotationQuarterTurns, equals(0));
      expect(adj.isNeutral, isTrue);
    });

    test('Clamps brightness, contrast, and saturation between -1.0 and 1.0', () {
      final adj = ImageAdjustments.neutral.copyWith(
        brightness: 2.5,
        contrast: -3.0,
        saturation: 1.5,
        grayscale: true,
      );

      expect(adj.brightness, equals(1.0));
      expect(adj.contrast, equals(-1.0));
      expect(adj.saturation, equals(1.0));
      expect(adj.grayscale, isTrue);
    });

    test('Serializes and deserializes ImageAdjustments to and from JSON', () {
      const crop = NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8);
      const adj = ImageAdjustments(
        crop: crop,
        rotationQuarterTurns: 3,
        brightness: 0.25,
        contrast: -0.15,
        saturation: 0.5,
        grayscale: true,
      );

      final json = adj.toJson();
      final restored = ImageAdjustments.fromJson(json);

      expect(restored, equals(adj));
      expect(restored.crop, equals(crop));
      expect(restored.rotationQuarterTurns, equals(3));
      expect(restored.grayscale, isTrue);
    });
  });
}
