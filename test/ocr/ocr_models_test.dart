import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

void main() {
  group('NormalizedRect Geometry & Invariants Tests', () {
    test('Constructs and clamps normalized coordinates within [0.0, 1.0]', () {
      const rect = NormalizedRect(
        x: 0.1,
        y: 0.2,
        width: 0.4,
        height: 0.3,
      );

      expect(rect.x, equals(0.1));
      expect(rect.y, equals(0.2));
      expect(rect.width, equals(0.4));
      expect(rect.height, equals(0.3));
      expect(rect.right, closeTo(0.5, 0.0001));
      expect(rect.bottom, closeTo(0.5, 0.0001));
      expect(rect.centerX, closeTo(0.3, 0.0001));
      expect(rect.centerY, closeTo(0.35, 0.0001));
    });

    test('Converts raw pixel bounds to normalized coordinates correctly', () {
      final rect = NormalizedRect.fromPixels(
        pixelX: 100,
        pixelY: 200,
        pixelWidth: 400,
        pixelHeight: 300,
        sourceWidth: 1000,
        sourceHeight: 1000,
      );

      expect(rect.x, equals(0.1));
      expect(rect.y, equals(0.2));
      expect(rect.width, equals(0.4));
      expect(rect.height, equals(0.3));

      final pixels = rect.toPixels(targetWidth: 500, targetHeight: 500);
      expect(pixels.x, equals(50));
      expect(pixels.y, equals(100));
      expect(pixels.width, equals(200));
      expect(pixels.height, equals(150));
    });

    test('Contains and intersection calculations are accurate', () {
      const rectA = NormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4);
      const rectB = NormalizedRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4);
      const rectC = NormalizedRect(x: 0.6, y: 0.6, width: 0.3, height: 0.3);

      expect(rectA.contains(0.2, 0.2), isTrue);
      expect(rectA.contains(0.8, 0.8), isFalse);

      expect(rectA.intersects(rectB), isTrue);
      expect(rectA.intersects(rectC), isFalse);
    });

    test('JSON serialization and deserialization roundtrip preserves precision', () {
      const rect = NormalizedRect(x: 0.12345, y: 0.67891, width: 0.25, height: 0.15);
      final json = rect.toJson();
      final decoded = NormalizedRect.fromJson(json);

      expect(decoded.x, equals(rect.x));
      expect(decoded.y, equals(rect.y));
      expect(decoded.width, equals(rect.width));
      expect(decoded.height, equals(rect.height));
      expect(decoded, equals(rect));
    });
  });

  group('OcrLanguage Invariants Tests', () {
    test('Resolves canonical English language code and display name', () {
      expect(OcrLanguage.english.code, equals('en'));
      expect(OcrLanguage.english.displayName, equals('English'));

      expect(OcrLanguage.fromCode('en'), equals(OcrLanguage.english));
      expect(OcrLanguage.fromCode('EN'), equals(OcrLanguage.english));
      expect(OcrLanguage.fromCode('english'), equals(OcrLanguage.english));
      expect(OcrLanguage.fromCode(null), equals(OcrLanguage.english));
      expect(OcrLanguage.fromCode('unknown'), equals(OcrLanguage.english));
    });
  });

  group('Structured OcrDocument Hierarchy Tests', () {
    test('Serializes and deserializes full OcrDocument with blocks, lines, and words', () {
      const word1 = OcrWord(
        text: 'Quiet',
        bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.1, height: 0.05),
        confidence: 0.98,
      );
      const word2 = OcrWord(
        text: 'Paper',
        bounds: NormalizedRect(x: 0.22, y: 0.1, width: 0.1, height: 0.05),
        confidence: 0.99,
      );

      const line1 = OcrLine(
        text: 'Quiet Paper',
        bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.25, height: 0.05),
        words: [word1, word2],
      );

      const block1 = OcrBlock(
        text: 'Quiet Paper',
        bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1),
        lines: [line1],
      );

      const page1 = OcrPage(
        pageNumber: 1,
        plainText: 'Quiet Paper',
        width: 1000,
        height: 1414,
        source: OcrSource.onDeviceOcr,
        blocks: [block1],
      );

      final doc = OcrDocument(
        documentId: 'doc-uuid-1234',
        language: OcrLanguage.english,
        engine: 'quietpaper_ocr_v1',
        engineVersion: '1.0.0',
        schemaVersion: 1,
        processedAt: DateTime(2026, 8, 20, 15, 0, 0),
        pages: [page1],
      );

      expect(doc.fullPlainText, equals('Quiet Paper'));

      final json = doc.toJson();
      final restored = OcrDocument.fromJson(json);

      expect(restored.documentId, equals('doc-uuid-1234'));
      expect(restored.language, equals(OcrLanguage.english));
      expect(restored.pages.length, equals(1));
      expect(restored.pages.first.plainText, equals('Quiet Paper'));
      expect(restored.pages.first.blocks.first.lines.first.words.length, equals(2));
      expect(restored.pages.first.blocks.first.lines.first.words.first.text, equals('Quiet'));
    });
  });
}
