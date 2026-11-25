import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/platform_layout_helper.dart';
import '../../tags/domain/phosphor_icons.dart';

bool taskUsesSheet(BuildContext context) =>
    !PlatformLayoutHelper.isDesktop(context) ||
    MediaQuery.sizeOf(context).width < 600;

Future<T?> showTaskModal<T>(BuildContext context, WidgetBuilder builder) {
  final colors = context.appColors;
  if (taskUsesSheet(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.background,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: colors.background,
      child: SizedBox(width: 440, child: builder(context)),
    ),
  );
}

/// Shared paper surface with a fixed header/footer and keyboard-aware body.
class TaskModal extends StatelessWidget {
  const TaskModal({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
    this.busy = false,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.appColors;
    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (media.size.height -
                          media.viewInsets.bottom -
                          media.padding.vertical -
                          24)
                      .clamp(0, 560),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (taskUsesSheet(context))
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: colors.textTertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: context.appTypography.title.copyWith(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.appTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: Icon(
                          PhosphorIconsRegular.x,
                          size: 20,
                          color: colors.iconSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(child: child),
                Divider(height: 1, color: colors.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
