import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

class OnboardingCoachMarks extends StatefulWidget {
  const OnboardingCoachMarks({
    super.key,
    required this.sidebarTarget,
    required this.searchTarget,
    required this.createTarget,
    required this.isTablet,
    required this.onCreateFirstNote,
    required this.onDismiss,
  });

  final GlobalKey sidebarTarget;
  final GlobalKey searchTarget;
  final GlobalKey createTarget;
  final bool isTablet;
  final VoidCallback onCreateFirstNote;
  final VoidCallback onDismiss;

  @override
  State<OnboardingCoachMarks> createState() => _OnboardingCoachMarksState();
}

class _OnboardingCoachMarksState extends State<OnboardingCoachMarks>
    with WidgetsBindingObserver {
  int _currentStep = 0; // 0: sidebar, 1: search, 2: create

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) setState(() {});
  }

  GlobalKey get _currentTargetKey {
    switch (_currentStep) {
      case 0:
        return widget.sidebarTarget;
      case 1:
        return widget.searchTarget;
      case 2:
      default:
        return widget.createTarget;
    }
  }

  Rect? _getTargetRect() {
    final context = _currentTargetKey.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) return null;
    final size = renderBox.size;
    if (size.width <= 0 || size.height <= 0) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & size;
  }

  void _handleNext() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final targetRect = _getTargetRect();
    final padding = MediaQuery.paddingOf(context);

    String stepIndicator;
    String eyebrow;
    String title;
    String body;
    String buttonLabel;
    Key buttonKey;
    VoidCallback onButtonPressed;

    switch (_currentStep) {
      case 0:
        stepIndicator = '1 of 3';
        eyebrow = 'YOUR LIBRARY';
        title = 'Everything, in one place.';
        body =
            'All notes, pinned, archive, and tags live here. One list. No filing system required.';
        buttonLabel = 'Next';
        buttonKey = const Key('onboarding-coach-next');
        onButtonPressed = _handleNext;
        break;
      case 1:
        stepIndicator = '2 of 3';
        eyebrow = 'FIND ANYTHING';
        title = 'Find it in a blink.';
        body =
            'Search titles, text, and tags—fully offline. Even the words inside your scans.';
        buttonLabel = 'Next';
        buttonKey = const Key('onboarding-coach-next');
        onButtonPressed = _handleNext;
        break;
      case 2:
      default:
        stepIndicator = '3 of 3';
        eyebrow = 'THE FRONT DOOR';
        title = 'This is where notes begin.';
        body =
            'Tap it whenever a thought arrives—or let us make the first one for you.';
        buttonLabel = 'Create my first note';
        buttonKey = const Key('onboarding-coach-create');
        onButtonPressed = widget.onCreateFirstNote;
        break;
    }

    return Stack(
      children: [
        // 1. Gesture barrier to block underlying taps
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
          ),
        ),

        // 2. Dim layer with cutout and accent border
        Positioned.fill(
          child: CustomPaint(
            painter: _CoachDimPainter(
              targetRect: targetRect,
              accentColor: colors.accent,
            ),
          ),
        ),

        // 3. Coach card positioned near target
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _CoachCardLayoutDelegate(
              targetRect: targetRect,
              padding: padding,
            ),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: "X of 3" and "Skip tour"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stepIndicator,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textTertiary,
                          ),
                        ),
                        TextButton(
                          key: const Key('onboarding-coach-skip'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: colors.textSecondary,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: widget.onDismiss,
                          child: const Text('Skip tour'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Eyebrow
                    Text(
                      eyebrow,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Body
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Primary action button
                    QuietButton(
                      key: buttonKey,
                      label: buttonLabel,
                      variant: QuietButtonVariant.primary,
                      isFullWidth: true,
                      onPressed: onButtonPressed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachCardLayoutDelegate extends SingleChildLayoutDelegate {
  _CoachCardLayoutDelegate({
    required this.targetRect,
    required this.padding,
  });

  final Rect? targetRect;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = math.min(360.0, constraints.maxWidth - 32.0);
    return BoxConstraints(
      maxWidth: maxW,
      minWidth: math.min(280.0, maxW),
      maxHeight: constraints.maxHeight - padding.top - padding.bottom,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final screenW = size.width;
    final screenH = size.height;
    final topSafe = padding.top + 16.0;
    final bottomSafe = screenH - padding.bottom - 16.0;

    if (targetRect == null) {
      final x = (screenW - childSize.width) / 2;
      final y = (screenH - childSize.height) / 2;
      return Offset(x, y);
    }

    final target = targetRect!;
    double x;
    double y;

    final belowY = target.bottom + 16.0;
    final aboveY = target.top - childSize.height - 16.0;

    if (belowY + childSize.height <= bottomSafe) {
      y = belowY;
      x = target.center.dx - (childSize.width / 2);
    } else if (aboveY >= topSafe) {
      y = aboveY;
      x = target.center.dx - (childSize.width / 2);
    } else {
      final rightX = target.right + 16.0;
      final leftX = target.left - childSize.width - 16.0;
      if (rightX + childSize.width <= screenW - 16.0) {
        x = rightX;
        y = target.center.dy - (childSize.height / 2);
      } else if (leftX >= 16.0) {
        x = leftX;
        y = target.center.dy - (childSize.height / 2);
      } else {
        x = (screenW - childSize.width) / 2;
        y = (screenH - childSize.height) / 2;
      }
    }

    x = x.clamp(16.0, math.max(16.0, screenW - childSize.width - 16.0));
    y = y.clamp(topSafe, math.max(topSafe, bottomSafe - childSize.height));

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _CoachCardLayoutDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.padding != padding;
  }
}

class _CoachDimPainter extends CustomPainter {
  const _CoachDimPainter({
    required this.targetRect,
    required this.accentColor,
  });

  final Rect? targetRect;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, dimPaint);
      return;
    }

    final cutoutRect = targetRect!.inflate(8);
    final rrect =
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12));

    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()..addRRect(rrect);
    final combined =
        Path.combine(PathOperation.difference, fullPath, cutoutPath);

    canvas.drawPath(combined, dimPaint);

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachDimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.accentColor != accentColor;
  }
}
