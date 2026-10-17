import 'package:flutter/widgets.dart';

/// Helper utility for aligning layouts and borders to physical device pixels,
/// eliminating blurriness and fuzzy lines on fractional scaling displays (1.25x, 1.5x, 1.75x).
abstract final class PixelSnap {
  /// Computes the crisp width of a 1-physical-pixel hairline border on the current screen.
  /// Under 1.25x or 1.5x scaling, standard 1.0 logical pixel borders span fractional
  /// pixels and get anti-aliased into blurry 2px smudges. This returns the exact
  /// fractional logical dimension that maps to 1 hardware pixel.
  static double hairlineWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr <= 0) return 1.0;
    return (1.0 / dpr).clamp(0.5, 1.0);
  }

  /// Snaps a logical pixel coordinate to the nearest physical device pixel boundary.
  static double snap(double logicalPixels, double dpr) {
    if (dpr <= 0) return logicalPixels;
    return (logicalPixels * dpr).roundToDouble() / dpr;
  }

  /// Snaps an offset to the physical device pixel grid.
  static Offset snapOffset(Offset offset, double dpr) {
    if (dpr <= 0) return offset;
    return Offset(
      snap(offset.dx, dpr),
      snap(offset.dy, dpr),
    );
  }
}
