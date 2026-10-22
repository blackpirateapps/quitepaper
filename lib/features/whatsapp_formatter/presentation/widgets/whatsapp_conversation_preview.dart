import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/whatsapp_format_options.dart';
import '../../domain/whatsapp_parse_result.dart';

/// Formatted visual transcript of WhatsApp messages matching the design mockup.
class WhatsAppConversationPreview extends StatelessWidget {
  const WhatsAppConversationPreview({
    super.key,
    required this.parseResult,
    required this.options,
  });

  final WhatsAppParseResult parseResult;
  final WhatsAppFormatOptions options;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (parseResult.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No messages detected',
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
        ),
      );
    }

    final children = <Widget>[];
    String? currentDate;
    String? currentSender;

    // Optional warning banner if some lines couldn't be parsed
    if (parseResult.hasUnrecognizedLines) {
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Some lines couldn't be identified and will be preserved.",
                  style: AppTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (var i = 0; i < parseResult.messages.length; i++) {
      final msg = parseResult.messages[i];

      // Handle Unrecognized Lines
      if (msg.isUnrecognized) {
        currentSender = null;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              msg.body,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
        continue;
      }

      // Handle Date Dividers
      if (msg.date.isNotEmpty && msg.date != currentDate) {
        currentDate = msg.date;
        currentSender = null;
        final dateLabel = _formatDateHeader(msg.date);

        children.add(
          Padding(
            padding: EdgeInsets.only(top: i > 0 ? 20 : 4, bottom: 12),
            child: Row(
              children: [
                Text(
                  dateLabel,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    color: colors.divider.withValues(alpha: 0.7),
                    height: 1,
                    thickness: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Handle System Notices
      if (msg.isSystemMessage) {
        currentSender = null;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                msg.body,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontStyle: FontStyle.italic,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // Handle Sender Grouping
      final sender = msg.sender ?? 'Unknown';
      final isNewSenderGroup = !options.groupConsecutiveMessages ||
          currentSender == null ||
          currentSender != sender;

      if (isNewSenderGroup) {
        currentSender = sender;
        if (options.showSenderNames) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sender,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  if (options.preserveTimestamps && msg.time.isNotEmpty)
                    Text(
                      msg.time,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          );
        }
      }

      // Message Body + Timestamp
      final showIndividualTimestamp = options.preserveTimestamps &&
          msg.time.isNotEmpty &&
          (!options.showSenderNames || !isNewSenderGroup);

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                msg.body,
                style: AppTypography.editorBody.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (showIndividualTimestamp) ...[
                const SizedBox(height: 2),
                Text(
                  '${msg.date.isNotEmpty ? "${msg.date}, " : ""}${msg.time}',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary.withValues(alpha: 0.8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _formatDateHeader(String rawDate) {
    final parts = rawDate.split(RegExp(r'[/\.-]'));
    if (parts.length >= 2) {
      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      if (p1 != null && p2 != null) {
        int day = p1;
        int month = p2;
        if (p1 <= 12 && p2 > 12) {
          month = p1;
          day = p2;
        }
        if (month >= 1 && month <= 12) {
          const monthNames = [
            'JANUARY',
            'FEBRUARY',
            'MARCH',
            'APRIL',
            'MAY',
            'JUNE',
            'JULY',
            'AUGUST',
            'SEPTEMBER',
            'OCTOBER',
            'NOVEMBER',
            'DECEMBER',
          ];
          return '${monthNames[month - 1]} $day';
        }
      }
    }
    return rawDate.toUpperCase();
  }
}
