import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// A wrapper widget that provides a deliberate, Bear Notes-inspired pull-down
/// gesture to reveal and trigger a Search interface.
///
/// ## Why this is a *two-phase* gesture
///
/// Earlier revisions fired on any small overscroll (and, on the notes list, via
/// a raw [GestureDetector] that competed with the scroll view and the drawer
/// edge-drag). Both triggered constantly by accident. This version is driven
/// purely by scroll notifications and only ever engages when the gesture
/// *begins* from a resting position at the very top of the content:
///
///   1. **Arm** — on [ScrollStartNotification], the pull arms only if the
///      scrollable is already at the top (`pixels <= 0`) *and* the scroll is
///      user-initiated (`dragDetails != null`). A drag that starts mid-list and
///      scrolls up into the top boundary never arms; a ballistic fling-bounce
///      never arms. You must lift and touch again from rest at the top.
///   2. **Pull** — while armed, user-driven overscroll translates the content
///      downward with rubber-band resistance, revealing the search bar.
///   3. **Commit** — on release, crossing [threshold] navigates; otherwise the
///      content springs back.
class PullDownSearchReveal extends StatefulWidget {
  const PullDownSearchReveal({
    super.key,
    required this.child,
    required this.onOpenSearch,
    this.threshold = 96.0,
    this.maxPullOffset = 150.0,
    this.isTabletPane = false,
    this.enabled = true,
    this.hintText,
  });

  final Widget child;
  final VoidCallback onOpenSearch;

  /// Pull distance (in logical pixels of revealed offset) that must be exceeded
  /// at release for the gesture to commit.
  final double threshold;

  /// Maximum revealed offset; the rubber-band asymptotes toward this value.
  final double maxPullOffset;

  final bool isTabletPane;
  final bool enabled;

  /// Overrides the placeholder shown in the revealed search bar. Defaults to a
  /// notes-list oriented hint.
  final String? hintText;

  @override
  State<PullDownSearchReveal> createState() => _PullDownSearchRevealState();
}

class _PullDownSearchRevealState extends State<PullDownSearchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _springAnimation;

  double _pullOffset = 0.0;

  /// Whether the *current* drag gesture is allowed to pull. Set on
  /// [ScrollStartNotification] and cleared when the gesture ends. This is the
  /// core guard against accidental triggering.
  bool _armed = false;
  bool _hasTriggeredHaptic = false;

  /// Guards against committing twice for a single gesture: a finger lift can
  /// surface as a [UserScrollNotification] (idle) and then, after the bounce
  /// settles, a [ScrollEndNotification].
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        setState(() {
          _pullOffset = _springAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPullDelta(double rawDeltaY) {
    if (_springController.isAnimating) {
      _springController.stop();
    }

    setState(() {
      // Rubber-band: resistance grows as the pull approaches [maxPullOffset],
      // so the final stretch toward the threshold takes deliberate effort.
      final double progress =
          (_pullOffset / widget.maxPullOffset).clamp(0.0, 1.0);
      final double resistance = 0.85 * (1.0 - (progress * 0.5));
      _pullOffset = math.max(
        0.0,
        math.min(widget.maxPullOffset, _pullOffset + (rawDeltaY * resistance)),
      );

      if (_pullOffset >= widget.threshold && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (_pullOffset < widget.threshold && _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onPullEnd() {
    _armed = false;
    if (_pullOffset == 0.0 || _committed) return;

    final bool shouldCommit = _pullOffset >= widget.threshold;

    _springAnimation = Tween<double>(begin: _pullOffset, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    _springController.forward(from: 0.0);
    _hasTriggeredHaptic = false;

    if (shouldCommit) {
      _committed = true;
      widget.onOpenSearch();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Ignore horizontal scrollables (e.g. the tags filter bar).
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      // Phase 1 — arm only when starting from rest at the very top under a
      // real finger. A drag that begins mid-list, or any ballistic motion,
      // leaves us disarmed for the whole gesture.
      _armed = notification.metrics.pixels <= 0 &&
          notification.dragDetails != null;
      _committed = false;
    } else if (notification is ScrollUpdateNotification) {
      // Bouncing physics lets the position travel past the top edge, so the
      // pull surfaces as negative pixels on a user-driven update. Track the
      // raw finger delta and ignore ballistic spring-back (dragDetails null).
      if (_armed &&
          notification.dragDetails != null &&
          notification.metrics.pixels <= 0) {
        final double delta = notification.dragDetails!.delta.dy;
        if (delta > 0) {
          _onPullDelta(delta);
        }
      }
    } else if (notification is OverscrollNotification) {
      // Clamping physics instead reports the unabsorbed overscroll; same intent.
      if (_armed &&
          notification.dragDetails != null &&
          notification.overscroll < 0) {
        final double delta = notification.dragDetails!.delta.dy;
        if (delta > 0) {
          _onPullDelta(delta);
        }
      }
    } else if (notification is ScrollEndNotification) {
      _onPullEnd();
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      // Finger lifted without a settling animation — resolve any accumulated
      // pull.
      if (_pullOffset > 0.0 || _armed) {
        _onPullEnd();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final colors = context.appColors;
    final double revealRatio = (_pullOffset / widget.threshold).clamp(0.0, 1.0);
    final bool past = _pullOffset >= widget.threshold;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Revealed search header (sits behind the content, exposed as it
          // slides down).
          if (_pullOffset > 0.0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: revealRatio,
                    child: Transform.scale(
                      scale: 0.90 + (0.10 * revealRatio),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: AppRadii.borderMd,
                          border: Border.all(
                            color: past
                                ? colors.accent.withValues(alpha: 0.5)
                                : colors.divider,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.divider.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: past
                                  ? colors.accent
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.hintText ??
                                    (widget.isTabletPane
                                        ? 'Search notes...'
                                        : 'Search notes, documents, OCR, tags...'),
                                style: AppTypography.headline.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (past)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Release',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Translating content.
          Transform.translate(
            offset: Offset(0.0, _pullOffset),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
