import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/ocr/ocr_models.dart';

enum _CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topEdge,
  bottomEdge,
  leftEdge,
  rightEdge,
  body,
  none,
}

/// Interactive draggable crop surface with direct manipulation of corner handles,
/// edge bars, and body panning with real-time normalized coordinate updates.
class InteractiveCropOverlay extends StatefulWidget {
  const InteractiveCropOverlay({
    super.key,
    required this.crop,
    required this.onCropChanged,
    this.onCropEnd,
    this.accentColor = const Color(0xFFD97706),
    this.enabled = true,
  });

  /// Current normalized crop rectangle in range `[0.0, 1.0]`.
  final NormalizedRect? crop;

  /// Callback fired continuously during drag gestures.
  final ValueChanged<NormalizedRect> onCropChanged;

  /// Callback fired when the drag gesture completes.
  final VoidCallback? onCropEnd;

  /// Theme accent color for corner handles and bounding box.
  final Color accentColor;

  /// Whether user manipulation is active.
  final bool enabled;

  @override
  State<InteractiveCropOverlay> createState() => _InteractiveCropOverlayState();
}

class _InteractiveCropOverlayState extends State<InteractiveCropOverlay> {
  _CropHandle _activeHandle = _CropHandle.none;

  static const double _minDimension = 0.05; // 5% minimum normalized dimension
  static const double _hitSlop = 36.0; // 36dp touch target radius

  NormalizedRect get _effectiveCrop =>
      widget.crop ?? const NormalizedRect(x: 0, y: 0, width: 1, height: 1);

