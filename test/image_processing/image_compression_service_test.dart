import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/image_compression_service.dart';
import 'package:quitepaper/features/settings/domain/default_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ImageCompressionService service;

  setUp(() {
    service = const DefaultImageCompressionService();
  });

  group('ImageCompressionService Threshold & Probing', () {
    test('isEligibleForCompression returns false for <= 500 KB and true for > 500 KB', () {
      expect(service.isEligibleForCompression(100), isFalse);
      expect(service.isEligibleForCompression(500 * 1024), isFalse);
      expect(service.isEligibleForCompression((500 * 1024) + 1), isTrue);
      expect(service.isEligibleForCompression(2 * 1024 * 1024), isTrue);
    });

    test('probeDimensions extracts width and height from valid image bytes', () async {
      final image = img.Image(width: 320, height: 240);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(image));

      final dims = await service.probeDimensions(jpgBytes);
      expect(dims.width, 320);
      expect(dims.height, 240);
    });

    test('probeDimensions returns 0x0 for invalid bytes without crashing', () async {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final dims = await service.probeDimensions(invalidBytes);
      expect(dims.width, 0);
      expect(dims.height, 0);
    });
  });

  group('ImageCompressionService Compression', () {
    test('bypasses compression when size <= 500 KB and force is false', () async {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(0, 255, 0));
      final bytes = Uint8List.fromList(img.encodeJpg(image));

      final result = await service.compressImage(
        rawBytes: bytes,
        fileName: 'small_photo.jpg',
        force: false,
      );

      expect(result.wasCompressed, isFalse);
      expect(result.bytes, equals(bytes));
      expect(result.compressedByteSize, bytes.length);
      expect(result.originalByteSize, bytes.length);
      expect(result.fileName, 'small_photo.jpg');
    });

    test('downscales image larger than maxDimension when forced or eligible', () async {
      // Create a 2400x1200 image
      final image = img.Image(width: 2400, height: 1200);
      img.fill(image, color: img.ColorRgb8(100, 150, 200));
      final uncompressedJpg = Uint8List.fromList(img.encodeJpg(image, quality: 100));

      final result = await service.compressImage(
        rawBytes: uncompressedJpg,
        fileName: 'landscape.jpg',
        preset: ImageCompressionPreset.balanced, // maxDimension: 1920
        force: true,
      );

      expect(result.wasCompressed, isTrue);
      expect(result.width, 1920);
      expect(result.height, 960);
      expect(result.compressedByteSize, lessThan(uncompressedJpg.length));
      expect(result.mimeType, 'image/jpeg');
      expect(result.fileName, 'landscape.jpg');
      expect(result.savedPercentage, isNotEmpty);
    });

    test('compact preset downscales to 1280px max dimension', () async {
      final image = img.Image(width: 1600, height: 1600);
      img.fill(image, color: img.ColorRgb8(50, 100, 150));
      final uncompressedJpg = Uint8List.fromList(img.encodeJpg(image, quality: 95));

      final result = await service.compressImage(
        rawBytes: uncompressedJpg,
        fileName: 'square.jpg',
        preset: ImageCompressionPreset.compact, // maxDimension: 1280
        force: true,
      );

      expect(result.wasCompressed, isTrue);
      expect(result.width, 1280);
      expect(result.height, 1280);
      expect(result.compressedByteSize, lessThan(uncompressedJpg.length));
    });

    test('preserves alpha transparency for PNGs', () async {
      final image = img.Image(width: 200, height: 200, numChannels: 4);
      // Set pixel with alpha = 0
      image.setPixelRgba(0, 0, 255, 0, 0, 0);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final result = await service.compressImage(
        rawBytes: pngBytes,
        fileName: 'transparent.png',
        force: true,
      );

      // Either kept original if already small, or encoded as PNG
      expect(result.mimeType, 'image/png');
    });

    test('gracefully handles corrupt bytes during compression', () async {
      final corruptBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00, 0x01]);
      final result = await service.compressImage(
        rawBytes: corruptBytes,
        fileName: 'corrupt.jpg',
        force: true,
      );

      expect(result.wasCompressed, isFalse);
      expect(result.bytes, equals(corruptBytes));
      expect(result.fileName, 'corrupt.jpg');
    });
  });
}
