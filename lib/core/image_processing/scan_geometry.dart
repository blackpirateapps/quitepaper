import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'document_quad.dart';

/// Pure-Dart perspective dewarp (homography warp) for the document scanner.
///
/// Takes a [NormalizedQuad] describing the four document corners in a source
/// photo and flattens that quadrilateral into an upright rectangle, undoing the
/// perspective keystone introduced by shooting a page at an angle.
///
/// Everything here is a pure function of its inputs — no Flutter imports and no
/// I/O — so it is safe to run inside a `compute()` isolate alongside the
/// [ScanPipelines] colour stages.
class ScanGeometry {
  const ScanGeometry._();

  /// Smallest output edge (px) we will emit; guards against degenerate quads
  /// collapsing to a zero-size image.
  static const int _minDim = 16;

  /// Perspective-dewarps the quadrilateral [quad] (normalized coords over [src])
  /// into an upright rectangle. Returns a NEW img.Image (3-channel). Pure &
  /// isolate-safe (no Flutter imports, no I/O). If [quad] is full-frame,
  /// degenerate, or not convex, returns a clone of [src] unchanged.
  static img.Image dewarp(img.Image src, NormalizedQuad quad, {int? maxDimension}) {
    // Nothing meaningful to correct: identity passthrough.
    if (quad.isFullFrame || !quad.isConvex) {
      return src.clone();
    }

    // Normalized corners → source pixel coordinates, clockwise tl,tr,br,bl.
    final tl = _toPixel(quad.topLeft, src);
    final tr = _toPixel(quad.topRight, src);
    final br = _toPixel(quad.bottomRight, src);
    final bl = _toPixel(quad.bottomLeft, src);

    // Target rectangle size from the quad's physical edge lengths in source px.
    final topW = _dist(tl, tr);
    final bottomW = _dist(bl, br);
    final leftH = _dist(tl, bl);
    final rightH = _dist(tr, br);
    var w = math.max(topW, bottomW).round();
    var h = math.max(leftH, rightH).round();

    // Scale down proportionally if a max dimension cap is requested.
    if (maxDimension != null && math.max(w, h) > maxDimension) {
      final scale = maxDimension / math.max(w, h);
      w = (w * scale).round();
      h = (h * scale).round();
    }

    // Guard against tiny/zero sizes.
    w = math.max(w, _minDim);
    h = math.max(h, _minDim);

    // Homography maps DESTINATION rect corners → SOURCE quad corners, so a
    // forward map of each dst pixel lands directly on the source to sample.
    final homography = _solveHomography(
      [
        _Point(0, 0),
        _Point((w - 1).toDouble(), 0),
        _Point((w - 1).toDouble(), (h - 1).toDouble()),
        _Point(0, (h - 1).toDouble()),
      ],
      [tl, tr, br, bl],
    );
    if (homography == null) {
      // Singular system — bail out rather than emit garbage.
      return src.clone();
    }

    final h0 = homography[0], h1 = homography[1], h2 = homography[2];
    final h3 = homography[3], h4 = homography[4], h5 = homography[5];
    final h6 = homography[6], h7 = homography[7];

    final out = img.Image(width: w, height: h, numChannels: 3);
    final maxX = src.width - 1;
    final maxY = src.height - 1;

    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        final denom = h6 * dx + h7 * dy + 1.0;
        // Degenerate projection for this pixel: fall back to black.
        if (denom == 0) {
          out.setPixelRgb(dx, dy, 0, 0, 0);
          continue;
        }
        final u = (h0 * dx + h1 * dy + h2) / denom;
        final v = (h3 * dx + h4 * dy + h5) / denom;
        final rgb = _bilinear(src, u, v, maxX, maxY);
        out.setPixelRgb(dx, dy, rgb[0], rgb[1], rgb[2]);
      }
    }
    return out;
  }

  /// Converts a normalized point to source pixel coordinates.
  static _Point _toPixel(NormalizedPoint p, img.Image src) =>
      _Point(p.x * src.width, p.y * src.height);

  static double _dist(_Point a, _Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Solves for the 8 DOF homography (h8 fixed to 1) mapping each [dst] corner
  /// to the matching [src] corner, via an 8x8 linear system and Gaussian
  /// elimination with partial pivoting. Returns `[h0..h7]`, or `null` if the
  /// system is singular.
  ///
  /// For a correspondence dst(x,y) → src(u,v):
  ///   u = (h0*x + h1*y + h2) / (h6*x + h7*y + 1)
  ///   v = (h3*x + h4*y + h5) / (h6*x + h7*y + 1)
  /// linearized into two rows per correspondence:
  ///   h0*x + h1*y + h2 - h6*x*u - h7*y*u = u
  ///   h3*x + h4*y + h5 - h6*x*v - h7*y*v = v
  static List<double>? _solveHomography(List<_Point> dst, List<_Point> src) {
    // Augmented 8x9 matrix: 8 unknowns + 1 RHS column.
    final a = List.generate(8, (_) => List<double>.filled(9, 0.0));
    for (var i = 0; i < 4; i++) {
      final x = dst[i].x, y = dst[i].y;
      final u = src[i].x, v = src[i].y;
      final r0 = i * 2;
      final r1 = r0 + 1;

      a[r0][0] = x;
      a[r0][1] = y;
      a[r0][2] = 1;
      a[r0][6] = -x * u;
      a[r0][7] = -y * u;
      a[r0][8] = u;

      a[r1][3] = x;
      a[r1][4] = y;
      a[r1][5] = 1;
      a[r1][6] = -x * v;
      a[r1][7] = -y * v;
      a[r1][8] = v;
    }

    // Gaussian elimination with partial pivoting.
    const n = 8;
    for (var col = 0; col < n; col++) {
      // Find the pivot row (largest magnitude in this column).
      var pivot = col;
      var best = a[col][col].abs();
      for (var r = col + 1; r < n; r++) {
        final mag = a[r][col].abs();
        if (mag > best) {
          best = mag;
          pivot = r;
        }
      }
      if (best < 1e-12) return null; // Singular.
      if (pivot != col) {
        final tmp = a[col];
        a[col] = a[pivot];
        a[pivot] = tmp;
      }

      // Eliminate this column from the rows below.
      final pivVal = a[col][col];
      for (var r = col + 1; r < n; r++) {
        final factor = a[r][col] / pivVal;
        if (factor == 0) continue;
        for (var c = col; c <= n; c++) {
          a[r][c] -= factor * a[col][c];
        }
      }
    }

    // Back-substitution.
    final h = List<double>.filled(n, 0.0);
    for (var row = n - 1; row >= 0; row--) {
      var sum = a[row][n];
      for (var c = row + 1; c < n; c++) {
        sum -= a[row][c] * h[c];
      }
      final diag = a[row][row];
      if (diag.abs() < 1e-12) return null;
      h[row] = sum / diag;
    }
    return h;
  }

  /// Bilinearly samples [src] at the (possibly fractional) coordinate (u,v),
  /// clamping to the image bounds. Returns `[r, g, b]` as ints in `[0, 255]`.
  static List<int> _bilinear(img.Image src, double u, double v, int maxX, int maxY) {
    final cu = u.clamp(0.0, maxX.toDouble());
    final cv = v.clamp(0.0, maxY.toDouble());
    final x0 = cu.floor();
    final y0 = cv.floor();
    final x1 = math.min(x0 + 1, maxX);
    final y1 = math.min(y0 + 1, maxY);
    final fx = cu - x0;
    final fy = cv - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final w00 = (1 - fx) * (1 - fy);
    final w10 = fx * (1 - fy);
    final w01 = (1 - fx) * fy;
    final w11 = fx * fy;

    int mix(num a, num b, num c, num d) =>
        (a * w00 + b * w10 + c * w01 + d * w11).round().clamp(0, 255);

    return [
      mix(p00.r, p10.r, p01.r, p11.r),
      mix(p00.g, p10.g, p01.g, p11.g),
      mix(p00.b, p10.b, p01.b, p11.b),
    ];
  }
}

/// Lightweight 2D point used internally for pixel-space geometry.
class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;
}
