import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/attachments/presentation/image_dimension_reader.dart';

void main() {
  group('ImageDimensionReader Unit Tests', () {
    test('extracts dimensions from valid PNG header', () {
      final image = img.Image(width: 640, height: 480);
      final pngBytes = Uint8List.fromList(img.encodePng(image));

      final size = ImageDimensionReader.extractDimensions(pngBytes);
      expect(size, isNotNull);
      expect(size!.width, 640.0);
      expect(size.height, 480.0);
    });

    test('extracts dimensions from valid JPEG header', () {
      final image = img.Image(width: 800, height: 600);
      final jpgBytes = Uint8List.fromList(img.encodeJpg(image));

      final size = ImageDimensionReader.extractDimensions(jpgBytes);
      expect(size, isNotNull);
      expect(size!.width, 800.0);
      expect(size.height, 600.0);
    });

    test('extracts dimensions from valid GIF header', () {
      final image = img.Image(width: 320, height: 240);
      final gifBytes = Uint8List.fromList(img.encodeGif(image));

      final size = ImageDimensionReader.extractDimensions(gifBytes);
      expect(size, isNotNull);
      expect(size!.width, 320.0);
      expect(size.height, 240.0);
    });

    test('extracts dimensions from valid BMP header', () {
      final image = img.Image(width: 200, height: 100);
      final bmpBytes = Uint8List.fromList(img.encodeBmp(image));

      final size = ImageDimensionReader.extractDimensions(bmpBytes);
      expect(size, isNotNull);
      expect(size!.width, 200.0);
      expect(size.height, 100.0);
    });

    test('extracts dimensions from valid AVIF header with ispe box', () {
      final builder = BytesBuilder();
      // ftyp box (28 bytes)
      builder.add([0, 0, 0, 28]); // box size
      builder.add([0x66, 0x74, 0x79, 0x70]); // 'ftyp'
      builder.add([0x61, 0x76, 0x69, 0x66]); // 'avif' (major brand)
      builder.add([0, 0, 0, 0]); // minor version
      builder.add([0x61, 0x76, 0x69, 0x66]); // 'avif' (compatible brand)
      builder.add([0x6d, 0x69, 0x66, 0x31]); // 'mif1' (compatible brand)

      // ispe box (20 bytes: 4 size + 4 type + 1 version + 3 flags + 4 width + 4 height)
      builder.add([0, 0, 0, 20]); // box size
      builder.add([0x69, 0x73, 0x70, 0x65]); // 'ispe'
      builder.add([0, 0, 0, 0]); // version 0, flags 0
      builder.add([0, 0, 7, 128]); // width = 1920 (0x0780)
      builder.add([0, 0, 4, 56]); // height = 1080 (0x0438)

      final avifBytes = builder.toBytes();
      final size = ImageDimensionReader.extractDimensions(avifBytes);
      expect(size, isNotNull);
      expect(size!.width, 1920.0);
      expect(size.height, 1080.0);
    });

    test('returns null for empty or corrupted image bytes', () {
      expect(ImageDimensionReader.extractDimensions(Uint8List(0)), isNull);
      expect(ImageDimensionReader.extractDimensions(Uint8List.fromList([1, 2, 3])), isNull);
      expect(ImageDimensionReader.extractDimensions(Uint8List.fromList(List.filled(50, 0))), isNull);
    });
  });
}
