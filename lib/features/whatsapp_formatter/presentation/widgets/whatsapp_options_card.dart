import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/whatsapp_format_options.dart';

/// Card containing formatting toggles matching the Quiet Paper WhatsApp mockup.
class WhatsAppOptionsCard extends StatelessWidget {
  const WhatsAppOptionsCard({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final WhatsAppFormatOptions options;
  final ValueChanged<WhatsAppFormatOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header: Sliders icon + Options
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Options',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Rounded Options Container
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSubtle.withValues(alpha: 0.4)
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.7),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              _buildOptionRow(
                context,
                colors: colors,
                label: 'Show sender names',
                value: options.showSenderNames,
                onTap: () {
                  onChanged(options.copyWith(
                    showSenderNames: !options.showSenderNames,
                  ));
                },
              ),
              const SizedBox(height: 10),
              _buildOptionRow(
                context,
                colors: colors,
                label: 'Preserve timestamps',
                value: options.preserveTimestamps,
                onTap: () {
                  onChanged(options.copyWith(
                    preserveTimestamps: !options.preserveTimestamps,
                  ));
                },
              ),
              const SizedBox(height: 10),
              _buildOptionRow(
                context,
                colors: colors,
                label: 'Group consecutive messages',
                value: options.groupConsecutiveMessages,
                onTap: () {
                  onChanged(options.copyWith(
                    groupConsecutiveMessages: !options.groupConsecutiveMessages,
                  ));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow(
    BuildContext context, {
    required AppColors colors,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              value
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: value ? colors.textPrimary : colors.textTertiary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
