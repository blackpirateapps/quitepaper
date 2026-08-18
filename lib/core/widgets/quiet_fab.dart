import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

class QuietFab extends StatelessWidget {
  const QuietFab({
    super.key,
    required this.onPressed,
    this.tooltip = 'New note',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.accent,
        elevation: 2,
        shadowColor: colors.accentDark.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
