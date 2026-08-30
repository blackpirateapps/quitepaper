import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../syntax/application/syntax_provider.dart';
import '../../syntax/domain/syntax_theme.dart';
import '../../syntax/presentation/syntax_text_spans.dart';
import '../../utils/font_family_helper.dart';
import '../text/attachment_text_detector.dart';

/// Read-only plain text and source code viewer with line numbers, word wrap toggle,
/// syntax highlighting, search highlight matching, selectable text, and theme-adaptive typography.
class PlainTextViewer extends ConsumerStatefulWidget {
  const PlainTextViewer({
    super.key,
    required this.text,
    this.format = TextAttachmentFormat.plainText,
    this.fileName,
    this.mimeType,
    this.overrideLanguageId,
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
  final String? fileName;
  final String? mimeType;
  final String? overrideLanguageId;
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

    // 1. Resolve syntax language
    final resolver = ref.watch(syntaxLanguageResolverProvider);
    final language = resolver.resolveForAttachment(
      overrideLanguageId: widget.overrideLanguageId,
      mimeType: widget.mimeType,
      fileName: widget.fileName,
    );

    final isMono = widget.isMonospaced ??
        (language.isSupported || AttachmentTextDetector.isMonospaced(widget.format));
    final showLineNums = widget.showLineNumbers ??
        (language.isSupported || AttachmentTextDetector.supportsLineNumbers(widget.format));
    final wrap = widget.wordWrap ??
        (language.isSupported ? false : AttachmentTextDetector.defaultWordWrap(widget.format));

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

    // 2. Perform syntax highlighting if language is supported
    final highlighter = ref.watch(syntaxHighlighterProvider);
    final hlResult = highlighter.highlight(source: widget.text, language: language);

    final syntaxTheme = SyntaxTheme.fromColors(
      colors,
      typography: typography,
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: baseLetterSpacing,
    );

    final isDark = colors.background.computeLuminance() < 0.5;

    // 3. Build the TextSpan tree with syntax tokens and search overlays
    final textSpan = SyntaxTextSpans.buildTextSpan(
      text: widget.text,
      highlightResult: hlResult,
      theme: syntaxTheme,
      fallbackStyle: baseTextStyle,
      searchQuery: widget.searchQuery?.trim(),
      activeSearchMatchIndex: widget.currentMatchIndex,
      searchMatchOffsets: _matchOffsets,
      searchHighlightStyle: TextStyle(
        backgroundColor: isDark ? const Color(0xFF7A5C1E) : const Color(0xFFFFE066),
        color: isDark ? const Color(0xFFFFFAED) : const Color(0xFF242018),
        fontWeight: FontWeight.w500,
      ),
      activeSearchHighlightStyle: TextStyle(
        backgroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
        color: isDark ? const Color(0xFF1E1B13) : const Color(0xFF1A1810),
        fontWeight: FontWeight.w800,
      ),
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
}
