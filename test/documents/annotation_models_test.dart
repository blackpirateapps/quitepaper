import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/documents/annotations/annotation_models.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

Annotation _ann({
  required String id,
  AnnotationType type = AnnotationType.ink,
  int createdAtMs = 0,
  int updatedAtMs = 0,
  bool deleted = false,
  int z = 0,
  AnnotationGeometry geometry = const AnnotationGeometry(),
  String? text,
}) {
  return Annotation(
    id: id,
    documentId: 'qp://document/doc-1',
    pageIndex: 0,
    type: type,
    geometry: geometry,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    deleted: deleted,
    z: z,
    text: text,
  );
}

void expectGeometryEquals(AnnotationGeometry a, AnnotationGeometry b) {
  expect(a.points, b.points);
  expect(a.rects, b.rects);
  expect(a.anchor, b.anchor);
}

void expectAnnotationEquals(Annotation a, Annotation b) {
  expect(a.id, b.id);
  expect(a.documentId, b.documentId);
  expect(a.pageIndex, b.pageIndex);
  expect(a.type, b.type);
  expectGeometryEquals(a.geometry, b.geometry);
  expect(a.style, b.style);
  expect(a.text, b.text);
  expect(a.createdAtMs, b.createdAtMs);
  expect(a.updatedAtMs, b.updatedAtMs);
  expect(a.deleted, b.deleted);
  expect(a.z, b.z);
}

void main() {
  group('Annotation JSON round-trip', () {
    test('ink with points', () {
      final original = _ann(
        id: 'ink-1',
        type: AnnotationType.ink,
        createdAtMs: 10,
        updatedAtMs: 20,
        z: 3,
        geometry: const AnnotationGeometry(
          points: [Offset(0.1, 0.2), Offset(0.3, 0.4), Offset(0.5, 0.6)],
        ),
      ).copyWith(
        style: const AnnotationStyle(
          colorArgb: 0xFF112233,
          strokeWidth: 0.006,
          opacity: 0.8,
        ),
      );

      final restored = Annotation.fromJson(original.toJson());
      expectAnnotationEquals(restored, original);
    });

    test('rect with rects', () {
      final original = _ann(
        id: 'rect-1',
        type: AnnotationType.rect,
        createdAtMs: 5,
        updatedAtMs: 7,
        z: 1,
        geometry: const AnnotationGeometry(
          rects: [
            NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.05),
            NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
          ],
        ),
      ).copyWith(
        style: const AnnotationStyle(colorArgb: 0x80FF0000, filled: true),
      );

      final restored = Annotation.fromJson(original.toJson());
      expectAnnotationEquals(restored, original);
    });

    test('comment with anchor + text', () {
      final original = _ann(
        id: 'comment-1',
        type: AnnotationType.comment,
        createdAtMs: 100,
        updatedAtMs: 101,
        geometry: const AnnotationGeometry(
          anchor: Offset(0.42, 0.37),
          rects: [NormalizedRect(x: 0.4, y: 0.35, width: 0.1, height: 0.04)],
        ),
        text: 'Remember this passage',
      );

      final restored = Annotation.fromJson(original.toJson());
      expectAnnotationEquals(restored, original);
      expect(restored.text, 'Remember this passage');
      expect(restored.geometry.anchor, const Offset(0.42, 0.37));
    });

    test('redaction', () {
      final original = _ann(
        id: 'redact-1',
        type: AnnotationType.redaction,
        createdAtMs: 1,
        updatedAtMs: 2,
        z: 9,
        deleted: false,
        geometry: const AnnotationGeometry(
          rects: [NormalizedRect(x: 0.2, y: 0.6, width: 0.5, height: 0.08)],
        ),
      );

      final restored = Annotation.fromJson(original.toJson());
      expectAnnotationEquals(restored, original);
      expect(restored.type, AnnotationType.redaction);
    });
  });

  group('mergeAnnotations', () {
    test('union by id across replicas', () {
      final local = [_ann(id: 'a', createdAtMs: 1)];
      final remote = [_ann(id: 'b', createdAtMs: 2)];

      final merged = mergeAnnotations(local, remote);

      expect(merged.map((a) => a.id).toSet(), {'a', 'b'});
    });

    test('for a shared id the greater updatedAtMs wins', () {
      final older = _ann(id: 'a', updatedAtMs: 100, text: 'old');
      final newer = _ann(id: 'a', updatedAtMs: 200, text: 'new');

      // Newer on the remote side.
      final m1 = mergeAnnotations([older], [newer]);
      expect(m1, hasLength(1));
      expect(m1.single.text, 'new');

      // Newer on the local side (older arrives as remote, must not clobber).
      final m2 = mergeAnnotations([newer], [older]);
      expect(m2, hasLength(1));
      expect(m2.single.text, 'new');
    });

    test('a newer deleted tombstone wins over an older edit', () {
      final edit = _ann(id: 'a', updatedAtMs: 100, deleted: false, text: 'kept');
      final tombstone = _ann(id: 'a', updatedAtMs: 200, deleted: true);

      final merged = mergeAnnotations([edit], [tombstone]);
      expect(merged, hasLength(1));
      expect(merged.single.deleted, isTrue);
    });

    test('a newer edit wins over an older tombstone (resurrects)', () {
      final tombstone = _ann(id: 'a', updatedAtMs: 100, deleted: true);
      final edit = _ann(id: 'a', updatedAtMs: 200, deleted: false, text: 'back');

      final merged = mergeAnnotations([tombstone], [edit]);
      expect(merged, hasLength(1));
      expect(merged.single.deleted, isFalse);
      expect(merged.single.text, 'back');
    });

    test('result is sorted by z then createdAtMs', () {
      final a = _ann(id: 'a', z: 1, createdAtMs: 50);
      final b = _ann(id: 'b', z: 0, createdAtMs: 90);
      final c = _ann(id: 'c', z: 0, createdAtMs: 10);
      final d = _ann(id: 'd', z: 2, createdAtMs: 5);

      final merged = mergeAnnotations([a, b], [c, d]);

      // z ascending, then createdAtMs ascending within equal z.
      expect(merged.map((e) => e.id).toList(), ['c', 'b', 'a', 'd']);
    });
  });
}
