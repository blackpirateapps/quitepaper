import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../features/scanner/domain/scanned_page.dart';
import '../../ocr/ocr_models.dart';
import '../../pdf/pdf_generator.dart';
import '../../pdf/pdf_page_renderer.dart';
import 'annotation_models.dart';

/// Export / flatten pipeline (spec §7–§8).
///
/// Produces a NEW, image-only PDF in which every annotation is permanently
/// composited onto a re-rasterized copy of each page. The original decrypted
/// [Uint8List] is treated as read-only and is never mutated — flatten always
/// yields a fresh artifact for save / share / print.
///
/// ## Why image-only output makes redaction unrecoverable (§7/§8)
/// Each page is rasterized to pixels and the marks are burned into those
/// pixels; the resulting PDF carries NO live text layer and NO vector objects
/// beneath the marks. A [AnnotationType.redaction] therefore paints a fully
/// opaque black fill directly over the pixels, and because nothing survives
/// underneath it in the exported file, the covered content is genuinely gone
/// *in the artifact you hand out*. (The in-app stored original still retains
/// the content — that is a deliberate, accepted limitation per spec §2.6/§7.)
///
/// ## Isolate boundary (important)
/// `Printing.raster` (used by [DefaultPdfPageRenderer]) talks over a platform
/// channel and MUST run on the main isolate — it cannot run inside
/// `compute()`. Only the pure-Dart pixel compositing is offloaded to a
/// background isolate via [compute].
class AnnotationFlattener {
  const AnnotationFlattener({PdfPageRenderer? renderer})
      : _renderer = renderer ?? const DefaultPdfPageRenderer();

  final PdfPageRenderer _renderer;

  /// Minimum stroke thickness in export pixels.
  static const double _minStrokePx = 1.0;

  /// Highlighter strokes are drawn wider than the ink pen.
  static const double _highlighterWidthFactor = 3.0;

  /// Translucency ceiling for highlighter / text-highlight fills.
  static const double _highlightMaxOpacity = 0.4;

  /// Returns NEW flattened PDF bytes. Pages with no annotations are still
  /// re-rastered so the output is uniform. Original bytes are never mutated.
  Future<Uint8List> flatten({
    required Uint8List pdfBytes,
    required Map<int, List<Annotation>> annotationsByPageIndex, // 0-based
    Map<int, OcrPage>? ocrByPageIndex, // for redaction word-drop
    double dpi = 220.0,
  }) async {
    // 1. Rasterize ALL pages at export DPI on the MAIN isolate. Printing.raster
    //    uses a platform channel and cannot run inside compute()/an isolate.
    final rendered = await _renderer.renderPages(pdfBytes, dpi: dpi);
    if (rendered.isEmpty) {
      // Render failed or empty doc: return the original untouched so the caller
      // never loses the document.
      return pdfBytes;
    }

    final pages = <ScannedPage>[];
    for (final page in rendered) {
      final pageIndex = page.pageNumber - 1; // renderer pageNumber is 1-based
      final anns = (annotationsByPageIndex[pageIndex] ?? const <Annotation>[])
          .where((a) => !a.deleted)
          .toList();

      Uint8List composited;
      if (anns.isEmpty) {
        // No marks: the renderer already re-rastered this page, so emit it as
        // is. Output stays uniform (every exported page is a raster image).
        composited = page.imageBytes;
      } else {
        // Expand redactions to fully cover any intersecting OCR word (§7)
        // BEFORE compositing, so no glyph pokes out from under the burn-in.
        // The export carries no text layer, so there is no separate text to
        // "drop" — fully covering the pixels is what removes the content.
        final ocr = ocrByPageIndex?[pageIndex];
        final prepared = <Annotation>[
          for (final a in anns)
            a.type == AnnotationType.redaction
                ? expandRedactionForOcr(a, ocr)
                : a,
        ];
        final params = _CompositeParams(pngBytes: page.imageBytes, annotations: prepared);
        // 2. Composite (pure Dart) — safe to offload to a background isolate.
        try {
          composited = await compute(_compositePagePng, params);
        } catch (_) {
          // Fallback: composite on the main isolate if the spawn fails.
          composited = _compositePagePng(params);
        }
      }

      pages.add(
        ScannedPage(
          id: 'flatten_${page.pageNumber}',
          imageBytes: composited,
          width: page.width,
          height: page.height,
          pageNumber: page.pageNumber,
        ),
      );
    }

    // 4. Re-wrap every composited page image into a NEW PDF using the repo's
    //    existing image->PDF builder (one image per page, aspect preserved).
    return const DefaultPdfGenerator().generatePdf(pages);
  }

