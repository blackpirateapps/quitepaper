import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../utils/font_family_helper.dart';
import '../text/attachment_text_detector.dart';

/// Read-only plain text viewer with line numbers, word wrap toggle, search highlight matching,
/// selectable text, and theme-adaptive typography.
class PlainTextViewer extends ConsumerStatefulWidget {
  const PlainTextViewer({
    super.key,
    required this.text,
    this.format = TextAttachmentFormat.plainText,
    this.isMonospaced,
    this.showLineNumbers,
    this.wordWrap,
    this.searchQuery,
    this.currentMatchIndex = 0,
    this.onMatchesCountChanged,
    this.scrollController,
  });

  final String text;
  final TextAttachmentFormat format;
  final bool? isMonospaced;
  final bool? showLineNumbers;
  final bool? wordWrap;
  final String? searchQuery;
  final int currentMatchIndex;
  final ValueChanged<int>? onMatchesCountChanged;
  final ScrollController? scrollController;

  @override
  ConsumerState<PlainTextViewer> createState() => _PlainTextViewerState();
}

class _PlainTextViewerState extends ConsumerState<PlainTextViewer> {
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;
  final List<int> _matchOffsets = [];

  @override
  void initState() {
    super.initState();
    _verticalScrollController = widget.scrollController ?? ScrollController();
    _horizontalScrollController = ScrollController();
    _computeMatches();
  }

  @override
  void didUpdateWidget(PlainTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery || oldWidget.text != widget.text) {
      _computeMatches();
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _verticalScrollController.dispose();
    }
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _computeMatches() {
    _matchOffsets.clear();
    final query = widget.searchQuery?.trim();
    if (query != null && query.isNotEmpty && widget.text.isNotEmpty) {
      final lowerText = widget.text.toLowerCase();
      final lowerQuery = query.toLowerCase();
      int start = 0;
      while (start < lowerText.length) {
        final idx = lowerText.indexOf(lowerQuery, start);
        if (idx == -1) break;
        _matchOffsets.add(idx);
        start = idx + lowerQuery.length;
      }
    }

    widget.onMatchesCountChanged?.call(_matchOffsets.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);

    final isMono = widget.isMonospaced ?? AttachmentTextDetector.isMonospaced(widget.format);
    final showLineNums = widget.showLineNumbers ?? AttachmentTextDetector.supportsLineNumbers(widget.format);
    final wrap = widget.wordWrap ?? AttachmentTextDetector.defaultWordWrap(widget.format);

    final fontFamily = isMono
        ? (typography.codeFontFamily ?? 'monospace')
        : typography.bodyFontFamily;
    final fontSize = isMono ? typography.scaledCodeSize : typography.fontSize;
    final lineHeight = typography.lineHeight;
    final baseLetterSpacing = typography.letterSpacing;

    final baseTextStyle = FontFamilyHelper.getTextStyle(
      fontFamily: fontFamily,
      baseStyle: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: baseLetterSpacing,
        color: colors.textPrimary,
      ),
    );

    if (widget.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 40, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Empty file',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final lines = widget.text.split('\n');
    final lineCount = lines.length;
    final gutterWidth = _calculateGutterWidth(lineCount, fontSize);

    // Build the TextSpan tree with search highlights
    final textSpan = _buildHighlightedTextSpan(
      widget.text,
      baseTextStyle,
      colors,
      widget.searchQuery?.trim(),
      widget.currentMatchIndex,
    );

    Widget content = SelectableText.rich(
      textSpan,
      style: baseTextStyle,
    );

    if (!wrap) {
      content = SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }

    return SingleChildScrollView(
      controller: _verticalScrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Line Numbers Gutter (presentation-only, side-by-side)
          if (showLineNums)
            Container(
              width: gutterWidth,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                border: Border(
                  right: BorderSide(color: colors.divider.withValues(alpha: 0.6), width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 1; i <= lineCount; i++)
                    SizedBox(
                      height: fontSize * lineHeight,
                      child: Text(
                        '$i',
                        style: FontFamilyHelper.getTextStyle(
                          fontFamily: typography.codeFontFamily ?? 'monospace',
                          baseStyle: TextStyle(
                            fontSize: fontSize * 0.88,
                            height: lineHeight,
                            color: colors.textTertiary,
                          ),
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ),

          // 2. Main Selectable Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 120.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateGutterWidth(int lineCount, double fontSize) {
    final digits = lineCount.toString().length;
    final charWidth = fontSize * 0.65;
    return (digits * charWidth) + 20.0;
  }

  TextSpan _buildHighlightedTextSpan(
    String fullText,
    TextStyle baseStyle,
    AppColors colors,
    String? query,
    int activeMatchIndex,
  ) {
    if (query == null || query.isEmpty || _matchOffsets.isEmpty) {
      return TextSpan(text: fullText, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int currentPos = 0;
    final queryLen = query.length;

    for (int matchIdx = 0; matchIdx < _matchOffsets.length; matchIdx++) {
      final matchStart = _matchOffsets[matchIdx];

      // Add preceding plain text
      if (matchStart > currentPos) {
        spans.add(TextSpan(
          text: fullText.substring(currentPos, matchStart),
          style: baseStyle,
        ));
      }

      final isCurrent = matchIdx == activeMatchIndex;
      final matchText = fullText.substring(matchStart, matchStart + queryLen);

      // Highlighted match using native TextStyle backgroundColor
      spans.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(
            backgroundColor: isCurrent
                ? colors.accent.withValues(alpha: 0.55)
                : colors.accent.withValues(alpha: 0.25),
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      );

      currentPos = matchStart + queryLen;
    }

    // Add any remaining text
    if (currentPos < fullText.length) {
      spans.add(TextSpan(
        text: fullText.substring(currentPos),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}
