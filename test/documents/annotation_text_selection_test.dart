import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/documents/annotations/annotation_text_selection.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

/// Builds a synthetic 2-line × 3-word page.
///
/// Line 1 (y=0.10): "Hello" "big" "world"
/// Line 2 (y=0.30): "Foo" "bar" "baz"
OcrPage _buildPage() {
  OcrWord word(String t, double x, double y, double w, double h) =>
      OcrWord(text: t, bounds: NormalizedRect(x: x, y: y, width: w, height: h));

  final line1 = OcrLine(
    text: 'Hello big world',
    bounds: const NormalizedRect(x: 0.10, y: 0.10, width: 0.42, height: 0.05),
    words: [
      word('Hello', 0.10, 0.10, 0.10, 0.05), // center (0.15, 0.125)
      word('big', 0.25, 0.10, 0.08, 0.05), // center (0.29, 0.125)
      word('world', 0.40, 0.10, 0.12, 0.05), // center (0.46, 0.125)
    ],
  );

  final line2 = OcrLine(
    text: 'Foo bar baz',
    bounds: const NormalizedRect(x: 0.10, y: 0.30, width: 0.32, height: 0.05),
    words: [
      word('Foo', 0.10, 0.30, 0.08, 0.05), // center (0.14, 0.325)
      word('bar', 0.22, 0.30, 0.08, 0.05), // center (0.26, 0.325)
      word('baz', 0.34, 0.30, 0.08, 0.05), // center (0.38, 0.325)
    ],
  );

  return OcrPage(
    pageNumber: 1,
    plainText: 'Hello big world\nFoo bar baz',
    width: 1000,
    height: 1000,
    blocks: [
      OcrBlock(
        text: 'Hello big world\nFoo bar baz',
        bounds: const NormalizedRect(x: 0.10, y: 0.10, width: 0.42, height: 0.25),
        lines: [line1, line2],
      ),
    ],
  );
}

void main() {
  const selector = AnnotationTextSelector();

  group('AnnotationTextSelector.resolve', () {
    test('(a) drag over all of line 1 -> one rect spanning its 3 words', () {
      final page = _buildPage();
      // Covers y 0.05-0.15 (line 1 only), x 0.05-0.60 (all 3 words).
      const drag = NormalizedRect(x: 0.05, y: 0.05, width: 0.55, height: 0.10);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, hasLength(1));
      expect(result.text, 'Hello big world');

      final rect = result.lineRects.single;
      // Union of the 3 word boxes.
      expect(rect.x, closeTo(0.10, 1e-9));
      expect(rect.y, closeTo(0.10, 1e-9));
      expect(rect.right, closeTo(0.52, 1e-9));
      expect(rect.bottom, closeTo(0.15, 1e-9));
    });

    test('(b) drag spanning both lines -> 2 rects, text with a newline', () {
      final page = _buildPage();
      // Covers y 0.05-0.40 -> both lines.
      const drag = NormalizedRect(x: 0.05, y: 0.05, width: 0.55, height: 0.35);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, hasLength(2));
      expect(result.text, 'Hello big world\nFoo bar baz');
      expect(result.text, contains('\n'));

      // Ordered top-to-bottom.
      expect(result.lineRects[0].y, lessThan(result.lineRects[1].y));
    });

    test('(c) drag over only the middle word -> rect hugging just that word', () {
      final page = _buildPage();
      // Tight box around "big" center (0.29, 0.125) only.
      const drag = NormalizedRect(x: 0.27, y: 0.10, width: 0.05, height: 0.05);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, hasLength(1));
      expect(result.text, 'big');

      final rect = result.lineRects.single;
      expect(rect.x, closeTo(0.25, 1e-9));
      expect(rect.y, closeTo(0.10, 1e-9));
      expect(rect.width, closeTo(0.08, 1e-9));
      expect(rect.height, closeTo(0.05, 1e-9));
    });

    test('(d) line with empty words falls back to line-level rect', () {
      final page = OcrPage(
        pageNumber: 1,
        plainText: 'Fallback line',
        width: 1000,
        height: 1000,
        blocks: const [
          OcrBlock(
            text: 'Fallback line',
            bounds: NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
            lines: [
              OcrLine(
                text: 'Fallback line',
                bounds:
                    NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
                // no words
              ),
            ],
          ),
        ],
      );
      // Drag intersects the line bounds.
      const drag = NormalizedRect(x: 0.0, y: 0.55, width: 1.0, height: 0.10);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, hasLength(1));
      expect(result.text, 'Fallback line');
      expect(result.lineRects.single,
          const NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05));
    });

    test('(d2) line whose words are all zero-size also falls back', () {
      final page = OcrPage(
        pageNumber: 1,
        plainText: 'Zero size',
        width: 1000,
        height: 1000,
        blocks: const [
          OcrBlock(
            text: 'Zero size',
            bounds: NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
            lines: [
              OcrLine(
                text: 'Zero size',
                bounds:
                    NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
                words: [
                  OcrWord(
                      text: 'Zero',
                      bounds: NormalizedRect(
                          x: 0.10, y: 0.60, width: 0.0, height: 0.0)),
                  OcrWord(
                      text: 'size',
                      bounds: NormalizedRect(
                          x: 0.20, y: 0.60, width: 0.0, height: 0.0)),
                ],
              ),
            ],
          ),
        ],
      );
      const drag = NormalizedRect(x: 0.0, y: 0.55, width: 1.0, height: 0.10);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, hasLength(1));
      expect(result.text, 'Zero size');
      expect(result.lineRects.single,
          const NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05));
    });

    test('drag over empty region yields no rects and empty text', () {
      final page = _buildPage();
      const drag = NormalizedRect(x: 0.80, y: 0.80, width: 0.10, height: 0.10);

      final result = selector.resolve(page, drag);

      expect(result.lineRects, isEmpty);
      expect(result.text, isEmpty);
    });

    test('is robust to empty blocks / lines', () {
      const empty = OcrPage(
        pageNumber: 1,
        plainText: '',
        width: 1000,
        height: 1000,
        blocks: [],
      );
      final result =
          selector.resolve(empty, NormalizedRect.full);
      expect(result.lineRects, isEmpty);
      expect(result.text, isEmpty);
    });
  });

  group('AnnotationTextSelector.resolvePoint', () {
    test('(e) returns the word under a point', () {
      final page = _buildPage();
      // Inside "Hello".
      final result = selector.resolvePoint(page, 0.15, 0.125);

      expect(result, isNotNull);
      expect(result!.text, 'Hello');
      expect(result.lineRects, hasLength(1));
      expect(result.lineRects.single,
          const NormalizedRect(x: 0.10, y: 0.10, width: 0.10, height: 0.05));
    });

    test('(e) returns null outside any geometry', () {
      final page = _buildPage();
      final result = selector.resolvePoint(page, 0.90, 0.90);
      expect(result, isNull);
    });

    test('falls back to the line when no usable word is hit', () {
      final page = OcrPage(
        pageNumber: 1,
        plainText: 'Only line',
        width: 1000,
        height: 1000,
        blocks: const [
          OcrBlock(
            text: 'Only line',
            bounds: NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
            lines: [
              OcrLine(
                text: 'Only line',
                bounds:
                    NormalizedRect(x: 0.10, y: 0.60, width: 0.30, height: 0.05),
              ),
            ],
          ),
        ],
      );
      final result = selector.resolvePoint(page, 0.20, 0.62);
      expect(result, isNotNull);
      expect(result!.text, 'Only line');
    });
  });
}
