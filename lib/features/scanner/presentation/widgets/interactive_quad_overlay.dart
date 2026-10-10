import 'package:flutter/material.dart';
import '../../../../core/image_processing/document_quad.dart';

/// Interactive draggable 4-corner quadrilateral overlay for the document
/// scanner's crop UI.
///
/// Unlike [InteractiveCropOverlay] (an axis-aligned rectangle), this surface
/// exposes four *independent* corner handles so the user can trace a skewed
/// document boundary for perspective / keystone correction. Dragging a handle
/// moves only that corner; updates that would make the quad non-convex are
/// rejected so the shape always stays valid for the downstream homography.
///
/// Pure presentation + gestures: no image processing happens here. The widget
/// fills its parent (place it inside a [Positioned.fill] over the page image)
/// and reports changes through [onQuadChanged] in normalized `[0, 1]`
/// coordinates (origin top-left).
class InteractiveQuadOverlay extends StatelessWidget {
  const InteractiveQuadOverlay({
    super.key,
    required this.quad,
    required this.accentColor,
    required this.onQuadChanged,
  });

  /// Current document boundary as four normalized corners (clockwise from
  /// top-left).
  final NormalizedQuad quad;

  /// Theme accent color for the edges and corner handles.
  final Color accentColor;

  /// Fired continuously as a corner is dragged, with the updated quad.
  final ValueChanged<NormalizedQuad> onQuadChanged;

  /// Diameter of the (invisible) square touch target around each corner.
  static const double _touchTarget = 44.0;

  /// Diameter of the visible handle dot centered in the touch target.
  static const double _handleDiameter = 20.0;

  void _onCornerDrag(int index, Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final corner = quad.corners[index];
    final moved = NormalizedPoint(
      corner.x + delta.dx / size.width,
      corner.y + delta.dy / size.height,
    ).clamped();

    final result = quad.withCorner(index, moved);

    // Keep the shape valid: never emit a self-intersecting / degenerate quad.
    if (!result.isConvex) return;

    onQuadChanged(result);
  }

  Widget _buildHandle(int index, Size size) {
    final corner = quad.corners[index];
    final cx = corner.x * size.width;
    final cy = corner.y * size.height;

    return Positioned(
      left: cx - _touchTarget / 2,
      top: cy - _touchTarget / 2,
      width: _touchTarget,
      height: _touchTarget,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _onCornerDrag(index, d.delta, size),
        child: Center(
          child: Container(
            width: _handleDiameter,
            height: _handleDiameter,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Scrim + edges + guide lines. Ignore pointer so only the corner
            // handles receive drag gestures.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  size: size,
                  painter: _QuadOverlayPainter(
                    quad: quad,
                    accentColor: accentColor,
                  ),
                ),
              ),
            ),
            // Four independent corner handles (tl, tr, br, bl).
            for (var i = 0; i < 4; i++) _buildHandle(i, size),
          ],
        );
      },
    );
  }
}

class _QuadOverlayPainter extends CustomPainter {
  const _QuadOverlayPainter({
    required this.quad,
    required this.accentColor,
  });

  final NormalizedQuad quad;
  final Color accentColor;

  Offset _toLocal(NormalizedPoint p, Size size) =>
      Offset(p.x * size.width, p.y * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final tl = _toLocal(quad.topLeft, size);
    final tr = _toLocal(quad.topRight, size);
    final br = _toLocal(quad.bottomRight, size);
    final bl = _toLocal(quad.bottomLeft, size);

    final quadPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    // 1. Semi-transparent dimming of the non-document area (outside the quad).
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scrimPath = Path.combine(PathOperation.difference, fullPath, quadPath);
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;
    canvas.drawPath(scrimPath, dimPaint);

    // 2. Perspective-aware rule-of-thirds guide lines inside the quad.
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final t in const [1.0 / 3.0, 2.0 / 3.0]) {
      // Lines spanning the (slanted) left↔right direction.
      canvas.drawLine(
        Offset.lerp(tl, tr, t)!,
        Offset.lerp(bl, br, t)!,
        gridPaint,
      );
      // Lines spanning the (slanted) top↔bottom direction.
      canvas.drawLine(
        Offset.lerp(tl, bl, t)!,
        Offset.lerp(tr, br, t)!,
        gridPaint,
      );
    }

    // 3. Quad border outline (tl→tr→br→bl→tl) in the accent color.
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(quadPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _QuadOverlayPainter oldDelegate) {
    return oldDelegate.quad != quad || oldDelegate.accentColor != accentColor;
  }
}
