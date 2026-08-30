import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../markdown/heading_item.dart';
import '../markdown/heading_parser.dart';

/// An intelligent heading-aware scrollbar for long-form note reading and editing.
///
/// Features:
/// - Minimal, unobtrusive scrollbar when idle or scrolling.
/// - When hovered or dragged, nearby Markdown headings appear alongside the scrollbar.
/// - Visual integration using a soft continuous gradient rather than opaque boxes or panels.
/// - Dynamic moving heading window for notes with dozens or hundreds of headings.
/// - Subtly distinguishes the currently active section.
/// - Tapping a heading smoothly animates the document to that section.
/// - Works uniformly across Editor mode and Markdown Preview mode.
/// - Fully accessible with semantics announcements and responsive touch hit targets.
class IntelligentHeadingScrollbar extends StatefulWidget {
  const IntelligentHeadingScrollbar({
    super.key,
    required this.child,
    required this.scrollController,
    this.markdownData,
    this.contentController,
    this.title,
    this.titleController,
    this.enabled = true,
    this.padding = const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 3.0),
    this.onHeadingTap,
    this.maxVisibleHeadings = 8,
  });

  /// The scrollable child widget (e.g. SingleChildScrollView or ListView).
  final Widget child;

  /// Authoritative ScrollController attached to the scrollable child.
  final ScrollController scrollController;

  /// Canonical Markdown document text (used when contentController is null).
  final String? markdownData;

  /// Optional Markdown TextEditingController for instant live-editing updates.
  final TextEditingController? contentController;

  /// Optional document title.
  final String? title;

  /// Optional title TextEditingController.
  final TextEditingController? titleController;

  /// Whether the intelligent scrollbar is enabled.
  final bool enabled;

  /// Edge insets for the scrollbar track.
  final EdgeInsets padding;

  /// Optional custom callback when a heading is selected.
  final void Function(HeadingItem heading, double targetOffset)? onHeadingTap;

  /// Maximum number of headings visible at once in the dynamic window.
  final int maxVisibleHeadings;

  @override
  State<IntelligentHeadingScrollbar> createState() =>
      _IntelligentHeadingScrollbarState();
}