  /// Maps a normalized rect to export pixels as left/top/right/bottom. Pure.
  static ({double left, double top, double right, double bottom})
      normalizedRectToPixels(NormalizedRect r, double widthPx, double heightPx) {
    final px = r.toPixels(targetWidth: widthPx, targetHeight: heightPx);
    return (
      left: px.x,
      top: px.y,
      right: px.x + px.width,
      bottom: px.y + px.height,
    );
  }

  /// Paint order: ascending [Annotation.z], then [Annotation.createdAtMs] as a
  /// stable tiebreak (matching [mergeAnnotations]); tombstones are dropped.
  static List<Annotation> sortedForPaint(Iterable<Annotation> annotations) {
    return annotations.where((a) => !a.deleted).toList()
      ..sort((a, b) => a.z != b.z
          ? a.z.compareTo(b.z)
          : a.createdAtMs.compareTo(b.createdAtMs));
  }

  /// Grows each redaction rect to the bounding union of any OCR word it
  /// intersects, so the opaque burn-in fully covers every touched glyph (§7).
  /// Pure; returns the input unchanged when no OCR is available.
  static Annotation expandRedactionForOcr(Annotation redaction, OcrPage? ocr) {
    if (ocr == null || redaction.geometry.rects.isEmpty) return redaction;
    final words = <OcrWord>[
      for (final block in ocr.blocks)
        for (final line in block.lines) ...line.words,
    ];
    if (words.isEmpty) return redaction;

    final expanded = <NormalizedRect>[];
    for (final rect in redaction.geometry.rects) {
      var left = rect.x, top = rect.y, right = rect.right, bottom = rect.bottom;
      for (final w in words) {
        if (rect.intersects(w.bounds)) {
          left = math.min(left, w.bounds.x);
          top = math.min(top, w.bounds.y);
          right = math.max(right, w.bounds.right);
          bottom = math.max(bottom, w.bounds.bottom);
        }
      }
      expanded.add(NormalizedRect(
        x: left,
        y: top,
        width: (right - left).clamp(0.0, 1.0),
        height: (bottom - top).clamp(0.0, 1.0),
      ));
    }
    return redaction.copyWith(
      geometry: redaction.geometry.copyWith(rects: expanded),
    );
  }