  _CropHandle _determineHandle(Offset localPos, Size size) {
    if (size.width <= 0 || size.height <= 0) return _CropHandle.none;

    final crop = _effectiveCrop;
    final pixelLeft = crop.x * size.width;
    final pixelTop = crop.y * size.height;
    final pixelRight = crop.right * size.width;
    final pixelBottom = crop.bottom * size.height;

    double dist(double x1, double y1, double x2, double y2) {
      final dx = x1 - x2;
      final dy = y1 - y2;
      return math.sqrt(dx * dx + dy * dy);
    }

    // 1. Check Corner Handles (highest priority)
    if (dist(localPos.dx, localPos.dy, pixelLeft, pixelTop) <= _hitSlop) {
      return _CropHandle.topLeft;
    }
    if (dist(localPos.dx, localPos.dy, pixelRight, pixelTop) <= _hitSlop) {
      return _CropHandle.topRight;
    }
    if (dist(localPos.dx, localPos.dy, pixelLeft, pixelBottom) <= _hitSlop) {
      return _CropHandle.bottomLeft;
    }
    if (dist(localPos.dx, localPos.dy, pixelRight, pixelBottom) <= _hitSlop) {
      return _CropHandle.bottomRight;
    }

    // 2. Check Edge Handles
    if ((localPos.dy - pixelTop).abs() <= _hitSlop &&
        localPos.dx >= pixelLeft &&
        localPos.dx <= pixelRight) {
      return _CropHandle.topEdge;
    }
    if ((localPos.dy - pixelBottom).abs() <= _hitSlop &&
        localPos.dx >= pixelLeft &&
        localPos.dx <= pixelRight) {
      return _CropHandle.bottomEdge;
    }
    if ((localPos.dx - pixelLeft).abs() <= _hitSlop &&
        localPos.dy >= pixelTop &&
        localPos.dy <= pixelBottom) {
      return _CropHandle.leftEdge;
    }
    if ((localPos.dx - pixelRight).abs() <= _hitSlop &&
        localPos.dy >= pixelTop &&
        localPos.dy <= pixelBottom) {
      return _CropHandle.rightEdge;
    }

    // 3. Check Inside Body for Panning
    if (localPos.dx >= pixelLeft &&
        localPos.dx <= pixelRight &&
        localPos.dy >= pixelTop &&
        localPos.dy <= pixelBottom) {
      return _CropHandle.body;
    }

    return _CropHandle.none;
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (!widget.enabled) return;
    _activeHandle = _determineHandle(details.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!widget.enabled || _activeHandle == _CropHandle.none) return;
    if (size.width <= 0 || size.height <= 0) return;

    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;

    final crop = _effectiveCrop;
    double left = crop.x;
    double top = crop.y;
    double right = crop.right;
    double bottom = crop.bottom;

    switch (_activeHandle) {
      case _CropHandle.topLeft:
        left = (left + dx).clamp(0.0, right - _minDimension);
        top = (top + dy).clamp(0.0, bottom - _minDimension);
        break;
      case _CropHandle.topRight:
        right = (right + dx).clamp(left + _minDimension, 1.0);
        top = (top + dy).clamp(0.0, bottom - _minDimension);
        break;
      case _CropHandle.bottomLeft:
        left = (left + dx).clamp(0.0, right - _minDimension);
        bottom = (bottom + dy).clamp(top + _minDimension, 1.0);
        break;
      case _CropHandle.bottomRight:
        right = (right + dx).clamp(left + _minDimension, 1.0);
        bottom = (bottom + dy).clamp(top + _minDimension, 1.0);
        break;
      case _CropHandle.topEdge:
        top = (top + dy).clamp(0.0, bottom - _minDimension);
        break;
      case _CropHandle.bottomEdge:
        bottom = (bottom + dy).clamp(top + _minDimension, 1.0);
        break;
      case _CropHandle.leftEdge:
        left = (left + dx).clamp(0.0, right - _minDimension);
        break;
      case _CropHandle.rightEdge:
        right = (right + dx).clamp(left + _minDimension, 1.0);
        break;
      case _CropHandle.body:
        final w = right - left;
        final h = bottom - top;
        left = (left + dx).clamp(0.0, 1.0 - w);
        top = (top + dy).clamp(0.0, 1.0 - h);
        right = left + w;
        bottom = top + h;
        break;
      case _CropHandle.none:
        return;
    }

    final updatedRect = NormalizedRect(
      x: left,
      y: top,
      width: (right - left).clamp(_minDimension, 1.0),
      height: (bottom - top).clamp(_minDimension, 1.0),
    );

    widget.onCropChanged(updatedRect);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    _activeHandle = _CropHandle.none;
    widget.onCropEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: size,
            painter: _CropOverlayPainter(
              crop: _effectiveCrop,
              accentColor: widget.accentColor,
            ),
          ),
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.crop,
    required this.accentColor,
  });

  final NormalizedRect crop;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final left = crop.x * size.width;
    final top = crop.y * size.height;
    final width = crop.width * size.width;
    final height = crop.height * size.height;
    final right = left + width;
    final bottom = top + height;
    final cropRect = Rect.fromLTRB(left, top, right, bottom);

    // 1. Semi-transparent dimming outside the crop rectangle
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;

    // Top rect
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, top), dimPaint);
    // Bottom rect
    canvas.drawRect(Rect.fromLTRB(0, bottom, size.width, size.height), dimPaint);
    // Left rect
    canvas.drawRect(Rect.fromLTRB(0, top, left, bottom), dimPaint);
    // Right rect
    canvas.drawRect(Rect.fromLTRB(right, top, size.width, bottom), dimPaint);

    // 2. Crop border outline
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRect(cropRect, borderPaint);

    // 3. Rule of Thirds subtle grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final oneThirdW = width / 3.0;
    final twoThirdsW = 2.0 * oneThirdW;
    final oneThirdH = height / 3.0;
    final twoThirdsH = 2.0 * oneThirdH;

    canvas.drawLine(Offset(left + oneThirdW, top), Offset(left + oneThirdW, bottom), gridPaint);
    canvas.drawLine(Offset(left + twoThirdsW, top), Offset(left + twoThirdsW, bottom), gridPaint);
    canvas.drawLine(Offset(left, top + oneThirdH), Offset(right, top + oneThirdH), gridPaint);
    canvas.drawLine(Offset(left, top + twoThirdsH), Offset(right, top + twoThirdsH), gridPaint);

    // 4. L-shaped Corner Handles
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 16.0;

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), cornerPaint);

    // 5. Edge Pill Handles
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    const edgeLength = 16.0;
    const edgeThickness = 3.0;

    // Top Edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left + width / 2, top), width: edgeLength, height: edgeThickness),
        const Radius.circular(2),
      ),
      edgePaint,
    );
    // Bottom Edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left + width / 2, bottom), width: edgeLength, height: edgeThickness),
        const Radius.circular(2),
      ),
      edgePaint,
    );
    // Left Edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(left, top + height / 2), width: edgeThickness, height: edgeLength),
        const Radius.circular(2),
      ),
      edgePaint,
    );
    // Right Edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(right, top + height / 2), width: edgeThickness, height: edgeLength),
        const Radius.circular(2),
      ),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.crop != crop || oldDelegate.accentColor != accentColor;
  }
}
