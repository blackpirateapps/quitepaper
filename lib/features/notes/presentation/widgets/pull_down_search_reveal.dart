import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Builder for rendering an in-place search view behind the sliding content.
typedef SearchViewBuilder =
    Widget Function(
      BuildContext context,
      bool isPastThreshold,
      VoidCallback onClose,
    );

/// A wrapper widget that provides a deliberate, Bear Notes-inspired pull-down
/// gesture to reveal and trigger a Search interface.
///
/// ## Why this is a *two-phase* gesture
///
/// Earlier revisions fired on any small overscroll (and, on the notes list, via
/// a raw [GestureDetector] that competed with the scroll view and the drawer
/// edge-drag). Both triggered constantly by accident. This version is driven
/// by scroll notifications, with pointer release/cancel ending the pull, and
/// only engages when the gesture *begins* from a resting position at the very
/// top of the content:
///
///   1. **Arm** — on [ScrollStartNotification], the pull arms only if the
///      scrollable is already at the top (`pixels <= 0`) *and* the scroll is
///      user-initiated (`dragDetails != null`). A drag that starts mid-list and
///      scrolls up into the top boundary never arms; a ballistic fling-bounce
///      never arms. You must lift and touch again from rest at the top.
///   2. **Pull** — while armed, user-driven overscroll translates the content
///      downward (1:1 for the search view, resisted for the compact bar), revealing
///      the search view resting directly behind it.
///   3. **Commit** — on release, crossing [effectiveThreshold] smoothly slides
///      the content away, fully unveiling search in-place with zero lag.
///      If released before threshold, content smoothly springs back.
class PullDownSearchReveal extends StatefulWidget {
  const PullDownSearchReveal({
    super.key,
    required this.child,
    required this.onOpenSearch,
    this.searchViewBuilder,
    this.onStateCreated,
    this.threshold,
    this.maxPullOffset,
    this.isTabletPane = false,
    this.enabled = true,
    this.hintText,
  });

  final Widget child;
  final VoidCallback onOpenSearch;

  /// Optional in-place search view builder rendered directly behind the content.
  /// When provided, pulling down unveils this view in-place, and committing
  /// smoothly slides the content away with zero route-push delay.
  final SearchViewBuilder? searchViewBuilder;

  /// Optional callback invoked when the state is created or updated.
  final void Function(PullDownSearchRevealState state)? onStateCreated;

  /// Pull distance (in logical pixels of revealed offset) that must be exceeded
  /// at release for the gesture to commit.
  final double? threshold;

  /// Maximum revealed offset; the rubber-band asymptotes toward this value.
  final double? maxPullOffset;

  final bool isTabletPane;

  /// Enables the pull gesture. Toolbar and keyboard actions can still open
  /// search when the gesture is disabled.
  final bool enabled;

  /// Overrides the placeholder shown in the fallback revealed search bar.
  final String? hintText;

  double get effectiveThreshold =>
      threshold ?? (searchViewBuilder != null ? 120.0 : 96.0);

  double get effectiveMaxPullOffset =>
      maxPullOffset ?? (searchViewBuilder != null ? 180.0 : 150.0);

  @override
  State<PullDownSearchReveal> createState() => PullDownSearchRevealState();
}