class _IntelligentHeadingScrollbarState extends State<IntelligentHeadingScrollbar>
    with TickerProviderStateMixin {
  // Parsed heading list and target scroll offsets
  List<HeadingItem> _headings = const [];
  List<double> _headingOffsets = const [];
  int _activeHeadingIndex = 0;

  // Tracked scroll metrics
  double _maxScrollExtent = 0.0;
  double _currentScrollOffset = 0.0;
  double _viewportDimension = 0.0;

  // Interaction and animation states
  bool _isHovered = false;
  bool _isDragging = false;
  bool _isScrolling = false;

  Timer? _scrollFadeTimer;
  Timer? _hoverExitGraceTimer;
  Timer? _contentDebounceTimer;

  late final AnimationController _thumbFadeController;
  late final Animation<double> _thumbFadeAnimation;

  late final AnimationController _headingFadeController;
  late final Animation<double> _headingFadeAnimation;

  // Drag tracking
  double _dragStartOffset = 0.0;
  double _dragStartY = 0.0;

  String get _effectiveMarkdown =>
      widget.contentController?.text ?? widget.markdownData ?? '';

  @override
  void initState() {
    super.initState();

    _thumbFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _thumbFadeAnimation = CurvedAnimation(
      parent: _thumbFadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _headingFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _headingFadeAnimation = CurvedAnimation(
      parent: _headingFadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _extractAndRecalculateHeadings();

    widget.scrollController.addListener(_onScrollUpdated);
    widget.contentController?.addListener(_onContentChanged);
    widget.titleController?.addListener(_onContentChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onScrollUpdated();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onScrollUpdated();
      }
    });
  }

  @override
  void didUpdateWidget(IntelligentHeadingScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollUpdated);
      widget.scrollController.addListener(_onScrollUpdated);
    }

    if (oldWidget.contentController != widget.contentController) {
      oldWidget.contentController?.removeListener(_onContentChanged);
      widget.contentController?.addListener(_onContentChanged);
    }

    if (oldWidget.titleController != widget.titleController) {
      oldWidget.titleController?.removeListener(_onContentChanged);
      widget.titleController?.addListener(_onContentChanged);
    }

    if (oldWidget.markdownData != widget.markdownData ||
        oldWidget.title != widget.title ||
        oldWidget.contentController != widget.contentController) {
      _extractAndRecalculateHeadings();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onScrollUpdated();
      }
    });
  }

  @override
  void dispose() {
    _scrollFadeTimer?.cancel();
    _hoverExitGraceTimer?.cancel();
    _contentDebounceTimer?.cancel();
    widget.scrollController.removeListener(_onScrollUpdated);
    widget.contentController?.removeListener(_onContentChanged);
    widget.titleController?.removeListener(_onContentChanged);
    _thumbFadeController.dispose();
    _headingFadeController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    _contentDebounceTimer?.cancel();
    _contentDebounceTimer = Timer(const Duration(milliseconds: 40), () {
      if (mounted) {
        _extractAndRecalculateHeadings();
      }
    });
  }

  void _extractAndRecalculateHeadings() {
    final parsed = HeadingParser.extractHeadings(_effectiveMarkdown);
    if (!mounted) return;
    setState(() {
      _headings = parsed;
    });
    _recalculateHeadingOffsets();
  }

  void _recalculateHeadingOffsets() {
    if (_headings.isEmpty) {
      _headingOffsets = const [];
      _activeHeadingIndex = 0;
      return;
    }

    final maxScroll = _effectiveMaxScrollExtent;
    if (maxScroll <= 0) {
      _headingOffsets = _headings.map((h) => 0.0).toList();
      _activeHeadingIndex = 0;
      return;
    }

    _headingOffsets = _headings.map((h) {
      return (h.normalizedOffset * maxScroll).clamp(0.0, maxScroll);
    }).toList();

    _updateActiveHeading();
  }

  double get _effectiveMaxScrollExtent {
    if (widget.scrollController.hasClients &&
        widget.scrollController.position.hasContentDimensions) {
      return widget.scrollController.position.maxScrollExtent;
    }
    return _maxScrollExtent;
  }

  double get _effectiveCurrentOffset {
    if (widget.scrollController.hasClients &&
        widget.scrollController.position.hasContentDimensions) {
      return widget.scrollController.offset;
    }
    return _currentScrollOffset;
  }

  void _onScrollUpdated() {
    if (!mounted) return;

    if (widget.scrollController.hasClients &&
        widget.scrollController.position.hasContentDimensions) {
      setState(() {
        _maxScrollExtent = widget.scrollController.position.maxScrollExtent;
        _currentScrollOffset = widget.scrollController.offset;
        _viewportDimension = widget.scrollController.position.viewportDimension;
      });
    }

    _recalculateHeadingOffsets();
    _showScrollbarTemporarily();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) {
      final metrics = notification.metrics;
      final maxExtent = metrics.maxScrollExtent;
      final pixels = metrics.pixels;
      final viewport = metrics.viewportDimension;

      if (_maxScrollExtent != maxExtent ||
          _currentScrollOffset != pixels ||
          _viewportDimension != viewport) {
        setState(() {
          _maxScrollExtent = maxExtent;
          _currentScrollOffset = pixels;
          _viewportDimension = viewport;
        });
        _recalculateHeadingOffsets();
      }
      _showScrollbarTemporarily();
    }
    return false;
  }

  bool _handleScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      final metrics = notification.metrics;
      final maxExtent = metrics.maxScrollExtent;
      final pixels = metrics.pixels;
      final viewport = metrics.viewportDimension;

      if (_maxScrollExtent != maxExtent ||
          _currentScrollOffset != pixels ||
          _viewportDimension != viewport) {
        setState(() {
          _maxScrollExtent = maxExtent;
          _currentScrollOffset = pixels;
          _viewportDimension = viewport;
        });
        _recalculateHeadingOffsets();
      }
    }
    return false;
  }

  void _updateActiveHeading() {
    if (_headings.isEmpty || _headingOffsets.isEmpty) {
      _activeHeadingIndex = 0;
      return;
    }

    final currentOffset = _effectiveCurrentOffset;

    final newIndex = HeadingParser.findActiveHeadingIndex(
      scrollOffset: currentOffset,
      headingOffsets: _headingOffsets,
    );

    if (newIndex != _activeHeadingIndex) {
      setState(() {
        _activeHeadingIndex = newIndex;
      });
    }
  }

  void _showScrollbarTemporarily() {
    if (!_isScrolling && !_isHovered && !_isDragging) {
      _isScrolling = true;
      _thumbFadeController.forward();
    }

    _scrollFadeTimer?.cancel();
    _scrollFadeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_isHovered && !_isDragging) {
        _isScrolling = false;
        _thumbFadeController.reverse();
      }
    });
  }

  void _onPointerEnter() {
    _hoverExitGraceTimer?.cancel();
    setState(() {
      _isHovered = true;
    });

    _thumbFadeController.forward();
    if (_headings.isNotEmpty) {
      _headingFadeController.forward();
    }
  }

  void _onPointerExit() {
    _hoverExitGraceTimer?.cancel();
    _hoverExitGraceTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted && !_isDragging) {
        setState(() {
          _isHovered = false;
        });

        _headingFadeController.reverse();
        if (!_isScrolling) {
          _thumbFadeController.reverse();
        }
      }
    });
  }

  void _onDragStart(DragStartDetails details, double trackHeight, double thumbHeight) {
    _hoverExitGraceTimer?.cancel();
    _scrollFadeTimer?.cancel();

    setState(() {
      _isDragging = true;
    });

    _thumbFadeController.forward();
    if (_headings.isNotEmpty) {
      _headingFadeController.forward();
    }

    _dragStartY = details.localPosition.dy;
    if (widget.scrollController.hasClients) {
      _dragStartOffset = widget.scrollController.offset;
    } else {
      _dragStartOffset = _currentScrollOffset;
    }
  }

  void _onDragUpdate(
    DragUpdateDetails details,
    double trackHeight,
    double thumbHeight,
  ) {
    final maxScroll = _effectiveMaxScrollExtent;
    if (maxScroll <= 0) return;

    final travelDistance = (trackHeight - thumbHeight).clamp(1.0, double.infinity);
    final deltaY = details.localPosition.dy - _dragStartY;
    final scrollDelta = (deltaY / travelDistance) * maxScroll;

    final targetOffset = (_dragStartOffset + scrollDelta).clamp(0.0, maxScroll);
    if (widget.scrollController.hasClients) {
      widget.scrollController.jumpTo(targetOffset);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    _hoverExitGraceTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_isHovered) {
        _headingFadeController.reverse();
        _thumbFadeController.reverse();
      }
    });
  }

  void _onTrackTap(TapDownDetails details, double trackHeight, double thumbHeight) {
    final maxScroll = _effectiveMaxScrollExtent;
    if (maxScroll <= 0) return;

    final localY = details.localPosition.dy.clamp(0.0, trackHeight);
    final travelDistance = (trackHeight - thumbHeight).clamp(1.0, double.infinity);
    final fraction = (localY - (thumbHeight / 2)) / travelDistance;
    final targetOffset = (fraction * maxScroll).clamp(0.0, maxScroll);

    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }

    _showScrollbarTemporarily();
  }

  void _navigateToHeading(HeadingItem heading) {
    final headingIndex = _headings.indexOf(heading);
    final maxScroll = _effectiveMaxScrollExtent;

    double targetOffset;
    if (headingIndex >= 0 && headingIndex < _headingOffsets.length) {
      targetOffset = _headingOffsets[headingIndex];
    } else {
      targetOffset = (heading.normalizedOffset * maxScroll).clamp(0.0, maxScroll);
    }

    if (widget.onHeadingTap != null) {
      widget.onHeadingTap!(heading, targetOffset);
    } else if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    HapticFeedback.selectionClick();

    setState(() {
      if (headingIndex >= 0) {
        _activeHeadingIndex = headingIndex;
      }
    });

    // Hold visible briefly after jump so user sees destination, then fade
    _hoverExitGraceTimer?.cancel();
    _hoverExitGraceTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && !_isHovered && !_isDragging) {
        _headingFadeController.reverse();
        if (!_isScrolling) {
          _thumbFadeController.reverse();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final colors = context.appColors;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _handleScrollMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final availableWidth = constraints.maxWidth;

            final trackHeight = (availableHeight - widget.padding.vertical).clamp(20.0, double.infinity);

            final maxScroll = _effectiveMaxScrollExtent;
            final currentScroll = _effectiveCurrentOffset.clamp(0.0, maxScroll > 0 ? maxScroll : 0.0);
            final viewportDim = _viewportDimension > 0 ? _viewportDimension : availableHeight;

            final canScroll = maxScroll > 0;
            final totalContentHeight = maxScroll + viewportDim;

            // Thumb height calculation
            final rawThumbHeight = totalContentHeight > 0
                ? (viewportDim / totalContentHeight) * trackHeight
                : trackHeight;
            final thumbHeight = rawThumbHeight.clamp(24.0, (trackHeight * 0.85).clamp(24.0, trackHeight));

            final travelDistance = (trackHeight - thumbHeight).clamp(0.0, double.infinity);
            final scrollFraction = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
            final thumbTop = scrollFraction * travelDistance;

            // Visible window of headings
            final visibleHeadings = _headings.isNotEmpty
                ? HeadingParser.computeVisibleWindow(
                    headings: _headings,
                    activeIndex: _activeHeadingIndex,
                    availableHeight: trackHeight,
                    itemHeight: 32.0,
                    maxItems: widget.maxVisibleHeadings,
                  )
                : const <HeadingItem>[];

            final activeHeading = (_activeHeadingIndex >= 0 && _activeHeadingIndex < _headings.length)
                ? _headings[_activeHeadingIndex]
                : null;

            return Stack(
              children: [
                // 1. Underlying scrollable document content
                Positioned.fill(
                  child: widget.child,
                ),

                // 2. Heading navigation overlay (soft gradient + dynamic moving heading window)
                if (canScroll && visibleHeadings.isNotEmpty)
                  Positioned(
                    top: widget.padding.top,
                    bottom: widget.padding.bottom,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _headingFadeAnimation,
                      builder: (context, child) {
                        if (_headingFadeAnimation.value <= 0) {
                          return const SizedBox.shrink();
                        }
                        return Opacity(
                          opacity: _headingFadeAnimation.value,
                          child: IgnorePointer(
                            ignoring: !_isHovered && !_isDragging,
                            child: _buildHeadingOverlay(
                              context,
                              colors,
                              visibleHeadings,
                              activeHeading,
                              thumbTop,
                              thumbHeight,
                              trackHeight,
                              availableWidth,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // 3. Scrollbar track and thumb with comfortable touch/hover hit zone
                if (canScroll)
                  Positioned(
                    top: widget.padding.top,
                    bottom: widget.padding.bottom,
                    right: widget.padding.right,
                    child: MouseRegion(
                      onEnter: (_) => _onPointerEnter(),
                      onExit: (_) => _onPointerExit(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (d) => _onDragStart(d, trackHeight, thumbHeight),
                        onVerticalDragUpdate: (d) => _onDragUpdate(d, trackHeight, thumbHeight),
                        onVerticalDragEnd: _onDragEnd,
                        onVerticalDragCancel: () => _onDragEnd(DragEndDetails()),
                        onTapDown: (d) => _onTrackTap(d, trackHeight, thumbHeight),
                        child: Container(
                          width: 36.0, // Generous invisible touch/pointer target
                          color: Colors.transparent,
                          alignment: Alignment.topRight,
                          child: FadeTransition(
                            opacity: _thumbFadeAnimation,
                            child: _buildScrollbarThumb(
                              colors,
                              thumbTop,
                              thumbHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScrollbarThumb(
    AppColors colors,
    double thumbTop,
    double thumbHeight,
  ) {
    final isInteracting = _isHovered || _isDragging;
    final thumbWidth = isInteracting ? 4.5 : 3.0;

    return Container(
      margin: EdgeInsets.only(top: thumbTop),
      width: thumbWidth,
      height: thumbHeight,
      decoration: BoxDecoration(
        color: isInteracting
            ? colors.scrollbarActive
            : colors.scrollbar.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(thumbWidth / 2),
      ),
    );
  }

  Widget _buildHeadingOverlay(
    BuildContext context,
    AppColors colors,
    List<HeadingItem> visibleHeadings,
    HeadingItem? activeHeading,
    double thumbTop,
    double thumbHeight,
    double trackHeight,
    double availableWidth,
  ) {
    // Dynamic overlay width constraint (proportional to screen, capped for aesthetics)
    final maxOverlayWidth = (availableWidth * 0.48).clamp(160.0, 300.0);
    const itemHeight = 30.0;
    final windowTotalHeight = visibleHeadings.length * itemHeight;

    // Anchor the heading window vertically near the scrollbar thumb center
    final thumbCenterY = thumbTop + (thumbHeight / 2);
    final targetWindowTop = (thumbCenterY - (windowTotalHeight / 2)).clamp(
      8.0,
      (trackHeight - windowTotalHeight - 8.0).clamp(8.0, double.infinity),
    );

    return MouseRegion(
      onEnter: (_) => _onPointerEnter(),
      onExit: (_) => _onPointerExit(),
      child: Container(
        width: maxOverlayWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          // Continuous subtle horizontal gradient fading into document background
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              colors.background.withValues(alpha: 0.0),
              colors.background.withValues(alpha: 0.78),
              colors.background.withValues(alpha: 0.94),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Headings column positioned smoothly alongside the thumb
            Positioned(
              top: targetWindowTop,
              right: 18.0, // Spaced just to the left of the scrollbar thumb
              left: 12.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: visibleHeadings.map((heading) {
                  final isActive = activeHeading?.id == heading.id;
                  return _buildHeadingRow(
                    context,
                    colors,
                    heading,
                    isActive,
                    itemHeight,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadingRow(
    BuildContext context,
    AppColors colors,
    HeadingItem heading,
    bool isActive,
    double itemHeight,
  ) {
    // Subtle typography and indentation hierarchy based on heading level
    final levelIndent = (heading.level - 1) * 6.0;

    TextStyle labelStyle;
    if (isActive) {
      labelStyle = AppTypography.caption.copyWith(
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
        color: colors.accent,
        letterSpacing: -0.1,
      );
    } else {
      switch (heading.level) {
        case 1:
          labelStyle = AppTypography.caption.copyWith(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary.withValues(alpha: 0.88),
          );
          break;
        case 2:
          labelStyle = AppTypography.caption.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary.withValues(alpha: 0.82),
          );
          break;
        default:
          labelStyle = AppTypography.caption.copyWith(
            fontSize: 11.0,
            fontWeight: FontWeight.w400,
            color: colors.textTertiary.withValues(alpha: 0.80),
          );
          break;
      }
    }

    return Semantics(
      label: 'Jump to ${heading.title}',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToHeading(heading),
        child: Container(
          height: itemHeight,
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: levelIndent),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Truncated heading title
              Flexible(
                child: Text(
                  heading.title,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),

              // Small subtle indicator dot for currently active heading
              if (isActive) ...[
                const SizedBox(width: 6.0),
                Container(
                  width: 4.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
