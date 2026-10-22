import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/whatsapp_parse_result.dart';

/// Subtle, quiet inline suggestion banner appearing upon WhatsApp chat paste.
class WhatsAppInlineSuggestionBanner extends StatelessWidget {
  const WhatsAppInlineSuggestionBanner({
    super.key,
    required this.result,
    required this.onPreview,
    required this.onDismiss,
    this.onApply,
  });

  final WhatsAppParseResult result;
  final VoidCallback onPreview;
  final VoidCallback onDismiss;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final msgCount = result.messageCount;
    final countLabel = msgCount > 0 ? ' ($msgCount messages)' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSubtle : colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.8),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 16,
            color: colors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'WhatsApp conversation detected$countLabel',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (onApply != null) ...[
            ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: colors.textPrimary,
                foregroundColor: colors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Apply format',
                style: AppTypography.caption.copyWith(
                  color: colors.background,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          TextButton(
            onPressed: onPreview,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: colors.accent.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Preview',
              style: AppTypography.caption.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: colors.textTertiary,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Dismiss suggestion',
          ),
        ],
      ),
    );
  }
}
