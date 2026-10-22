import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../application/whatsapp_markdown_formatter.dart';
import '../application/whatsapp_preferences_provider.dart';
import '../domain/whatsapp_format_options.dart';
import '../domain/whatsapp_parse_result.dart';
import 'widgets/whatsapp_conversation_preview.dart';
import 'widgets/whatsapp_options_card.dart';

enum _WhatsAppPreviewTab { formatted, original }

/// Full interactive WhatsApp Formatter preview screen matching the design mockups.
class WhatsAppPreviewScreen extends ConsumerStatefulWidget {
  const WhatsAppPreviewScreen({
    super.key,
    required this.parseResult,
    required this.noteTitle,
    required this.onApply,
    this.onClose,
    this.onSwitchToEdit,
    this.isEmbedded = false,
  });

  final WhatsAppParseResult parseResult;
  final String noteTitle;
  final void Function(String formattedMarkdown, String? approvedTitle) onApply;
  final VoidCallback? onClose;
  final VoidCallback? onSwitchToEdit;
  final bool isEmbedded;

  @override
  ConsumerState<WhatsAppPreviewScreen> createState() =>
      _WhatsAppPreviewScreenState();
}

class _WhatsAppPreviewScreenState extends ConsumerState<WhatsAppPreviewScreen> {
  _WhatsAppPreviewTab _activeTab = _WhatsAppPreviewTab.formatted;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = ref.watch(whatsappFormatOptionsProvider);
    final optionsNotifier = ref.read(whatsappFormatOptionsProvider.notifier);

    final displayTitle = widget.noteTitle.trim().isNotEmpty &&
            widget.noteTitle.trim() != 'Untitled'
        ? widget.noteTitle
        : widget.parseResult.suggestedTitle;

    final subtitle =
        '${widget.parseResult.dateRangeLabel} · PERSONAL NOTE';

    final body = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Document Title & Subtitle Header
          Text(
            displayTitle,
            style: AppTypography.editorTitle.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),

          // 2. Detection Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSubtle.withValues(alpha: 0.5)
                  : colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 22,
                  color: colors.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp conversation detected',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.parseResult.messageCount} messages · ${widget.parseResult.participants.length} participants',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _activeTab = _activeTab == _WhatsAppPreviewTab.formatted
                          ? _WhatsAppPreviewTab.original
                          : _WhatsAppPreviewTab.formatted;
                    });
                  },
                  child: Text(
                    _activeTab == _WhatsAppPreviewTab.formatted
                        ? 'View source'
                        : 'View formatted',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Segmented Control / Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSubtle : colors.surfaceSubtle.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton(
                  title: 'Formatted conversation',
                  isSelected: _activeTab == _WhatsAppPreviewTab.formatted,
                  onTap: () {
                    setState(() {
                      _activeTab = _WhatsAppPreviewTab.formatted;
                    });
                  },
                  colors: colors,
                  isDark: isDark,
                ),
                _buildTabButton(
                  title: 'Original text',
                  isSelected: _activeTab == _WhatsAppPreviewTab.original,
                  onTap: () {
                    setState(() {
                      _activeTab = _WhatsAppPreviewTab.original;
                    });
                  },
                  colors: colors,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Content Area
          if (_activeTab == _WhatsAppPreviewTab.formatted) ...[
            // Options Box
            WhatsAppOptionsCard(
              options: options,
              onChanged: (updated) {
                optionsNotifier.setOptions(updated);
              },
            ),
            const SizedBox(height: 18),

            // Formatted Messages
            WhatsAppConversationPreview(
              parseResult: widget.parseResult,
              options: options,
            ),
          ] else ...[
            // Original Raw Text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSubtle : colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: SelectableText(
                widget.parseResult.originalText,
                style: AppTypography.editorBody.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  height: 1.5,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 80), // Padding above sticky footer
        ],
      ),
    );

    final content = Column(
      children: [
        Expanded(child: body),
        _buildStickyFooter(context, colors: colors, isDark: isDark, options: options),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close preview',
          onPressed: () {
            if (widget.onClose != null) {
              widget.onClose!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (widget.onSwitchToEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit raw note',
              onPressed: widget.onSwitchToEdit,
            ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors colors,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.surface : colors.background)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: AppTypography.caption.copyWith(
            color: isSelected ? colors.textPrimary : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStickyFooter(
    BuildContext context, {
    required AppColors colors,
    required bool isDark,
    required WhatsAppFormatOptions options,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          top: BorderSide(
            color: colors.divider.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.parseResult.originalText),
                  );
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Original text copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.divider.withValues(alpha: 0.8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Copy original',
                  style: AppTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final formattedMd = WhatsAppMarkdownFormatter.format(
                    widget.parseResult,
                    options: options,
                  );

                  Clipboard.setData(ClipboardData(text: formattedMd));

                  final suggestedTitle = widget.noteTitle.trim().isEmpty ||
                          widget.noteTitle.trim() == 'Untitled'
                      ? widget.parseResult.suggestedTitle
                      : null;

                  widget.onApply(formattedMd, suggestedTitle);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.textPrimary,
                  foregroundColor: colors.background,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(
                  'Apply format',
                  style: AppTypography.caption.copyWith(
                    color: colors.background,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Markdown · Remains fully editable',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                actionButtons,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Markdown · Remains fully editable',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              actionButtons,
            ],
          );
        },
      ),
    );
  }
}
