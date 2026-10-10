import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'document_quad.dart';

/// Best-effort automatic document corner detection for the scanner.
///
/// Pure Dart (no Flutter, no I/O, no network, no ML) built on the `image`
/// package, so it is safe to run inside an isolate. The approach is a simple
/// luminance-segmentation + extreme-point scan: it separates the brighter (or
/// darker) page region from its background with an Otsu threshold, then reads
/// the four document corners as the mask's extreme points. This naturally
/// handles a rotated page and returns a convex quad.
///
/// It is intentionally conservative: anything that looks like noise, a blank
/// frame, or the whole frame yields [NormalizedQuad.full] with confidence `0`
/// so callers can fall back to a manual crop.
class DocumentDetector {
  const DocumentDetector._();

  /// Longest side (px) of the internal working copy. Detection accuracy does
  /// not benefit from full resolution and the scan is O(pixels).
  static const int _workingMaxDim = 500;

  /// Confidence below which we treat detection as a failure.
  static const double _minConfidence = 0.35;

  /// Best-effort detection of the document boundary in [src]. Returns a
  /// normalized quad (clockwise tl,tr,br,bl) and a confidence in [0,1].
  /// Low confidence or failure returns `(quad: NormalizedQuad.full, confidence: 0)`.
  /// Pure & isolate-safe (no Flutter imports, no I/O). Never throws.
  static ({NormalizedQuad quad, double confidence}) detect(img.Image src) {
    try {
      // 1. Downscale a working copy and grayscale it. Clone so [src] is never
      //    mutated (grayscale works in place).
      img.Image work = src;
      final srcMax = math.max(src.width, src.height);
      if (srcMax > _workingMaxDim) {
        work = src.width >= src.height
            ? img.copyResize(src,
                width: _workingMaxDim,
                interpolation: img.Interpolation.average)
            : img.copyResize(src,
                height: _workingMaxDim,
                interpolation: img.Interpolation.average);
      }
      final gray = img.grayscale(img.Image.from(work));

      final w = gray.width;
      final h = gray.height;
      // Need at least a 2x2 image to span normalized [0,1] meaningfully.
      if (w < 2 || h < 2) return _fail();

      // 2. Global Otsu threshold over the luminance histogram.
      final hist = List<int>.filled(256, 0);
      var total = 0;
      for (final p in gray) {
        hist[p.r.round().clamp(0, 255)]++;
        total++;
      }
      if (total == 0) return _fail();
      final threshold = _otsuThreshold(hist, total);

      // 3. Scan once, collecting extreme points for BOTH polarities: the page
      //    may be brighter than its background (common) or darker. We score
      //    both and keep the stronger candidate.
      final bright = _Extremes();
      final dark = _Extremes();
      for (final p in gray) {
        final v = p.r;
        if (v > threshold) {
          bright.add(p.x, p.y);
        } else if (v < threshold) {
          dark.add(p.x, p.y);
        }
      }

      final candidates = <({NormalizedQuad quad, double confidence})>[];
      for (final e in [bright, dark]) {
        if (e.count == 0) continue;
        final quad = e.toQuad(w, h);
        candidates.add((quad: quad, confidence: _score(quad)));
      }
      if (candidates.isEmpty) return _fail();

      candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
      final best = candidates.first;
      if (best.confidence < _minConfidence) return _fail();
      return best;
    } catch (_) {
      // Best-effort: any failure degrades gracefully to the full frame.
      return _fail();
    }
  }

  static ({NormalizedQuad quad, double confidence}) _fail() =>
      (quad: NormalizedQuad.full, confidence: 0.0);

  /// Classic Otsu: the threshold maximizing between-class variance.
  static int _otsuThreshold(List<int> hist, int total) {
    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * hist[i];
    }
    var sumB = 0.0;
    var wB = 0;
    var maxVar = -1.0;
    var threshold = 127;
    for (var t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final between = wB * wF * (mB - mF) * (mB - mF);
      if (between > maxVar) {
        maxVar = between;
        threshold = t;
      }
    }
    return threshold;
  }

  /// Confidence heuristic in [0,1] combining three signals:
  /// convexity (gate), how sensibly the quad fills the frame, and how far it
  /// is inset from the edges (a full-frame quad means "nothing found").
  static double _score(NormalizedQuad quad) {
    if (!quad.isConvex) return 0.0;

    // Fill: polygon area as a fraction of the frame. Reject near-empty and
    // near-whole-frame; reward a sensible middle band.
    final area = _polygonArea(quad.corners);
    double fill;
    if (area < 0.05 || area > 0.985) {
      fill = 0.0;
    } else if (area < 0.2) {
      fill = (area - 0.05) / (0.2 - 0.05);
    } else if (area > 0.9) {
      fill = (0.985 - area) / (0.985 - 0.9);
    } else {
      fill = 1.0;
    }
    fill = fill.clamp(0.0, 1.0);

    // Inset: smallest margin between the quad's bounding box and the frame
    // edge. A full-frame detection has ~0 margin and scores 0 here.
    final r = quad.boundingRect;
    final minMargin = [
      r.x,
      r.y,
      1.0 - (r.x + r.width),
      1.0 - (r.y + r.height),
    ].reduce(math.min);
    final inset = (minMargin / 0.08).clamp(0.0, 1.0);

    return (0.5 * fill + 0.5 * inset).clamp(0.0, 1.0);
  }

  /// Shoelace area of a polygon in normalized coords (absolute, so winding
  /// direction does not matter).
  static double _polygonArea(List<NormalizedPoint> pts) {
    var acc = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      acc += a.x * b.y - b.x * a.y;
    }
    return acc.abs() / 2.0;
  }
}

/// Running tracker of the four extreme foreground pixels used as document
/// corners: tl minimizes (x+y), tr maximizes (x-y), br maximizes (x+y),
/// bl minimizes (x-y).
class _Extremes {
  int count = 0;

  int _tlX = 0, _tlY = 0, _tlSum = 1 << 30;
  int _trX = 0, _trY = 0, _trDiff = -(1 << 30);
  int _brX = 0, _brY = 0, _brSum = -(1 << 30);
  int _blX = 0, _blY = 0, _blDiff = 1 << 30;

  void add(int x, int y) {
    count++;
    final sum = x + y;
    final diff = x - y;
    if (sum < _tlSum) {
      _tlSum = sum;
      _tlX = x;
      _tlY = y;
    }
    if (diff > _trDiff) {
      _trDiff = diff;
      _trX = x;
      _trY = y;
    }
    if (sum > _brSum) {
      _brSum = sum;
      _brX = x;
      _brY = y;
    }
    if (diff < _blDiff) {
      _blDiff = diff;
      _blX = x;
      _blY = y;
    }
  }

  /// Maps the collected pixel corners into a normalized clockwise quad.
  NormalizedQuad toQuad(int w, int h) {
    final dx = (w - 1).toDouble();
    final dy = (h - 1).toDouble();
    NormalizedPoint n(int x, int y) =>
        NormalizedPoint((x / dx).clamp(0.0, 1.0), (y / dy).clamp(0.0, 1.0));
    return NormalizedQuad(
      topLeft: n(_tlX, _tlY),
      topRight: n(_trX, _trY),
      bottomRight: n(_brX, _brY),
      bottomLeft: n(_blX, _blY),
    );
  }
}