  /// Pure mapping: a single annotation + a page raster size (export pixels) ->
  /// the resolution-independent list of [DrawOp] draw primitives. No `image`
  /// or `dart:ui` canvas calls, so it is fully unit-testable without a Flutter
  /// engine. The compositor ([_compositePagePng]) consumes these primitives.
  static List<DrawOp> opsForAnnotation(
    Annotation a,
    double widthPx,
    double heightPx,
  ) {
    final ops = <DrawOp>[];
    final strokePx = math.max(a.style.strokeWidth * widthPx, _minStrokePx);
    PxPoint mapOffset(Offset o) => PxPoint(o.dx * widthPx, o.dy * heightPx);
    final points = a.geometry.points;
    final rects = a.geometry.rects;

    switch (a.type) {
      case AnnotationType.ink:
        if (points.length >= 2) {
          ops.add(PolylineOp(
            points: points.map(mapOffset).toList(),
            argb: _effectiveArgb(a.style),
            widthPx: strokePx,
            roundCap: true,
          ));
        }
      case AnnotationType.highlighterFree:
        if (points.length >= 2) {
          ops.add(PolylineOp(
            points: points.map(mapOffset).toList(),
            argb: _highlightArgb(a.style),
            widthPx: strokePx * _highlighterWidthFactor,
            roundCap: true,
          ));
        }
      case AnnotationType.line:
        if (points.length >= 2) {
          ops.add(PolylineOp(
            points: [mapOffset(points.first), mapOffset(points.last)],
            argb: _effectiveArgb(a.style),
            widthPx: strokePx,
          ));
        }
      case AnnotationType.arrow:
        if (points.length >= 2) {
          final start = mapOffset(points.first);
          final tip = mapOffset(points.last);
          final argb = _effectiveArgb(a.style);
          ops.add(PolylineOp(points: [start, tip], argb: argb, widthPx: strokePx));
          ops.add(PolylineOp(
            points: _arrowHead(start, tip, strokePx),
            argb: argb,
            widthPx: strokePx,
            roundCap: true,
          ));
        }
      case AnnotationType.rect:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(RectOp(
            left: b.left, top: b.top, right: b.right, bottom: b.bottom,
            argb: _effectiveArgb(a.style),
            strokeWidthPx: strokePx,
            filled: a.style.filled,
          ));
        }
      case AnnotationType.ellipse:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(EllipseOp(
            left: b.left, top: b.top, right: b.right, bottom: b.bottom,
            argb: _effectiveArgb(a.style),
            strokeWidthPx: strokePx,
            filled: a.style.filled,
          ));
        }
      case AnnotationType.textHighlight:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(RectOp(
            left: b.left, top: b.top, right: b.right, bottom: b.bottom,
            argb: _highlightArgb(a.style),
            strokeWidthPx: strokePx,
            filled: true,
          ));
        }
      case AnnotationType.underline:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(PolylineOp(
            points: [PxPoint(b.left, b.bottom), PxPoint(b.right, b.bottom)],
            argb: _effectiveArgb(a.style),
            widthPx: strokePx,
          ));
        }
      case AnnotationType.strikethrough:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          final midY = (b.top + b.bottom) / 2.0;
          ops.add(PolylineOp(
            points: [PxPoint(b.left, midY), PxPoint(b.right, midY)],
            argb: _effectiveArgb(a.style),
            widthPx: strokePx,
          ));
        }
      case AnnotationType.squiggly:
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(PolylineOp(
            points: _squiggle(b.left, b.right, b.bottom, strokePx),
            argb: _effectiveArgb(a.style),
            widthPx: strokePx,
            roundCap: true,
          ));
        }
      case AnnotationType.comment:
        final anchor = a.geometry.anchor;
        if (anchor != null) {
          final c = mapOffset(anchor);
          final radius = math.max(widthPx * 0.012, 6.0);
          ops.add(DotOp(
            cx: c.x,
            cy: c.y,
            radiusPx: radius,
            fillArgb: _opaque(a.style.colorArgb),
            borderArgb: 0xFFFFFFFF,
            borderWidthPx: math.max(radius * 0.2, 1.0),
          ));
        }
      case AnnotationType.redaction:
        // §7/§8: a redaction burns a FULLY OPAQUE solid black fill, ignoring
        // the annotation's own color and opacity. Because the export is a flat
        // raster with no text/vector layer beneath (see class doc), the covered
        // content is unrecoverable in the shared artifact.
        for (final r in rects) {
          final b = normalizedRectToPixels(r, widthPx, heightPx);
          ops.add(RectOp(
            left: b.left, top: b.top, right: b.right, bottom: b.bottom,
            argb: 0xFF000000,
            strokeWidthPx: 0,
            filled: true,
          ));
        }
    }
    return ops;
  }

  static int _effectiveArgb(AnnotationStyle style) =>
      _applyOpacity(style.colorArgb, style.opacity);

  static int _highlightArgb(AnnotationStyle style) =>
      _applyOpacity(style.colorArgb, math.min(style.opacity, _highlightMaxOpacity));

  static int _applyOpacity(int argb, double opacity) {
    final baseA = (argb >> 24) & 0xFF;
    final a = (baseA * opacity).round().clamp(0, 255);
    return (a << 24) | (argb & 0x00FFFFFF);
  }

  static int _opaque(int argb) => 0xFF000000 | (argb & 0x00FFFFFF);

  static List<PxPoint> _arrowHead(PxPoint start, PxPoint tip, double strokePx) {
    final angle = math.atan2(tip.y - start.y, tip.x - start.x);
    final len = math.max(strokePx * 5.0, 8.0);
    const spread = 0.5; // ~28.6 degrees
    return [
      PxPoint(tip.x - len * math.cos(angle - spread), tip.y - len * math.sin(angle - spread)),
      tip,
      PxPoint(tip.x - len * math.cos(angle + spread), tip.y - len * math.sin(angle + spread)),
    ];
  }

  static List<PxPoint> _squiggle(
      double left, double right, double y, double strokePx) {
    final amp = math.max(strokePx * 1.5, 2.0);
    final wavelength = math.max(amp * 4.0, 6.0);
    final span = math.max(right - left, 1.0);
    final steps = math.max((span / (wavelength / 4.0)).ceil(), 2);
    return [
      for (var i = 0; i <= steps; i++)
        PxPoint(
          left + span * (i / steps),
          y + amp * math.sin((span * (i / steps)) / wavelength * 2 * math.pi),
        ),
    ];
  }
}

