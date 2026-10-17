import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'quiet_icon_button.dart';

/// Shows a centered editorial dialog following Quiet Paper's warm design system.
///
/// Replaces sprawling bottom sheets on desktop with a clean, focused dialog
/// featuring structured header, '✕' close affordance, and `Escape` key dismissal.
Future<T?> showQuietDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  Widget? headerTrailing,
  bool showCloseButton = true,
  double maxWidth = 560,
  double? maxHeight,
  bool barrierDismissible = true,
  Color? barrierColor,
  RouteSettings? routeSettings,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss dialog',
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.40),
    transitionDuration: const Duration(milliseconds: 180),
    routeSettings: routeSettings,
    pageBuilder: (ctx, anim1, anim2) {
      final screenHeight = MediaQuery.of(ctx).size.height;
      final effectiveMaxHeight = maxHeight ?? (screenHeight * 0.85);

      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: effectiveMaxHeight,
            ),
            child: QuietEditorialDialogCard(
              title: title,
              subtitle: subtitle,
              headerTrailing: headerTrailing,
              showCloseButton: showCloseButton,
              child: builder(ctx),
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
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A container card for editorial dialogs with an optional header and close button.
class QuietEditorialDialogCard extends StatelessWidget {
  const QuietEditorialDialogCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.headerTrailing,
    this.showCloseButton = true,
    this.onClose,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? headerTrailing;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasHeader = title != null || subtitle != null || headerTrailing != null || (showCloseButton && (title != null || subtitle != null));

    return Material(
      color: colors.surface,
      elevation: 10,
      shadowColor: colors.textPrimary.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderLg,
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (onClose != null) {
              onClose!();
            } else {
              Navigator.of(context).pop();
            }
          },
        },
        child: FocusScope(
          autofocus: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasHeader) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                style: AppTypography.title.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: AppTypography.caption.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ?headerTrailing,
                      if (showCloseButton)
                        QuietIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close (Esc)',
                          size: 18,
                          onPressed: () {
                            if (onClose != null) {
                              onClose!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: colors.divider,
                ),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
