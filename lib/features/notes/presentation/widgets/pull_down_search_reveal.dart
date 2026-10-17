import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Builder for rendering an in-place search view behind the sliding content.
typedef SearchViewBuilder = Widget Function(
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
/// purely by scroll notifications and only ever engages when the gesture
/// *begins* from a resting position at the very top of the content:
///
///   1. **Arm** — on [ScrollStartNotification], the pull arms only if the
///      scrollable is already at the top (`pixels <= 0`) *and* the scroll is
///      user-initiated (`dragDetails != null`). A drag that starts mid-list and
///      scrolls up into the top boundary never arms; a ballistic fling-bounce
///      never arms. You must lift and touch again from rest at the top.
///   2. **Pull** — while armed, user-driven overscroll translates the content
///      downward with rubber-band resistance, revealing the search view resting
///      directly behind it.
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
    with TickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _springAnimation;

  late final AnimationController _slideController;

  double _pullOffset = 0.0;
  double _slideBeginOffset = 0.0;

  /// Whether the *current* drag gesture is allowed to pull. Set on
  /// [ScrollStartNotification] and cleared when the gesture ends.
  bool _armed = false;
  bool _hasTriggeredHaptic = false;

  /// Guards against committing twice for a single gesture.
  bool _committed = false;

  /// Whether in-place search is currently active.
  bool _isSearchActive = false;

  bool get isSearchActive => _isSearchActive;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated?.call(this);
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _pullOffset = _springAnimation.value;
        });
      });

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void didUpdateWidget(PullDownSearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onStateCreated?.call(this);
  }

  @override
  void dispose() {
    _springController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Programmatically opens search with the smooth slide unveil.
  void openSearch() {
    if (_isSearchActive) return;
    if (_slideController.isAnimating) return;

    if (widget.searchViewBuilder == null) {
      widget.onOpenSearch();
      return;
    }

    setState(() {
      _isSearchActive = true;
      _committed = true;
      _slideBeginOffset = 0.0;
    });

    _slideController.forward(from: 0.0);
    widget.onOpenSearch();
  }

  /// Programmatically closes in-place search, smoothly sliding the content back up.
  void closeSearch() {
    if (!_isSearchActive && !_committed) return;
    if (_slideController.isAnimating) return;

    if (widget.searchViewBuilder == null) {
      setState(() {
        _isSearchActive = false;
        _committed = false;
        _pullOffset = 0.0;
      });
      return;
    }

    _slideBeginOffset = 0.0;
    _slideController.reverse(from: 1.0).then((_) {
      if (mounted) {
        setState(() {
          _isSearchActive = false;
          _committed = false;
          _pullOffset = 0.0;
        });
      }
    });
  }

  void _onPullDelta(double rawDeltaY) {
    if (_springController.isAnimating) {
      _springController.stop();
    }

    setState(() {
      final double progress =
          (_pullOffset / widget.effectiveMaxPullOffset).clamp(0.0, 1.0);
      final double resistance = 0.85 * (1.0 - (progress * 0.5));
      _pullOffset = math.max(
        0.0,
        math.min(
          widget.effectiveMaxPullOffset,
          _pullOffset + (rawDeltaY * resistance),
        ),
      );

      if (_pullOffset >= widget.effectiveThreshold && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (_pullOffset < widget.effectiveThreshold &&
          _hasTriggeredHaptic) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onPullEnd() {
    _armed = false;
    if (_pullOffset == 0.0 || _committed) return;

    final bool shouldCommit = _pullOffset >= widget.effectiveThreshold;

    if (shouldCommit) {
      _committed = true;
      _hasTriggeredHaptic = false;

      if (widget.searchViewBuilder != null) {
        // In-place unveil: continue sliding content smoothly down off-screen!
        _slideBeginOffset = _pullOffset;
        setState(() {
          _isSearchActive = true;
        });
        _slideController.forward(from: 0.0);
        widget.onOpenSearch();
      } else {
        // Fallback mode without searchViewBuilder (e.g. editor find-in-note):
        _springAnimation = Tween<double>(begin: _pullOffset, end: 0.0).animate(
          CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
        );
        _springController.forward(from: 0.0);
        widget.onOpenSearch();
      }
    } else {
      // Aborted before threshold: spring back to 0.0
      _springAnimation = Tween<double>(begin: _pullOffset, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
      );
      _springController.forward(from: 0.0);
      _hasTriggeredHaptic = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isSearchActive || !widget.enabled) {
      return false;
    }

    // Ignore horizontal scrollables (e.g. the tags filter bar).
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      // Phase 1 — arm only when starting from rest at the very top under a
      // real finger. Ballistic flings or mid-list drags never arm.
      _armed = notification.metrics.pixels <= 0 &&
          notification.dragDetails != null;
      _committed = false;
    } else if (notification is ScrollUpdateNotification) {
      // Phase 2 — accumulate finger delta while armed at the top boundary.
      if (_armed &&
          notification.dragDetails != null &&
          notification.metrics.pixels <= 0) {
        final double delta = notification.dragDetails!.delta.dy;
        if (delta > 0) {
          _onPullDelta(delta);
        }
      }
    } else if (notification is OverscrollNotification) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        double translation;
        if (_slideController.isAnimating) {
          translation = lerpDouble(
            _slideBeginOffset,
            viewportHeight,
            Curves.easeOutCubic.transform(_slideController.value),
          )!;
        } else if (_isSearchActive) {
          translation = viewportHeight;
        } else if (_springController.isAnimating) {
          translation = _springAnimation.value;
        } else {
          translation = _pullOffset;
        }

        final bool showSearchView = widget.searchViewBuilder != null &&
            (_pullOffset > 0.0 || _isSearchActive || _slideController.isAnimating);

        if (widget.searchViewBuilder != null) {
          return NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (showSearchView)
                  Positioned.fill(
                    child: widget.searchViewBuilder!(
                      context,
                      _pullOffset >= widget.effectiveThreshold,
                      closeSearch,
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0.0, translation),
                  child: Offstage(
                    offstage: _isSearchActive && !_slideController.isAnimating,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          );
        }

        // Fallback mode without searchViewBuilder (e.g. editor find-in-note).
        final colors = context.appColors;
        final double revealRatio =
            (_pullOffset / widget.effectiveThreshold).clamp(0.0, 1.0);
        final bool past = _pullOffset >= widget.effectiveThreshold;

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Stack(
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
