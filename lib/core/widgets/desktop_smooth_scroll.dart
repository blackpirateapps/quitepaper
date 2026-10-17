import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/platform_layout_helper.dart';

/// Kinetic smooth mouse-wheel scrolling wrapper for desktop platforms (Linux, macOS, Windows).
///
/// On desktop environments, Flutter's default engine dispatches discrete, rigid
/// [PointerScrollEvent] jumps per mouse wheel notch. This widget intercepts
/// pointer scroll events and smoothly glides to the target offset using an
/// eased deceleration curve with momentum accumulation.
///
/// On mobile/touch platforms (Android, iOS), pointer scroll events pass through
/// untouched to preserve standard native touch and fling behaviors.
class DesktopSmoothScroll extends StatefulWidget {
  const DesktopSmoothScroll({
    super.key,
    required this.child,
    this.controller,
    this.scrollSpeedMultiplier = 1.6,
    this.animationDuration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.axis = Axis.vertical,
  });

  /// The scrollable widget to wrap.
  final Widget child;

  /// The [ScrollController] attached to the scrollable child.
  /// If null, [PrimaryScrollController] will be resolved from context.
  final ScrollController? controller;

  /// Multiplier applied to mouse scroll delta to match physical wheel feel.
  final double scrollSpeedMultiplier;

  /// Animation duration for deceleration to the target offset.
  final Duration animationDuration;

  /// Easing deceleration curve for the smooth scroll glide.
  final Curve curve;

  /// Primary scroll axis.
  final Axis axis;

  @override
  State<DesktopSmoothScroll> createState() => _DesktopSmoothScrollState();
}

class _DesktopSmoothScrollState extends State<DesktopSmoothScroll> {
  double _targetOffset = 0.0;
  Timer? _cooldownTimer;
  bool _isAnimating = false;

  ScrollController? _getEffectiveController(BuildContext context) {
    return widget.controller ?? PrimaryScrollController.maybeOf(context);
  }

  void _handlePointerSignal(PointerSignalEvent event, BuildContext context) {
    if (event is! PointerScrollEvent) return;
    if (!PlatformLayoutHelper.isDesktopPlatform) return;

    final controller = _getEffectiveController(context);
    if (controller == null || !controller.hasClients) return;

    final position = controller.position;
    final delta = widget.axis == Axis.vertical
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;

    if (delta == 0) return;

    // If idle or out of sync, start from the current scroll position
    if (!_isAnimating) {
      _targetOffset = position.pixels;
    }

    _isAnimating = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(widget.animationDuration + const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });

    // Accumulate target offset with multiplier
    _targetOffset += delta * widget.scrollSpeedMultiplier;

    // Clamp within valid scroll boundaries
    final minExtent = position.minScrollExtent;
    final maxExtent = position.maxScrollExtent;
    _targetOffset = _targetOffset.clamp(minExtent, maxExtent);

    // Smoothly glide to the target offset
    controller.animateTo(
      _targetOffset,
      duration: widget.animationDuration,
      curve: widget.curve,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformLayoutHelper.isDesktopPlatform) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) => _handlePointerSignal(event, context),
      child: widget.child,
    );
  }
}
