import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

/// Shows a Spotlight / Command Palette style modal floating in the upper-third of the screen.
///
/// Designed for searchable pickers (Note Links, Languages, Fonts, Tags) where immediate
/// keyboard focus, quick typeahead, and rapid selection are essential on desktop.
Future<T?> showQuietSpotlight<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
  double? maxHeight,
  Color? barrierColor,
  bool barrierDismissible = true,
  RouteSettings? routeSettings,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss palette',
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 160),
    routeSettings: routeSettings,
    pageBuilder: (ctx, anim1, anim2) {
      final colors = ctx.appColors;
      final screenHeight = MediaQuery.of(ctx).size.height;
      final effectiveMaxHeight = maxHeight ?? (screenHeight * 0.72);

      return SafeArea(
        child: Align(
          // Positioned in the upper-third of the viewport to match desktop eye level
          alignment: const Alignment(0.0, -0.38),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: effectiveMaxHeight,
            ),
            child: Material(
              color: colors.surface,
              elevation: 12,
              shadowColor: colors.textPrimary.withValues(alpha: 0.16),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.borderMd,
                side: BorderSide(color: colors.divider, width: 0.8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    Navigator.of(ctx).pop();
                  },
                },
                child: FocusScope(
                  autofocus: true,
                  child: builder(ctx),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