/// A point in export-pixel space. Pure value type (no `dart:ui` dependency on
/// the drawing path) so draw primitives are trivially unit-testable.
@immutable
class PxPoint {
  const PxPoint(this.x, this.y);
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PxPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'PxPoint(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Resolved, pixel-space draw instruction produced from a normalized
/// annotation for a specific raster size. Pure data — the compositor turns
/// these into `image` package calls.
sealed class DrawOp {
  const DrawOp();
}

/// Connected line segments (ink, highlighter, line/arrow shafts, underline,
/// strikethrough, squiggly). [argb] already folds in opacity.
class PolylineOp extends DrawOp {
  const PolylineOp({
    required this.points,
    required this.argb,
    required this.widthPx,
    this.roundCap = false,
    this.closed = false,
  });
  final List<PxPoint> points;
  final int argb;
  final double widthPx;
  final bool roundCap;
  final bool closed;
}

/// Axis-aligned rectangle — filled (text highlight / redaction) or outlined.
class RectOp extends DrawOp {
  const RectOp({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.argb,
    required this.strokeWidthPx,
    required this.filled,
  });
  final double left, top, right, bottom;
  final int argb;
  final double strokeWidthPx;
  final bool filled;
}

/// Ellipse inscribed in the given bounds — filled or outlined.
class EllipseOp extends DrawOp {
  const EllipseOp({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.argb,
    required this.strokeWidthPx,
    required this.filled,
  });
  final double left, top, right, bottom;
  final int argb;
  final double strokeWidthPx;
  final bool filled;
}

/// A filled dot with a contrasting border — the comment pin marker.
class DotOp extends DrawOp {
  const DotOp({
    required this.cx,
    required this.cy,
    required this.radiusPx,
    required this.fillArgb,
    required this.borderArgb,
    required this.borderWidthPx,
  });
  final double cx, cy, radiusPx;
  final int fillArgb;
  final int borderArgb;
  final double borderWidthPx;
}

/// Number of polygon segments used to approximate an ellipse.
const int _kEllipseSegments = 48;

/// Parameters passed to the compositor isolate. Only pure-Dart, isolate-safe
/// values (bytes + plain annotation objects).
@immutable
class _CompositeParams {
  const _CompositeParams({required this.pngBytes, required this.annotations});
  final Uint8List pngBytes;
  final List<Annotation> annotations;
}

/// Top-level (isolate-safe) compositor: decode the page PNG, paint every
/// annotation in ascending z order, re-encode to PNG. Pure Dart (`image`
/// package only), so it runs safely under [compute].
Uint8List _compositePagePng(_CompositeParams p) {
  final image = img.decodePng(p.pngBytes);
  if (image == null) return p.pngBytes; // undecodable: leave the raster as-is
  final w = image.width.toDouble();
  final h = image.height.toDouble();
  for (final a in AnnotationFlattener.sortedForPaint(p.annotations)) {
    for (final op in AnnotationFlattener.opsForAnnotation(a, w, h)) {
      _paintOp(image, op);
    }
  }
  return img.encodePng(image);
}

img.Color _imgColor(int argb) => img.ColorRgba8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );

