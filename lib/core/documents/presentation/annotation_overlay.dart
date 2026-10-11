import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ocr/ocr_models.dart';
import '../annotations/annotation_editing_controller.dart';
import '../annotations/annotation_models.dart';
import '../annotations/annotation_text_selection.dart';

/// Vector annotation overlay painted directly over a page raster, living inside
/// the viewer's `InteractiveViewer` child so marks pan/zoom with the page and
/// stay crisp at any scale (spec §4.4). It must be laid out at the page's
/// intrinsic aspect ratio (no `BoxFit` letterbox) so a local gesture position
/// maps to page-normalized coordinates by a plain divide by the box size
/// (spec §4.3).
///
/// Gesture model (spec §4.5): the parent sets `InteractiveViewer.panEnabled`
/// false while a markup tool is active, so a one-finger drag can never be
/// stolen for panning; two fingers still pinch-zoom (and the in-progress stroke
/// is cancelled the moment a second pointer lands). Switching to Navigate
/// restores full pan/zoom.
class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({
    super.key,
    required this.controller,
    required this.pageIndex,
    this.ocrPage,
    this.textSelector = const AnnotationTextSelector(),
    required this.onCopyText,
    required this.onEditComment,
  });

  final AnnotationEditingController controller;
  final int pageIndex;

  /// Decrypted OCR geometry for this page; null until OCR is available. When
  /// null, text-anchored tools are inert.
  final OcrPage? ocrPage;
  final AnnotationTextSelector textSelector;

  /// Copies resolved OCR text to the clipboard (shows feedback).
  final void Function(String text) onCopyText;

  /// Opens the comment editor; returns the body text or null if cancelled.
  final Future<String?> Function(String? initial) onEditComment;

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  final Set<int> _activePointers = {};

  // In-progress gesture state, all in normalized page coordinates.
  final List<Offset> _livePoints = [];
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _drawing = false;
  bool _cancelled = false;

  AnnotationEditingController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Repaint committed marks when the controller mutates (add/undo/redo/tool).
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _markup => _c.isMarkupMode;

  Offset _normalize(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _onPointerDown(PointerDownEvent e, Size size) {
    _activePointers.add(e.pointer);
    if (!_markup) return;
    if (_activePointers.length > 1) {
      // Second finger: abandon any stroke so the gesture becomes pinch-zoom.
      _cancelDraw();
      return;
    }
    final n = _normalize(e.localPosition, size);
    setState(() {
      _drawing = true;
      _cancelled = false;
      _dragStart = n;
      _dragCurrent = n;
      _livePoints
        ..clear()
        ..add(n);
    });
    if (_c.tool == AnnotationTool.eraser) {
      _eraseAt(n);
    }
  }

  void _onPointerMove(PointerMoveEvent e, Size size) {
    if (!_markup || !_drawing || _cancelled) return;
    if (_activePointers.length > 1) {
      _cancelDraw();
      return;
    }
    final n = _normalize(e.localPosition, size);
    setState(() {
      _dragCurrent = n;
      if (_c.tool.isFreeformDraw &&
          (_c.tool == AnnotationTool.ink ||
              _c.tool == AnnotationTool.highlighter)) {
        _livePoints.add(n);
      }
    });
    if (_c.tool == AnnotationTool.eraser) {
      _eraseAt(n);
    }
  }

  void _onPointerUp(PointerUpEvent e, Size size) {
    _activePointers.remove(e.pointer);
    if (!_markup || !_drawing || _cancelled) {
      _drawing = false;
      return;
    }
    _commit(size);
    _resetDraw();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers.remove(e.pointer);
    _cancelDraw();
  }

  void _cancelDraw() {
    if (!_drawing && _livePoints.isEmpty && _dragStart == null) return;
    setState(() {
      _cancelled = true;
      _resetDraw();
    });
  }

  void _resetDraw() {
    _drawing = false;
    _livePoints.clear();
    _dragStart = null;
    _dragCurrent = null;
  }
  // ---- Commit the finished gesture into an annotation ----

  void _commit(Size size) {
    final tool = _c.tool;
    final start = _dragStart;
    final current = _dragCurrent;
    if (start == null || current == null) return;

    switch (tool) {
      case AnnotationTool.ink:
      case AnnotationTool.highlighter:
        if (_livePoints.length < 2) {
          // A tap with a draw tool: drop a tiny dot so it isn't lost.
          _livePoints.add(Offset(
            (current.dx + 0.002).clamp(0.0, 1.0),
            current.dy,
          ));
        }
        final type = tool == AnnotationTool.ink
            ? AnnotationType.ink
            : AnnotationType.highlighterFree;
        _c.addAnnotation(_c.buildAnnotation(
          pageIndex: widget.pageIndex,
          type: type,
          geometry: AnnotationGeometry(points: List<Offset>.from(_livePoints)),
        ));
        break;

      case AnnotationTool.line:
      case AnnotationTool.arrow:
        final end = _c.snapStraight ? _snapAngle(start, current) : current;
        _c.addAnnotation(_c.buildAnnotation(
          pageIndex: widget.pageIndex,
          type: tool == AnnotationTool.line
              ? AnnotationType.line
              : AnnotationType.arrow,
          geometry: AnnotationGeometry(points: [start, end]),
        ));
        break;

      case AnnotationTool.rect:
      case AnnotationTool.ellipse:
        final r = _rectFrom(start, current);
        if (r.width < 0.004 && r.height < 0.004) break;
        _c.addAnnotation(_c.buildAnnotation(
          pageIndex: widget.pageIndex,
          type: tool == AnnotationTool.rect
              ? AnnotationType.rect
              : AnnotationType.ellipse,
          geometry: AnnotationGeometry(rects: [r]),
        ));
        break;

      case AnnotationTool.redaction:
        final r = _rectFrom(start, current);
        if (r.width < 0.004 && r.height < 0.004) break;
        _c.addAnnotation(_c.buildAnnotation(
          pageIndex: widget.pageIndex,
          type: AnnotationType.redaction,
          geometry: AnnotationGeometry(rects: [r]),
          style: const AnnotationStyle(colorArgb: 0xFF000000, opacity: 1.0, filled: true),
        ));
        break;

      case AnnotationTool.textHighlight:
      case AnnotationTool.underline:
      case AnnotationTool.strikethrough:
      case AnnotationTool.squiggly:
        _commitTextAnchored(tool, start, current);
        break;

      case AnnotationTool.select:
        _commitSelectCopy(start, current);
        break;

      case AnnotationTool.comment:
        _commitComment(current);
        break;

      case AnnotationTool.eraser:
      case AnnotationTool.navigate:
        break;
    }
  }

  void _commitTextAnchored(AnnotationTool tool, Offset start, Offset current) {
    final ocr = widget.ocrPage;
    if (ocr == null) return;
    final result = widget.textSelector.resolve(ocr, _rectFrom(start, current));
    if (result.lineRects.isEmpty) return;
    final type = switch (tool) {
      AnnotationTool.textHighlight => AnnotationType.textHighlight,
      AnnotationTool.underline => AnnotationType.underline,
      AnnotationTool.strikethrough => AnnotationType.strikethrough,
      _ => AnnotationType.squiggly,
    };
    _c.addAnnotation(_c.buildAnnotation(
      pageIndex: widget.pageIndex,
      type: type,
      geometry: AnnotationGeometry(rects: result.lineRects),
      text: result.text,
      style: AnnotationStyle(
        colorArgb: _c.colorArgb,
        strokeWidth: _c.strokeWidth,
        opacity: type == AnnotationType.textHighlight ? 0.35 : 1.0,
      ),
    ));
  }

  void _commitSelectCopy(Offset start, Offset current) {
    final ocr = widget.ocrPage;
    if (ocr == null) return;
    final result = widget.textSelector.resolve(ocr, _rectFrom(start, current));
    if (result.text.trim().isNotEmpty) widget.onCopyText(result.text);
  }

  Future<void> _commitComment(Offset anchor) async {
    final body = await widget.onEditComment(null);
    if (body == null || body.trim().isEmpty) return;
    _c.addAnnotation(_c.buildAnnotation(
      pageIndex: widget.pageIndex,
      type: AnnotationType.comment,
      geometry: AnnotationGeometry(anchor: anchor),
      text: body.trim(),
      style: AnnotationStyle(colorArgb: _c.colorArgb),
    ));
  }

  void _eraseAt(Offset n) {
    for (final a in _c.annotationsForPage(widget.pageIndex).reversed) {
      if (_hitTest(a, n)) {
        _c.deleteAnnotation(widget.pageIndex, a.id);
        break;
      }
    }
  }

  bool _hitTest(Annotation a, Offset n) {
    const tol = 0.02;
    switch (a.type) {
      case AnnotationType.ink:
      case AnnotationType.highlighterFree:
      case AnnotationType.line:
      case AnnotationType.arrow:
        for (final p in a.geometry.points) {
          if ((p - n).distance <= tol) return true;
        }
        return false;
      case AnnotationType.comment:
        final anchor = a.geometry.anchor;
        return anchor != null && (anchor - n).distance <= 0.03;
      default:
        for (final r in a.geometry.rects) {
          if (r.contains(n.dx, n.dy)) return true;
        }
        return false;
    }
  }

  NormalizedRect _rectFrom(Offset a, Offset b) {
    final x = math.min(a.dx, b.dx);
    final y = math.min(a.dy, b.dy);
    return NormalizedRect(
      x: x,
      y: y,
      width: (a.dx - b.dx).abs(),
      height: (a.dy - b.dy).abs(),
    );
  }

  Offset _snapAngle(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    const step = math.pi / 4; // 45°
    final snapped = (angle / step).round() * step;
    final len = math.sqrt(dx * dx + dy * dy);
    return Offset(
      (start.dx + len * math.cos(snapped)).clamp(0.0, 1.0),
      (start.dy + len * math.sin(snapped)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: (e) => _onPointerDown(e, size),
          onPointerMove: (e) => _onPointerMove(e, size),
          onPointerUp: (e) => _onPointerUp(e, size),
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: size,
                    painter: _AnnotationPainter(
                      annotations: _c.annotationsForPage(widget.pageIndex),
                      livePoints: _drawing ? _livePoints : const [],
                      dragStart: _drawing ? _dragStart : null,
                      dragCurrent: _drawing ? _dragCurrent : null,
                      tool: _c.tool,
                      liveColor: _c.colorArgb,
                      liveStroke: _c.strokeWidth,
                      snapStraight: _c.snapStraight,
                    ),
                  ),
                ),
              ),
              // Tappable comment pins (open editor on tap).
              for (final a in _c.annotationsForPage(widget.pageIndex))
                if (a.type == AnnotationType.comment && a.geometry.anchor != null)
                  Positioned(
                    left: a.geometry.anchor!.dx * size.width - 14,
                    top: a.geometry.anchor!.dy * size.height - 28,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => _editExistingComment(a),
                      child: _CommentPin(color: Color(a.style.colorArgb)),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editExistingComment(Annotation a) async {
    final body = await widget.onEditComment(a.text);
    if (body == null) return;
    if (body.trim().isEmpty) {
      _c.deleteAnnotation(widget.pageIndex, a.id);
    } else {
      _c.updateAnnotation(a.copyWith(text: body.trim()));
    }
  }
}

class _CommentPin extends StatelessWidget {
  const _CommentPin({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: const Icon(Icons.chat_bubble, size: 14, color: Colors.white),
    );
  }
}
class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.annotations,
    required this.livePoints,
    required this.dragStart,
    required this.dragCurrent,
    required this.tool,
    required this.liveColor,
    required this.liveStroke,
    required this.snapStraight,
  });

  final List<Annotation> annotations;
  final List<Offset> livePoints;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final AnnotationTool tool;
  final int liveColor;
  final double liveStroke;
  final bool snapStraight;

  Offset _p(Offset n, Size s) => Offset(n.dx * s.width, n.dy * s.height);

  Rect _rect(NormalizedRect r, Size s) => Rect.fromLTWH(
      r.x * s.width, r.y * s.height, r.width * s.width, r.height * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in annotations) {
      _paintAnnotation(canvas, size, a);
    }
    _paintLive(canvas, size);
  }

  void _paintAnnotation(Canvas canvas, Size size, Annotation a) {
    final color = Color(a.style.colorArgb).withValues(alpha: a.style.opacity);
    final strokePx = (a.style.strokeWidth * size.width).clamp(0.5, 64.0);
    switch (a.type) {
      case AnnotationType.ink:
        _paintPolyline(canvas, size, a.geometry.points, color, strokePx, null);
        break;
      case AnnotationType.highlighterFree:
        _paintPolyline(canvas, size, a.geometry.points, color, strokePx * 3.5,
            BlendMode.multiply);
        break;
      case AnnotationType.line:
        if (a.geometry.points.length >= 2) {
          canvas.drawLine(_p(a.geometry.points.first, size),
              _p(a.geometry.points.last, size), _stroke(color, strokePx));
        }
        break;
      case AnnotationType.arrow:
        if (a.geometry.points.length >= 2) {
          _paintArrow(canvas, _p(a.geometry.points.first, size),
              _p(a.geometry.points.last, size), color, strokePx);
        }
        break;
      case AnnotationType.rect:
        for (final r in a.geometry.rects) {
          canvas.drawRect(_rect(r, size),
              a.style.filled ? _fill(color) : _stroke(color, strokePx));
        }
        break;
      case AnnotationType.ellipse:
        for (final r in a.geometry.rects) {
          canvas.drawOval(_rect(r, size),
              a.style.filled ? _fill(color) : _stroke(color, strokePx));
        }
        break;
      case AnnotationType.redaction:
        final solid = Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.fill;
        for (final r in a.geometry.rects) {
          canvas.drawRect(_rect(r, size), solid);
        }
        break;
      case AnnotationType.textHighlight:
        final hl = _fill(color);
        for (final r in a.geometry.rects) {
          canvas.drawRect(_rect(r, size), hl);
        }
        break;
      case AnnotationType.underline:
        for (final r in a.geometry.rects) {
          final rr = _rect(r, size);
          canvas.drawLine(
              rr.bottomLeft, rr.bottomRight, _stroke(color, strokePx));
        }
        break;
      case AnnotationType.strikethrough:
        for (final r in a.geometry.rects) {
          final rr = _rect(r, size);
          canvas.drawLine(Offset(rr.left, rr.center.dy),
              Offset(rr.right, rr.center.dy), _stroke(color, strokePx));
        }
        break;
      case AnnotationType.squiggly:
        for (final r in a.geometry.rects) {
          _paintSquiggly(canvas, _rect(r, size), color, strokePx);
        }
        break;
      case AnnotationType.comment:
        // Rendered as a tappable Positioned pin widget by the overlay.
        break;
    }
  }

  void _paintLive(Canvas canvas, Size size) {
    final color = Color(liveColor)
        .withValues(alpha: tool == AnnotationTool.highlighter ? 0.35 : 1.0);
    final strokePx = (liveStroke * size.width).clamp(0.5, 64.0);
    switch (tool) {
      case AnnotationTool.ink:
        _paintPolyline(canvas, size, livePoints, color, strokePx, null);
        break;
      case AnnotationTool.highlighter:
        _paintPolyline(canvas, size, livePoints, color, strokePx * 3.5,
            BlendMode.multiply);
        break;
      case AnnotationTool.line:
      case AnnotationTool.arrow:
        if (dragStart != null && dragCurrent != null) {
          final end = snapStraight
              ? _snapPreview(dragStart!, dragCurrent!)
              : dragCurrent!;
          if (tool == AnnotationTool.arrow) {
            _paintArrow(canvas, _p(dragStart!, size), _p(end, size),
                Color(liveColor), strokePx);
          } else {
            canvas.drawLine(_p(dragStart!, size), _p(end, size),
                _stroke(Color(liveColor), strokePx));
          }
        }
        break;
      case AnnotationTool.rect:
      case AnnotationTool.redaction:
        if (dragStart != null && dragCurrent != null) {
          canvas.drawRect(
              Rect.fromPoints(_p(dragStart!, size), _p(dragCurrent!, size)),
              _stroke(Color(liveColor), strokePx));
        }
        break;
      case AnnotationTool.ellipse:
        if (dragStart != null && dragCurrent != null) {
          canvas.drawOval(
              Rect.fromPoints(_p(dragStart!, size), _p(dragCurrent!, size)),
              _stroke(Color(liveColor), strokePx));
        }
        break;
      case AnnotationTool.textHighlight:
      case AnnotationTool.underline:
      case AnnotationTool.strikethrough:
      case AnnotationTool.squiggly:
      case AnnotationTool.select:
        if (dragStart != null && dragCurrent != null) {
          canvas.drawRect(
              Rect.fromPoints(_p(dragStart!, size), _p(dragCurrent!, size)),
              Paint()
                ..color = const Color(0x334285F4)
                ..style = PaintingStyle.fill);
        }
        break;
      case AnnotationTool.eraser:
      case AnnotationTool.comment:
      case AnnotationTool.navigate:
        break;
    }
  }

  Offset _snapPreview(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    const step = math.pi / 4;
    final snapped = (angle / step).round() * step;
    final len = math.sqrt(dx * dx + dy * dy);
    return Offset(
        start.dx + len * math.cos(snapped), start.dy + len * math.sin(snapped));
  }

  void _paintPolyline(Canvas canvas, Size size, List<Offset> pts, Color color,
      double strokePx, BlendMode? blend) {
    if (pts.length < 2) {
      if (pts.length == 1) {
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        if (blend != null) paint.blendMode = blend;
        canvas.drawCircle(_p(pts.first, size), strokePx / 2, paint);
      }
      return;
    }
    final first = _p(pts.first, size);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < pts.length; i++) {
      final o = _p(pts[i], size);
      path.lineTo(o.dx, o.dy);
    }
    final paint = _stroke(color, strokePx);
    if (blend != null) paint.blendMode = blend;
    canvas.drawPath(path, paint);
  }

  void _paintArrow(
      Canvas canvas, Offset a, Offset b, Color color, double strokePx) {
    final paint = _stroke(color, strokePx);
    canvas.drawLine(a, b, paint);
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    final headLen = math.max(strokePx * 3.5, 8.0);
    const spread = math.pi / 7;
    canvas.drawLine(
        b,
        Offset(b.dx - headLen * math.cos(angle - spread),
            b.dy - headLen * math.sin(angle - spread)),
        paint);
    canvas.drawLine(
        b,
        Offset(b.dx - headLen * math.cos(angle + spread),
            b.dy - headLen * math.sin(angle + spread)),
        paint);
  }

  void _paintSquiggly(Canvas canvas, Rect r, Color color, double strokePx) {
    final path = Path();
    final y = r.bottom;
    final amp = math.max(strokePx, 2.0);
    final wave = amp * 2;
    path.moveTo(r.left, y);
    var x = r.left;
    var up = true;
    while (x < r.right) {
      final nx = math.min(x + wave, r.right);
      path.quadraticBezierTo((x + nx) / 2, up ? y - amp : y + amp, nx, y);
      x = nx;
      up = !up;
    }
    canvas.drawPath(path, _stroke(color, strokePx));
  }

  Paint _stroke(Color color, double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  bool shouldRepaint(covariant _AnnotationPainter old) => true;
}

