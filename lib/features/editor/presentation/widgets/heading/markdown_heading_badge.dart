import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_typography.dart';

/// Compact, editorial badge for displaying and interacting with a heading's level (H1..H6).
/// Designed to provide visual parity with Table badges and CodeBlock language pills.
class MarkdownHeadingBadge extends StatelessWidget {
  const MarkdownHeadingBadge({
    super.key,
    required this.level,
    this.onTap,
    this.enabled = true,
  });

  /// Heading level (1 to 6).
  final int level;

  /// Callback when the badge is tapped.
  final VoidCallback? onTap;

  /// Whether the badge is interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: enabled,
      label: 'Heading level $level',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: enabled ? onTap : null,
          borderRadius: AppRadii.borderSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.0),
            decoration: BoxDecoration(
              color: colors.tagBackground.withValues(alpha: 0.8),
              borderRadius: AppRadii.borderSm,
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'H$level',
                  style: AppTypography.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 14,
                    color: colors.accent.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
