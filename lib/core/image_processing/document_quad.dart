import 'dart:math' as math;
import '../ocr/ocr_models.dart';

/// A point in normalized image coordinates, each component in `[0, 1]`
/// (origin top-left, x→right, y→down).
class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  final double x;
  final double y;

  NormalizedPoint clamped() =>
      NormalizedPoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));

  NormalizedPoint lerpTo(NormalizedPoint other, double t) =>
      NormalizedPoint(x + (other.x - x) * t, y + (other.y - y) * t);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory NormalizedPoint.fromJson(Map<String, dynamic> json) => NormalizedPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is NormalizedPoint &&
      (x - other.x).abs() < 1e-6 &&
      (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => Object.hash((x * 1e6).round(), (y * 1e6).round());

  @override
  String toString() => 'NP(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// A document boundary as four normalized corners in clockwise order starting
/// top-left. Used for the manual 4-corner crop overlay and perspective dewarp.
///
/// Stored on the scan page as in-session state (not persisted); when `null` or
/// [isFullFrame] the pipeline skips dewarp and uses the rectangular crop path.
class NormalizedQuad {
  const NormalizedQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final NormalizedPoint topLeft;
  final NormalizedPoint topRight;
  final NormalizedPoint bottomRight;
  final NormalizedPoint bottomLeft;

  /// The whole frame (corners at the image edges).
  static const NormalizedQuad full = NormalizedQuad(
    topLeft: NormalizedPoint(0, 0),
    topRight: NormalizedPoint(1, 0),
    bottomRight: NormalizedPoint(1, 1),
    bottomLeft: NormalizedPoint(0, 1),
  );

  /// Builds a quad from an axis-aligned [NormalizedRect].
  factory NormalizedQuad.fromRect(NormalizedRect rect) => NormalizedQuad(
        topLeft: NormalizedPoint(rect.x, rect.y),
        topRight: NormalizedPoint(rect.x + rect.width, rect.y),
        bottomRight: NormalizedPoint(rect.x + rect.width, rect.y + rect.height),
        bottomLeft: NormalizedPoint(rect.x, rect.y + rect.height),
      );

  /// Corners clockwise from top-left: `[tl, tr, br, bl]`.
  List<NormalizedPoint> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  NormalizedQuad clamped() => NormalizedQuad(
        topLeft: topLeft.clamped(),
        topRight: topRight.clamped(),
        bottomRight: bottomRight.clamped(),
        bottomLeft: bottomLeft.clamped(),
      );

  /// Replaces the corner at [index] (0=tl,1=tr,2=br,3=bl).
  NormalizedQuad withCorner(int index, NormalizedPoint p) => NormalizedQuad(
        topLeft: index == 0 ? p : topLeft,
        topRight: index == 1 ? p : topRight,
        bottomRight: index == 2 ? p : bottomRight,
        bottomLeft: index == 3 ? p : bottomLeft,
      );

  /// Whether the four corners sit (approximately) at the frame edges, meaning
  /// no meaningful dewarp/crop is implied.
  bool get isFullFrame {
    const e = 0.02;
    return topLeft.x < e &&
        topLeft.y < e &&
        topRight.x > 1 - e &&
        topRight.y < e &&
        bottomRight.x > 1 - e &&
        bottomRight.y > 1 - e &&
        bottomLeft.x < e &&
        bottomLeft.y > 1 - e;
  }

  /// Whether the quad is a non-degenerate convex polygon (all cross products of
  /// consecutive edges share a sign). Guards the overlay and the homography.
  bool get isConvex {
    final pts = corners;
    double? sign;
    for (var i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final c = pts[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross.abs() < 1e-9) return false; // collinear → degenerate
      final s = cross.sign;
      if (sign == null) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }

  /// Axis-aligned bounding rect of the quad (normalized).
  NormalizedRect get boundingRect {
    final xs = corners.map((p) => p.x);
    final ys = corners.map((p) => p.y);
    final minX = xs.reduce(math.min);
    final minY = ys.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final maxY = ys.reduce(math.max);
    return NormalizedRect(
      x: minX,
      y: minY,
      width: (maxX - minX).clamp(0.0, 1.0),
      height: (maxY - minY).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'topLeft': topLeft.toJson(),
        'topRight': topRight.toJson(),
        'bottomRight': bottomRight.toJson(),
        'bottomLeft': bottomLeft.toJson(),
      };

  factory NormalizedQuad.fromJson(Map<String, dynamic> json) => NormalizedQuad(
        topLeft: NormalizedPoint.fromJson(json['topLeft'] as Map<String, dynamic>),
        topRight: NormalizedPoint.fromJson(json['topRight'] as Map<String, dynamic>),
        bottomRight:
            NormalizedPoint.fromJson(json['bottomRight'] as Map<String, dynamic>),
        bottomLeft:
            NormalizedPoint.fromJson(json['bottomLeft'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      other is NormalizedQuad &&
      topLeft == other.topLeft &&
      topRight == other.topRight &&
      bottomRight == other.bottomRight &&
      bottomLeft == other.bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'NormalizedQuad($topLeft, $topRight, $bottomRight, $bottomLeft)';
}