class PullDownSearchRevealState extends State<PullDownSearchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;
  _RevealPhase _phase = _RevealPhase.idle;
  double _pullOffset = 0;
  double _viewportHeight = 800;
  bool _armed = false;
  bool _hasTriggeredHaptic = false;
  bool _committed = false;
  int? _pointer;

  bool get isSearchActive =>
      _phase == _RevealPhase.opening ||
      _phase == _RevealPhase.open ||
      _phase == _RevealPhase.closing;

  /// Focus only after the sliding card has left the screen. Opening the mobile
  /// keyboard during the slide changes its destination height mid-animation.
  bool get isSearchReady => _phase == _RevealPhase.open;
  double get pullOffset => _pullOffset;
  double get _translation => isSearchReady ? _viewportHeight : _pullOffset;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 240),
          )
          ..addListener(() {
            setState(() => _pullOffset = _animation!.value);
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            setState(() {
              if (_phase == _RevealPhase.opening) {
                _phase = _RevealPhase.open;
              } else {
                _phase = _RevealPhase.idle;
                _pullOffset = 0;
                _committed = false;
              }
            });
          });
    widget.onStateCreated?.call(this);
  }

  @override
  void didUpdateWidget(PullDownSearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onStateCreated?.call(this);
    if (oldWidget.enabled && !widget.enabled && !isSearchActive) {
      _armed = false;
      if (_pullOffset > 0) _settle();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, _RevealPhase phase) {
    final begin = _translation;
    _controller.stop();
    _animation = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurveTween(curve: Curves.easeOutCubic).animate(_controller));
    setState(() {
      _pullOffset = begin;
      _phase = phase;
    });
    _controller.forward(from: 0);
  }

  void _settle() {
    _hasTriggeredHaptic = false;
    _animateTo(0, _RevealPhase.settling);
  }

  /// Opens from the current card position, including an interrupted spring-back.
  void openSearch({bool animate = true}) {
    if (isSearchActive && _phase != _RevealPhase.closing) return;
    _armed = false;
    if (widget.searchViewBuilder == null) {
      widget.onOpenSearch();
      return;
    }
    _committed = true;
    if (animate) {
      _animateTo(_viewportHeight, _RevealPhase.opening);
    } else {
      _controller.stop();
      setState(() {
        _phase = _RevealPhase.open;
        _pullOffset = _viewportHeight;
      });
    }
    widget.onOpenSearch();
  }

  /// Back can reverse an opening slide immediately without jumping position.
  void closeSearch() {
    if (!isSearchActive || _phase == _RevealPhase.closing) return;
    FocusScope.of(context).unfocus();
    _armed = false;
    _animateTo(0, _RevealPhase.closing);
  }

  void _onPullDelta(double rawDeltaY) {
    _controller.stop();
    _phase = _RevealPhase.pulling;

    setState(() {
      if (widget.searchViewBuilder != null) {
        // Direct 1:1 sliding card mechanics (like sliding a card out from a deck)
        final double maxOffset = widget.maxPullOffset ?? _viewportHeight;
        _pullOffset = math.max(
          0.0,
          math.min(maxOffset, _pullOffset + rawDeltaY),
        );
      } else {
        // Fallback rubber-band mode for single search bar reveal (e.g. editor find-in-note)
        final double progress = (_pullOffset / widget.effectiveMaxPullOffset)
            .clamp(0.0, 1.0);
        final double resistance = rawDeltaY > 0
            ? 0.85 * (1.0 - (progress * 0.5))
            : 1.0;
        _pullOffset = math.max(
          0.0,
          math.min(
            widget.effectiveMaxPullOffset,
            _pullOffset + (rawDeltaY * resistance),
          ),
        );
      }

      if (_pullOffset >= widget.effectiveThreshold && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (_pullOffset < widget.effectiveThreshold &&
          _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onPullEnd({bool canceled = false}) {
    if (!_armed) return;
    _armed = false;
    if (_pullOffset == 0 || _committed) return;

    if (!canceled && _pullOffset >= widget.effectiveThreshold) {
      _hasTriggeredHaptic = false;
      if (widget.searchViewBuilder != null) {
        openSearch();
      } else {
        _committed = true;
        _settle();
        widget.onOpenSearch();
      }
    } else {
      _settle();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (isSearchActive || !widget.enabled) {
      return false;
    }

    // Ignore horizontal scrollables (e.g. the tags filter bar).
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      // Phase 1 — arm only when starting from rest at the very top under a
      // real finger. Ballistic flings or mid-list drags never arm.
      _armed =
          notification.metrics.pixels <= notification.metrics.minScrollExtent &&
          notification.dragDetails != null;
      if (_armed) {
        _controller.stop();
        _committed = false;
        _hasTriggeredHaptic = false;
      }
    } else if (notification is ScrollUpdateNotification) {
      // Phase 2 — accumulate finger delta while armed at the top boundary.
      if (_armed && notification.dragDetails != null) {
        final double delta = notification.dragDetails!.delta.dy;
        // If the inner list is scrolled down into items and no card pull is active, disarm.
        if (notification.metrics.pixels >
                notification.metrics.minScrollExtent &&
            _pullOffset == 0.0) {
          _armed = false;
        } else if (_pullOffset > 0.0 ||
            (notification.metrics.pixels <=
                    notification.metrics.minScrollExtent &&
                delta > 0)) {
          _onPullDelta(delta);
        }
      }
    } else if (notification is OverscrollNotification) {
      if (_armed && notification.dragDetails != null) {
        final double delta = notification.dragDetails!.delta.dy;
        if (_pullOffset > 0.0 || (notification.overscroll < 0 && delta > 0)) {
          _onPullDelta(delta);
        }
      }
    } else if (notification is ScrollEndNotification) {
      _onPullEnd();
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      if (_pullOffset > 0.0 || _armed) {
        _onPullEnd();
      }
    }
    return false;
  }

  Widget _trackPull(Widget child) => Listener(
    onPointerDown: (event) => _pointer ??= event.pointer,
    onPointerUp: (event) {
      if (_pointer != event.pointer) return;
      _pointer = null;
      _onPullEnd();
    },
    onPointerCancel: (event) {
      if (_pointer != event.pointer) return;
      _pointer = null;
      _onPullEnd(canceled: true);
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled && widget.searchViewBuilder == null) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        _viewportHeight = viewportHeight;

        final translation = _translation;
        final showSearchView =
            widget.searchViewBuilder != null &&
            (_pullOffset > 0 || isSearchActive);

        if (widget.searchViewBuilder != null) {
          return _trackPull(
            PopScope(
              canPop: !isSearchActive,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && isSearchActive) closeSearch();
              },
              child: Stack(
                // Keep the pane sized when its only non-positioned child goes
                // offstage. AnimatedSwitcher's desktop constraints are loose.
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  if (showSearchView)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !isSearchActive,
                        child: widget.searchViewBuilder!(
                          context,
                          !isSearchActive &&
                              _pullOffset >= widget.effectiveThreshold,
                          closeSearch,
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0.0, translation),
                    child: Offstage(
                      offstage: isSearchReady,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Fallback mode without searchViewBuilder (e.g. editor find-in-note).
        final colors = context.appColors;
        final double revealRatio = (_pullOffset / widget.effectiveThreshold)
            .clamp(0.0, 1.0);
        final bool past = _pullOffset >= widget.effectiveThreshold;

        return _trackPull(
          Stack(
            clipBehavior: Clip.hardEdge,
            children: [
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0.0, _pullOffset),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _RevealPhase { idle, pulling, settling, opening, open, closing }

/// Keeps the list at its top while the reveal owns a pull. Outside that gesture
/// the parent retains the platform's normal scrolling and bounce behavior.
class PullDownSearchScrollPhysics extends ScrollPhysics {
  const PullDownSearchScrollPhysics({required this.revealState, super.parent});

  final PullDownSearchRevealState? Function() revealState;

  @override
  PullDownSearchScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      PullDownSearchScrollPhysics(
        revealState: revealState,
        parent: buildParent(ancestor),
      );

  bool get _ownsPull {
    final state = revealState();
    return state != null &&
        state.widget.enabled &&
        (state._armed || state._pullOffset > 0 || state.isSearchActive);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (_ownsPull && position.pixels <= position.minScrollExtent) return offset;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (_ownsPull &&
        position.pixels == position.minScrollExtent &&
        (value < position.minScrollExtent ||
            (revealState()?.pullOffset ?? 0) > 0)) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (_ownsPull &&
        position.pixels == position.minScrollExtent &&
        (revealState()?.pullOffset ?? 0) > 0) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
