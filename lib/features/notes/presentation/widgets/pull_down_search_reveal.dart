import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// A wrapper widget that provides a Bear Notes-inspired pull-down gesture to reveal
/// and trigger the Search interface.
///
/// Swiping down at the top of scrollable content translates the entire child
/// downward with elastic rubber-banding, revealing an editorial search preview
/// bar from above. When pulled past [threshold], haptic feedback triggers and
/// releasing navigates seamlessly to search.
class PullDownSearchReveal extends StatefulWidget {
  const PullDownSearchReveal({
    super.key,
    required this.child,
    required this.onOpenSearch,
    this.threshold = 70.0,
    this.maxPullOffset = 130.0,
    this.isTabletPane = false,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onOpenSearch;
  final double threshold;
  final double maxPullOffset;
  final bool isTabletPane;
  final bool enabled;

  @override
  State<PullDownSearchReveal> createState() => _PullDownSearchRevealState();
}

class _PullDownSearchRevealState extends State<PullDownSearchReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _springAnimation;

  double _pullOffset = 0.0;
  bool _isDragging = false;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
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

  void _onPullDelta(double deltaY) {
    if (_springController.isAnimating) {
      _springController.stop();
    }

    _isDragging = true;
    setState(() {
      // Elastic rubber-band resistance curve
      final double progress = (_pullOffset / widget.maxPullOffset).clamp(0.0, 1.0);
      final double resistance = 0.55 * (1.0 - (progress * 0.45));
      _pullOffset = math.max(
        0.0,
        math.min(widget.maxPullOffset, _pullOffset + (deltaY * resistance)),
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
    if (!_isDragging && _pullOffset == 0.0) return;
    _isDragging = false;

    if (_pullOffset >= widget.threshold) {
      _springAnimation = Tween<double>(
        begin: _pullOffset,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _springController,
          curve: Curves.easeOutCubic,
        ),
      );
      _springController.forward(from: 0.0);
      _hasTriggeredHaptic = false;
      widget.onOpenSearch();
    } else if (_pullOffset > 0.0) {
      _springAnimation = Tween<double>(
        begin: _pullOffset,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _springController,
          curve: Curves.easeOutCubic,
        ),
      );
      _springController.forward(from: 0.0);
      _hasTriggeredHaptic = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.metrics.pixels <= 0) {
        _isDragging = true;
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        _onPullDelta(-notification.overscroll);
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels <= 0 &&
          notification.scrollDelta != null &&
          notification.scrollDelta! < 0 &&
          notification.dragDetails != null) {
        _onPullDelta(-notification.scrollDelta!);
      }
    } else if (notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      if (notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 0) {
            _onPullDelta(details.primaryDelta!);
          } else if (details.primaryDelta != null &&
              details.primaryDelta! < 0 &&
              _pullOffset > 0) {
            _onPullDelta(details.primaryDelta!);
          }
        },
        onVerticalDragEnd: (_) => _onPullEnd(),
        onVerticalDragCancel: () => _onPullEnd(),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Revealed Search Header
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
                              color: _pullOffset >= widget.threshold
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
                                color: _pullOffset >= widget.threshold
                                    ? colors.accent
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.isTabletPane
                                      ? 'Search notes...'
                                      : 'Search notes, documents, OCR, tags...',
                                  style: AppTypography.headline.copyWith(
                                    color: colors.textTertiary,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_pullOffset >= widget.threshold)
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

            // Translating Content
            Transform.translate(
              offset: Offset(0.0, _pullOffset),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
