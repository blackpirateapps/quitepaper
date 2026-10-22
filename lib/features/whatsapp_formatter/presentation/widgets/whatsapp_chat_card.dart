import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/whatsapp_chat_helper.dart';
import '../../application/whatsapp_preferences_provider.dart';
import '../../domain/whatsapp_format_options.dart';
import '../../domain/whatsapp_parse_result.dart';
import 'whatsapp_conversation_preview.dart';

/// An embedded card widget rendering a WhatsApp conversation with full editorial styling
/// (terracotta sender labels, date dividers, timestamps, and message grouping)
/// matching the approved design mockup and preview interface.
class WhatsAppChatCard extends ConsumerStatefulWidget {
  const WhatsAppChatCard({
    super.key,
    this.source,
    this.parseResult,
    this.options,
    this.readOnly = false,
    this.onRemove,
    this.onOptions,
  });

  /// Raw or formatted chat text (parsed via [WhatsAppChatHelper]).
  final String? source;

  /// Optional pre-computed parse result.
  final WhatsAppParseResult? parseResult;

  /// Optional pre-computed format options.
  final WhatsAppFormatOptions? options;

  /// Whether the card is embedded in a read-only surface.
  final bool readOnly;

  /// Optional callback to delete/remove this block in an active editor.
  final VoidCallback? onRemove;

  /// Optional callback to reconfigure options in preview screen.
  final VoidCallback? onOptions;

  @override
  ConsumerState<WhatsAppChatCard> createState() => _WhatsAppChatCardState();
}

class _WhatsAppChatCardState extends ConsumerState<WhatsAppChatCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final defaultOptions = ref.watch(whatsappFormatOptionsProvider);

    final WhatsAppParseResult effectiveResult;
    final WhatsAppFormatOptions effectiveOptions;

    if (widget.parseResult != null) {
      effectiveResult = widget.parseResult!;
      effectiveOptions = widget.options ?? defaultOptions;
    } else if (widget.source != null && widget.source!.isNotEmpty) {
      final parsed = WhatsAppChatHelper.parseContent(
        widget.source!,
        defaultOptions: widget.options ?? defaultOptions,
      );
      effectiveResult = parsed.result;
      effectiveOptions = parsed.options;
    } else {
      return const SizedBox.shrink();
    }

    final messageCount = effectiveResult.messages.where((m) => !m.isUnrecognized).length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(
                  color: colors.divider.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // Green WhatsApp pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 13,
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'WhatsApp',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF25D366),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$messageCount messages',
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // Options Action (re-open preview options)
                if (widget.onOptions != null) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: widget.onOptions,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Options',
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Copy Action
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    final textToCopy = effectiveResult.originalText.isNotEmpty
                        ? effectiveResult.originalText
                        : widget.source ?? '';
                    await Clipboard.setData(ClipboardData(text: textToCopy));
                    if (!mounted) return;
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 13,
                          color: _copied ? colors.accent : colors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: AppTypography.caption.copyWith(
                            color: _copied ? colors.accent : colors.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Remove Action (if editable and provided)
                if (!widget.readOnly && widget.onRemove != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: widget.onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Conversation Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: WhatsAppConversationPreview(
              parseResult: effectiveResult,
              options: effectiveOptions,
            ),
          ),
        ],
      ),
    );
  }
}
