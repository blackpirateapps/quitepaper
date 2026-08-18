import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

class QuietIconButton extends StatelessWidget {
  const QuietIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.size = 20.0,
    this.padding = const EdgeInsets.all(12.0),
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.accent : colors.textSecondary;

    Widget button = Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: padding,
          child: Icon(
            icon,
            size: size,
            color: onPressed == null ? colors.textTertiary : color,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    // Ensure accessible touch target
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 44.0,
        minHeight: 44.0,
      ),
      child: Center(child: button),
    );
  }
}
