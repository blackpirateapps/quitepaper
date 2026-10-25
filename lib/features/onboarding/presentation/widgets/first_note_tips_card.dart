import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class FirstNoteTipsCard extends StatelessWidget {
  const FirstNoteTipsCard({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 32dp accentSoft circle with 18dp icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'A few quiet tricks',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: colors.accent,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: onDismiss,
                      child: const Text('Got it'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildTipLine(
                  '• No save button—everything saves as you type.',
                  colors,
                ),
                const SizedBox(height: 3),
                _buildTipLine(
                  '• Type #tag anywhere to organize.',
                  colors,
                ),
                const SizedBox(height: 3),
                _buildTipLine(
                  '• Skip the title? The first line becomes it.',
                  colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipLine(String text, AppColors colors) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: colors.textSecondary,
      ),
    );
  }
}
