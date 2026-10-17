import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

/// Shows an anchored contextual popover route adjacent to [anchorKey] or [cursorPosition].
///
/// Automatically flips between opening below or above the anchor depending on
/// available screen clearance, and clamps horizontally within the viewport.
Future<T?> showQuietPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlobalKey? anchorKey,
  Offset? cursorPosition,
  double minWidth = 200,
  double maxWidth = 360,
  double? maxHeight,
  Color? barrierColor,
  bool barrierDismissible = true,
  RouteSettings? routeSettings,
}) {
  final overlay = Overlay.of(context, rootOverlay: true).context.findRenderObject() as RenderBox;
  Rect anchorRect;

  if (anchorKey != null && anchorKey.currentContext != null) {
    final box = anchorKey.currentContext!.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
      anchorRect = origin & box.size;
    } else {
      anchorRect = Rect.fromCenter(
        center: overlay.size.center(Offset.zero),
        width: 1,
        height: 1,
      );
    }
  } else if (cursorPosition != null) {
    anchorRect = Rect.fromLTWH(cursorPosition.dx, cursorPosition.dy, 1, 1);
  } else {
    anchorRect = Rect.fromCenter(
      center: overlay.size.center(Offset.zero),
      width: 1,
      height: 1,
    );
  }

  return Navigator.of(context, rootNavigator: true).push<T>(
    QuietPopoverRoute<T>(
      anchorRect: anchorRect,
      builder: builder,
      minWidth: minWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.12),
      barrierDismissible: barrierDismissible,
      settings: routeSettings,
    ),
  );
}

/// Custom popup route that positions a popover relative to an anchor rectangle.
class QuietPopoverRoute<T> extends PopupRoute<T> {
  QuietPopoverRoute({
    required this.anchorRect,
    required this.builder,
    this.minWidth = 200,
    this.maxWidth = 360,
    this.maxHeight,
    this.barrierColor = const Color(0x1F000000),
    this.barrierDismissible = true,
    this.barrierLabel = 'Dismiss popover',
    super.settings,
  });

  final Rect anchorRect;
  final WidgetBuilder builder;
  final double minWidth;
  final double maxWidth;
  final double? maxHeight;

  @override
  final Color barrierColor;

  @override
  final bool barrierDismissible;

  @override
  final String barrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final colors = context.appColors;

    return CustomSingleChildLayout(
      delegate: _QuietPopoverLayoutDelegate(
        anchorRect: anchorRect,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: Material(
            color: colors.surface,
            elevation: 8,
            shadowColor: colors.textPrimary.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.borderMd,
              side: BorderSide(color: colors.divider, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  Navigator.of(context).pop();
                },
              },
              child: FocusScope(
                autofocus: true,
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _QuietPopoverLayoutDelegate({
    required this.anchorRect,
    required this.minWidth,
    required this.maxWidth,
    this.maxHeight,
  });

  final Rect anchorRect;
  final double minWidth;
  final double maxWidth;
  final double? maxHeight;

  static const double _viewportPadding = 12.0;
  static const double _anchorSpacing = 4.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxAvailableWidth = constraints.maxWidth - (_viewportPadding * 2);
    final effectiveMaxWidth = maxWidth.clamp(minWidth, maxAvailableWidth);

    final maxAvailableHeight = maxHeight ?? (constraints.maxHeight - (_viewportPadding * 2));

    return BoxConstraints(
      minWidth: minWidth.clamp(0, effectiveMaxWidth),
      maxWidth: effectiveMaxWidth,
      minHeight: 0,
      maxHeight: maxAvailableHeight.clamp(0.0, constraints.maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final spaceBelow = size.height - anchorRect.bottom - _anchorSpacing - _viewportPadding;
    final spaceAbove = anchorRect.top - _anchorSpacing - _viewportPadding;

    double y;
    if (childSize.height <= spaceBelow || spaceBelow >= spaceAbove) {
      // Position below anchor
      y = anchorRect.bottom + _anchorSpacing;
    } else {
      // Position above anchor
      y = anchorRect.top - childSize.height - _anchorSpacing;
    }

    // Prefer aligning child left with anchor left, but shift if overflowing right
    double x = anchorRect.left;
    if (x + childSize.width > size.width - _viewportPadding) {
      x = size.width - _viewportPadding - childSize.width;
    }
    if (x < _viewportPadding) {
      x = _viewportPadding;
    }

    // Clamp Y to stay within viewport padding
    y = y.clamp(_viewportPadding, size.height - _viewportPadding - childSize.height);

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _QuietPopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect ||
        minWidth != oldDelegate.minWidth ||
        maxWidth != oldDelegate.maxWidth ||
        maxHeight != oldDelegate.maxHeight;
  }
}
