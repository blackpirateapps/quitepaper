import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/documents/annotations/annotation_flattener.dart';
import 'package:quitepaper/core/documents/annotations/annotation_models.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

/// Unit tests for the pure geometry/logic of [AnnotationFlattener]. The actual
/// raster + PDF rewrap steps need a Flutter engine (platform-channel raster),
/// so they are deliberately out of scope here — these cover the pure helpers
/// that map normalized annotations to pixel draw primitives.
void main() {
  Annotation annotation({
    required String id,
    required AnnotationType type,
    AnnotationGeometry geometry = const AnnotationGeometry(),
    AnnotationStyle style = const AnnotationStyle(),
    int createdAtMs = 0,
    int z = 0,
    bool deleted = false,
  }) {
    return Annotation(
      id: id,
      documentId: 'doc',
      pageIndex: 0,
      type: type,
      geometry: geometry,
      style: style,
      createdAtMs: createdAtMs,
      updatedAtMs: createdAtMs,
      z: z,
      deleted: deleted,
    );
  }

  group('normalizedRectToPixels', () {
    test('maps a normalized rect to the correct pixel rect', () {
      const r = NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      final px = AnnotationFlattener.normalizedRectToPixels(r, 1000, 2000);
      expect(px.left, closeTo(100, 1e-6));
      expect(px.top, closeTo(400, 1e-6));
      expect(px.right, closeTo(400, 1e-6)); // (0.1 + 0.3) * 1000
      expect(px.bottom, closeTo(1200, 1e-6)); // (0.2 + 0.4) * 2000
    });

    test('a rect annotation resolves to a RectOp with those pixel bounds', () {
      final a = annotation(
        id: 'rect1',
        type: AnnotationType.rect,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.25, y: 0.5, width: 0.25, height: 0.1)],
        ),
      );
      final ops = AnnotationFlattener.opsForAnnotation(a, 800, 600);
      final rectOps = ops.whereType<RectOp>().toList();
      expect(rectOps, hasLength(1));
      expect(rectOps.first.left, closeTo(200, 1e-6));
      expect(rectOps.first.top, closeTo(300, 1e-6));
      expect(rectOps.first.right, closeTo(400, 1e-6));
      expect(rectOps.first.bottom, closeTo(360, 1e-6));
    });
  });

  group('redaction', () {
    test('flattens to a fully opaque black fill regardless of its style', () {
      final a = annotation(
        id: 'red1',
        type: AnnotationType.redaction,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05)],
        ),
        // Deliberately red + translucent + unfilled: all must be ignored.
        style: const AnnotationStyle(
          colorArgb: 0xFFFF0000,
          opacity: 0.2,
          filled: false,
        ),
      );
      final ops = AnnotationFlattener.opsForAnnotation(a, 1000, 1000);
      final rectOps = ops.whereType<RectOp>().toList();
      expect(rectOps, hasLength(1));
      expect(rectOps.first.filled, isTrue, reason: 'redaction is always a fill');
      expect(rectOps.first.argb, 0xFF000000, reason: 'opaque black');
      expect((rectOps.first.argb >> 24) & 0xFF, 255, reason: 'alpha is fully opaque');
    });

    test('expandRedactionForOcr grows the rect to cover an intersecting word', () {
      final redaction = annotation(
        id: 'red2',
        type: AnnotationType.redaction,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.10, y: 0.10, width: 0.10, height: 0.05)],
        ),
      );
      final ocr = OcrPage(
        pageNumber: 1,
        plainText: 'secret',
        width: 1000,
        height: 1000,
        blocks: const [
          OcrBlock(
            text: 'secret',
            bounds: NormalizedRect(x: 0.15, y: 0.10, width: 0.20, height: 0.05),
            lines: [
              OcrLine(
                text: 'secret',
                bounds: NormalizedRect(x: 0.15, y: 0.10, width: 0.20, height: 0.05),
                words: [
                  OcrWord(
                    text: 'secret',
                    // Overhangs the redaction's right edge (0.20) out to 0.35.
                    bounds: NormalizedRect(x: 0.15, y: 0.10, width: 0.20, height: 0.05),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final expanded = AnnotationFlattener.expandRedactionForOcr(redaction, ocr);
      final rect = expanded.geometry.rects.single;
      expect(rect.x, closeTo(0.10, 1e-6));
      expect(rect.right, closeTo(0.35, 1e-6), reason: 'extended to cover the word');
    });

    test('expandRedactionForOcr is a no-op without OCR', () {
      final redaction = annotation(
        id: 'red3',
        type: AnnotationType.redaction,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.1, y: 0.1, width: 0.1, height: 0.05)],
        ),
      );
      final same = AnnotationFlattener.expandRedactionForOcr(redaction, null);
      expect(same.geometry.rects.single.right, closeTo(0.20, 1e-6));
    });
  });

  group('sortedForPaint', () {
    test('orders ascending by z then createdAtMs and drops tombstones', () {
      final input = [
        annotation(id: 'c', type: AnnotationType.ink, z: 2, createdAtMs: 0),
        annotation(id: 'a', type: AnnotationType.ink, z: 0, createdAtMs: 5),
        annotation(id: 'b', type: AnnotationType.ink, z: 1, createdAtMs: 0),
        annotation(id: 'old', type: AnnotationType.ink, z: 0, createdAtMs: 1),
        annotation(id: 'del', type: AnnotationType.ink, z: 0, createdAtMs: 0, deleted: true),
      ];
      final sorted = AnnotationFlattener.sortedForPaint(input);
      expect(sorted.map((a) => a.id).toList(), ['old', 'a', 'b', 'c']);
    });
  });

  group('style resolution', () {
    test('highlighter fill is translucent (alpha capped) even at full opacity', () {
      final a = annotation(
        id: 'hl',
        type: AnnotationType.textHighlight,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.03)],
        ),
        style: const AnnotationStyle(colorArgb: 0xFFFFFF00, opacity: 1.0),
      );
      final rectOp = AnnotationFlattener.opsForAnnotation(a, 1000, 1000)
          .whereType<RectOp>()
          .single;
      final alpha = (rectOp.argb >> 24) & 0xFF;
      expect(alpha, lessThan(255));
      expect(alpha, closeTo((0.4 * 255).round(), 1));
    });

    test('arrow yields a shaft polyline plus a 3-point arrowhead', () {
      final a = annotation(
        id: 'arr',
        type: AnnotationType.arrow,
        geometry: const AnnotationGeometry(
          points: [Offset(0.1, 0.1), Offset(0.5, 0.1)],
        ),
      );
      final polylines = AnnotationFlattener.opsForAnnotation(a, 1000, 1000)
          .whereType<PolylineOp>()
          .toList();
      expect(polylines, hasLength(2));
      expect(polylines[0].points, hasLength(2)); // shaft
      expect(polylines[1].points, hasLength(3)); // arrowhead
    });
  });
}