void _paintOp(img.Image image, DrawOp op) {
  switch (op) {
    case PolylineOp():
      _paintPolyline(image, op);
    case RectOp():
      final color = _imgColor(op.argb);
      if (op.filled) {
        img.fillRect(image,
            x1: op.left.round(),
            y1: op.top.round(),
            x2: op.right.round(),
            y2: op.bottom.round(),
            color: color);
      } else {
        img.drawRect(image,
            x1: op.left.round(),
            y1: op.top.round(),
            x2: op.right.round(),
            y2: op.bottom.round(),
            color: color,
            thickness: math.max(op.strokeWidthPx, 1.0));
      }
    case EllipseOp():
      _paintEllipse(image, op);
    case DotOp():
      img.fillCircle(image,
          x: op.cx.round(),
          y: op.cy.round(),
          radius: op.radiusPx.round(),
          color: _imgColor(op.fillArgb),
          antialias: true);
      img.drawCircle(image,
          x: op.cx.round(),
          y: op.cy.round(),
          radius: op.radiusPx.round(),
          color: _imgColor(op.borderArgb),
          antialias: true);
  }
}

void _paintPolyline(img.Image image, PolylineOp op) {
  final color = _imgColor(op.argb);
  final thickness = math.max(op.widthPx, 1.0);
  final pts = op.points;
  if (pts.isEmpty) return;
  if (pts.length == 1) {
    img.fillCircle(image,
        x: pts.first.x.round(),
        y: pts.first.y.round(),
        radius: math.max(thickness / 2.0, 1.0).round(),
        color: color);
    return;
  }
  for (var i = 0; i < pts.length - 1; i++) {
    img.drawLine(image,
        x1: pts[i].x.round(),
        y1: pts[i].y.round(),
        x2: pts[i + 1].x.round(),
        y2: pts[i + 1].y.round(),
        color: color,
        thickness: thickness,
        antialias: true);
  }
  if (op.closed && pts.length > 2) {
    img.drawLine(image,
        x1: pts.last.x.round(),
        y1: pts.last.y.round(),
        x2: pts.first.x.round(),
        y2: pts.first.y.round(),
        color: color,
        thickness: thickness,
        antialias: true);
  }
  // Round caps at the endpoints keep thick ink/highlighter strokes clean
  // without the alpha build-up that per-vertex dots would cause on
  // translucent strokes.
  if (op.roundCap && thickness > 2) {
    final r = (thickness / 2.0).round();
    img.fillCircle(image, x: pts.first.x.round(), y: pts.first.y.round(), radius: r, color: color);
    img.fillCircle(image, x: pts.last.x.round(), y: pts.last.y.round(), radius: r, color: color);
  }
}

void _paintEllipse(img.Image image, EllipseOp op) {
  final cx = (op.left + op.right) / 2.0;
  final cy = (op.top + op.bottom) / 2.0;
  final rx = (op.right - op.left).abs() / 2.0;
  final ry = (op.bottom - op.top).abs() / 2.0;
  if (rx < 0.5 || ry < 0.5) return;
  final verts = <img.Point>[
    for (var i = 0; i < _kEllipseSegments; i++)
      img.Point(
        cx + rx * math.cos((i / _kEllipseSegments) * 2 * math.pi),
        cy + ry * math.sin((i / _kEllipseSegments) * 2 * math.pi),
      ),
  ];
  final color = _imgColor(op.argb);
  if (op.filled) {
    img.fillPolygon(image, vertices: verts, color: color);
  } else {
    img.drawPolygon(image,
        vertices: verts,
        color: color,
        thickness: math.max(op.strokeWidthPx, 1.0),
        antialias: true);
  }
}
