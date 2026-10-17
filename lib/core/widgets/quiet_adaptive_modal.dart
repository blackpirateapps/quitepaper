import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../utils/platform_layout_helper.dart';
import 'quiet_editorial_dialog.dart';
import 'quiet_popover.dart';
import 'quiet_spotlight_dialog.dart';

/// Modal presentation styles on desktop/mouse platforms.
enum AdaptiveModalType {
  /// Anchored to a trigger button (GlobalKey) or mouse cursor position.
  popover,

  /// Centered spotlight-style command palette (top-third, auto-focused search).
  spotlight,

  /// Centered editorial dialog with structured header, '✕' button, and card layout.
  dialog,

  /// Embedded collapsible right-hand pane (used on wide screens for Version History/Inspectors).
  inspector,
}

/// Centralized presentation controller for mobile bottom sheets vs desktop modals.
class QuietAdaptiveModal {
  const QuietAdaptiveModal._();

  /// Presents a modal adaptively based on platform ergonomics.
  ///
  /// On mobile devices (Android/iOS), displays a standard modal bottom sheet with
  /// touch drag handles and swipe-to-dismiss.
  ///
  /// On desktop platforms (Linux, macOS, Windows), adapts according to [type]:
  /// - [AdaptiveModalType.popover]: Position-aware flyout adjacent to [anchorKey] or [cursorPosition].
  /// - [AdaptiveModalType.spotlight]: Floating command palette centered at eye level with instant keyboard focus.
  /// - [AdaptiveModalType.dialog]: Clean, centered card dialog with header and `Escape` key dismissal.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    AdaptiveModalType type = AdaptiveModalType.dialog,
    GlobalKey? anchorKey,
    Offset? cursorPosition,
    String? title,
    String? subtitle,
    Widget? headerTrailing,
    double maxWidth = 560,
    double? maxHeight,
    bool isScrollControlled = true,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) {
    final isDesktop = PlatformLayoutHelper.isDesktop(context);

    if (!isDesktop) {
      // -----------------------------------------------------------------
      // Mobile / Touch Presentation: Standard Modal Bottom Sheet
      // -----------------------------------------------------------------
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        backgroundColor: Colors.transparent,
        barrierColor: barrierColor ?? Colors.black54,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        builder: builder,
      );
    }

    // -------------------------------------------------------------------
    // Desktop / Mouse Presentation: Adaptive Paradigms
    // -------------------------------------------------------------------
    switch (type) {
      case AdaptiveModalType.popover:
        return showQuietPopover<T>(
          context: context,
          anchorKey: anchorKey,
          cursorPosition: cursorPosition,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          barrierColor: barrierColor,
          barrierDismissible: barrierDismissible,
          routeSettings: routeSettings,
          builder: builder,
        );

      case AdaptiveModalType.spotlight:
        return showQuietSpotlight<T>(
          context: context,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          barrierColor: barrierColor,
          barrierDismissible: barrierDismissible,
          routeSettings: routeSettings,
          builder: builder,
        );

      case AdaptiveModalType.dialog:
      case AdaptiveModalType.inspector:
        return showQuietDialog<T>(
          context: context,
          title: title,
          subtitle: subtitle,
          headerTrailing: headerTrailing,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          barrierColor: barrierColor,
          barrierDismissible: barrierDismissible,
          routeSettings: routeSettings,
          builder: builder,
        );
    }
  }
}

/// Subtle drag handle indicator rendered on touch devices, and completely hidden on desktop.
class AdaptiveSheetDragHandle extends StatelessWidget {
  const AdaptiveSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformLayoutHelper.isDesktop(context)) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;

    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.divider,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
  }
}
