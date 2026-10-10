import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/image_processing/scan_geometry.dart';

/// Builds a solid-white [size]x[size] source image.
img.Image _whitePage({int size = 400}) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixelRgb(x, y, 255, 255, 255);
    }
  }
  return image;
}

/// Paints a solid [r,g,b] square into [image] spanning `[x0,x1) x [y0,y1)`.
void _fillRect(img.Image image, int x0, int y0, int x1, int y1, int r, int g, int b) {
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
}

/// Mean `[r,g,b]` over the output block `[0,n) x [0,n)` (near the top-left).
List<double> _topLeftMean(img.Image out, {int n = 8}) {
  var sr = 0.0, sg = 0.0, sb = 0.0;
  var count = 0;
  for (var y = 0; y < n && y < out.height; y++) {
    for (var x = 0; x < n && x < out.width; x++) {
      final p = out.getPixel(x, y);
      sr += p.r;
      sg += p.g;
      sb += p.b;
      count++;
    }
  }
  return [sr / count, sg / count, sb / count];
}

void main() {
  group('ScanGeometry.dewarp', () {
    test('full-frame quad is an identity passthrough (same size as src)', () {
      final src = _whitePage(size: 120);
      final out = ScanGeometry.dewarp(src, NormalizedQuad.full);
      expect(out.width, src.width);
      expect(out.height, src.height);
    });

    test('keystone/trapezoid quad dewarps to an upright rectangle', () {
      final src = _whitePage(size: 400);
      // A convex, non-full trapezoid. Top-left corner sits at ~(80,80) px.
      const quad = NormalizedQuad(
        topLeft: NormalizedPoint(0.2, 0.2),
        topRight: NormalizedPoint(0.8, 0.1),
        bottomRight: NormalizedPoint(0.9, 0.9),
        bottomLeft: NormalizedPoint(0.1, 0.8),
      );
      // Distinct red mark covering the region around the quad's top-left corner.
      _fillRect(src, 60, 60, 101, 101, 255, 0, 0);

      final out = ScanGeometry.dewarp(src, quad);
      expect(out.width, greaterThan(0));
      expect(out.height, greaterThan(0));

      // The dst top-left corner maps to the quad's top-left source corner, so
      // the output's top-left region should sample the red mark.
      final mean = _topLeftMean(out);
      expect(mean[0], greaterThan(150), reason: 'red channel should dominate');
      expect(mean[1], lessThan(120), reason: 'green should be low');
      expect(mean[2], lessThan(120), reason: 'blue should be low');
    });

    test('respects maxDimension by scaling the output down', () {
      final src = _whitePage(size: 400);
      const quad = NormalizedQuad(
        topLeft: NormalizedPoint(0.2, 0.2),
        topRight: NormalizedPoint(0.8, 0.1),
        bottomRight: NormalizedPoint(0.9, 0.9),
        bottomLeft: NormalizedPoint(0.1, 0.8),
      );
      final out = ScanGeometry.dewarp(src, quad, maxDimension: 100);
      expect(out.width, lessThanOrEqualTo(100));
      expect(out.height, lessThanOrEqualTo(100));
    });

    test('degenerate/non-convex quad returns a clone (same dims as src)', () {
      final src = _whitePage(size: 200);
      // First three corners are collinear → not convex → identity clone.
      const quad = NormalizedQuad(
        topLeft: NormalizedPoint(0.0, 0.0),
        topRight: NormalizedPoint(0.5, 0.5),
        bottomRight: NormalizedPoint(1.0, 1.0),
        bottomLeft: NormalizedPoint(0.0, 1.0),
      );
      final out = ScanGeometry.dewarp(src, quad);
      expect(out.width, src.width);
      expect(out.height, src.height);
    });
  });
}
