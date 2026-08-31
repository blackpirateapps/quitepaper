import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/presentation/image_layout_calculator.dart';

void main() {
  group('ImageLayoutCalculator Unit Tests', () {
    test('Small image (100x100 on 800px width) is NOT upscaled', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 100,
        intrinsicHeight: 100,
        availableContentWidth: 800,
      );

      expect(size.width, 100.0);
      expect(size.height, 100.0);
    });

    test('Small landscape image (300x200 on 900px width) preserves natural size', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 300,
        intrinsicHeight: 200,
        availableContentWidth: 900,
      );

      expect(size.width, 300.0);
      expect(size.height, 200.0);
    });

    test('Large landscape image (1600x600 on 720px width) scales to content width proportionally', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 1600,
        intrinsicHeight: 600,
        availableContentWidth: 720,
      );

      expect(size.width, 720.0);
      expect(size.height, 270.0); // 720 / (1600 / 600) = 270
    });

    test('Full HD screenshot (1920x1080 on 600px width) scales proportionally', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 1920,
        intrinsicHeight: 1080,
        availableContentWidth: 600,
      );

      expect(size.width, 600.0);
      expect(size.height, closeTo(337.5, 0.01));
    });

    test('Extremely tall image (1080x3000 on 400px width) is constrained by maxAllowedHeight', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 1080,
        intrinsicHeight: 3000,
        availableContentWidth: 400,
        maxAllowedHeight: 520,
      );

      expect(size.height, 520.0);
      // Aspect ratio = 1080 / 3000 = 0.36
      // displayWidth = 520 * 0.36 = 187.2
      expect(size.width, closeTo(187.2, 0.01));
    });

    test('Tall infographic (1000x5000 on 800px width) scales width proportionally with max height', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 1000,
        intrinsicHeight: 5000,
        availableContentWidth: 800,
        maxAllowedHeight: 500,
      );

      expect(size.height, 500.0);
      // Aspect ratio = 1000 / 5000 = 0.2
      // displayWidth = 500 * 0.2 = 100.0
      expect(size.width, 100.0);
    });

    test('Extreme wide banner (3000x200 on 600px width) scales down without distortion', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 3000,
        intrinsicHeight: 200,
        availableContentWidth: 600,
      );

      expect(size.width, 600.0);
      expect(size.height, 40.0); // 600 / 15.0 = 40.0
    });

    test('Square image (4000x4000 on 500px width) scales to 500x500', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 4000,
        intrinsicHeight: 4000,
        availableContentWidth: 500,
      );

      expect(size.width, 500.0);
      expect(size.height, 500.0);
    });

    test('Missing / null intrinsic dimensions fallback cleanly without crashing', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: null,
        intrinsicHeight: null,
        availableContentWidth: 400,
      );

      expect(size.width, 400.0);
      expect(size.height, greaterThanOrEqualTo(120.0));
      expect(size.height, lessThanOrEqualTo(520.0));
    });

    test('Zero or negative content width returns minimum safe dimension', () {
      final size = ImageLayoutCalculator.calculateSize(
        intrinsicWidth: 500,
        intrinsicHeight: 500,
        availableContentWidth: 0,
      );

      expect(size.width, ImageLayoutCalculator.minImageDimension);
      expect(size.height, ImageLayoutCalculator.minImageDimension);
    });
  });
}
