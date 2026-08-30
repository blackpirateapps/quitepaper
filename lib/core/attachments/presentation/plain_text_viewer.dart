import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../syntax/application/syntax_provider.dart';
import '../../syntax/domain/syntax_theme.dart';
import '../../syntax/presentation/syntax_text_spans.dart';
import '../../utils/font_family_helper.dart';
import '../../widgets/quiet_button.dart';
import '../text/attachment_text_detector.dart';

/// Read-only plain text and source code viewer with 1,000-line progressive chunked loading,
/// line numbers, word wrap toggle, syntax highlighting, full-document global search matching,
/// selectable text, and theme-adaptive typography.
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
  static const int kLinesPerChunk = 1000;

  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;
  final List<int> _lineStarts = [];
  int _totalLineCount = 0;
  int _loadedLineCount = kLinesPerChunk;
  final List<int> _matchOffsets = [];

  @override
  void initState() {
    super.initState();
    _verticalScrollController = widget.scrollController ?? ScrollController();
    _horizontalScrollController = ScrollController();
    _verticalScrollController.addListener(_onScroll);
    _initLineIndexing();
    _computeMatches();
    if (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty) {
      _scrollToMatch(widget.currentMatchIndex);
    }
  }

  @override
  void didUpdateWidget(PlainTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final textChanged = oldWidget.text != widget.text;
    final queryChanged = oldWidget.searchQuery != widget.searchQuery;
    final matchIndexChanged = oldWidget.currentMatchIndex != widget.currentMatchIndex;

    if (textChanged) {
      _initLineIndexing();
      _computeMatches();
    } else if (queryChanged) {
      _computeMatches();
    }

    if (queryChanged || matchIndexChanged) {
      _scrollToMatch(widget.currentMatchIndex);
    }
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _verticalScrollController.dispose();
    }
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _initLineIndexing() {
    _lineStarts.clear();
    final text = widget.text;
    if (text.isEmpty) {
      _totalLineCount = 0;
      _loadedLineCount = 0;
      return;
    }

    _lineStarts.add(0);
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        _lineStarts.add(i + 1);
      }
    }
    _totalLineCount = _lineStarts.length;
    _loadedLineCount = min(kLinesPerChunk, _totalLineCount);
  }

  void _onScroll() {
    if (!_verticalScrollController.hasClients) return;
    if (_verticalScrollController.position.extentAfter < 600 && _loadedLineCount < _totalLineCount) {
      _loadNextChunk();
    }
  }

  void _loadNextChunk() {
    if (_loadedLineCount >= _totalLineCount) return;
    setState(() {
      _loadedLineCount = min(_loadedLineCount + kLinesPerChunk, _totalLineCount);
    });
  }

  void _loadAll() {
    if (_loadedLineCount >= _totalLineCount) return;
    setState(() {
      _loadedLineCount = _totalLineCount;
    });
  }

  int _findLineForOffset(int offset) {
    if (_lineStarts.isEmpty) return 0;
    int low = 0;
    int high = _lineStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_lineStarts[mid] == offset) {
        return mid;
      } else if (_lineStarts[mid] < offset) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return high.clamp(0, _lineStarts.length - 1);
  }

  void _scrollToMatch(int matchIndex) {
    if (_matchOffsets.isEmpty || matchIndex < 0 || matchIndex >= _matchOffsets.length) return;
    final matchOffset = _matchOffsets[matchIndex];
    final matchLine = _findLineForOffset(matchOffset);

    // Expand loaded lines if match is beyond current window
    if (matchLine >= _loadedLineCount) {
      final neededLines = min(((matchLine ~/ kLinesPerChunk) + 1) * kLinesPerChunk, _totalLineCount);
      if (mounted) {
        setState(() {
          _loadedLineCount = neededLines;
        });
      } else {
        _loadedLineCount = neededLines;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalScrollController.hasClients) return;
      final typography = ref.read(typographySettingsProvider);
      final isMono = widget.isMonospaced ?? true;
      final fontSize = isMono ? typography.scaledCodeSize : typography.fontSize;
      final lineHeight = typography.lineHeight;
      final targetY = matchLine * (fontSize * lineHeight);
      final maxScroll = _verticalScrollController.position.maxScrollExtent;
      final clampedY = (targetY - 80.0).clamp(0.0, maxScroll);
      _verticalScrollController.animateTo(
        clampedY,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
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

    // Determine the rendered text slice according to _loadedLineCount
    final String renderedText;
    final int renderedLineCount = _loadedLineCount;
    if (_loadedLineCount >= _totalLineCount) {
      renderedText = widget.text;
    } else {
      final endOffset = _loadedLineCount < _lineStarts.length ? _lineStarts[_loadedLineCount] : widget.text.length;
      renderedText = widget.text.substring(0, endOffset);
    }

    final gutterWidth = _calculateGutterWidth(_totalLineCount, fontSize);

    // 2. Perform syntax highlighting if language is supported
    final highlighter = ref.watch(syntaxHighlighterProvider);
    final hlResult = highlighter.highlight(source: renderedText, language: language);

    final syntaxTheme = SyntaxTheme.fromColors(
      colors,
      typography: typography,
      fontFamily: fontFamily,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: baseLetterSpacing,
    );

    final isDark = colors.background.computeLuminance() < 0.5;

    // 3. Filter match offsets to only those present in the visible slice
    final visibleMatchOffsets = _matchOffsets.where((o) => o < renderedText.length).toList();

    // 4. Build the TextSpan tree with syntax tokens and search overlays
    final textSpan = SyntaxTextSpans.buildTextSpan(
      text: renderedText,
      highlightResult: hlResult,
      theme: syntaxTheme,
      fallbackStyle: baseTextStyle,
      searchQuery: widget.searchQuery?.trim(),
      activeSearchMatchIndex: widget.currentMatchIndex,
      searchMatchOffsets: visibleMatchOffsets,
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
                  for (int i = 1; i <= renderedLineCount; i++)
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
                  _buildChunkFooter(colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChunkFooter(AppColors colors) {
    if (_loadedLineCount >= _totalLineCount) {
      return const SizedBox(height: 120.0);
    }

    final percent = ((_loadedLineCount / _totalLineCount) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 120.0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: colors.divider, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, size: 18, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Showing ${_formatNumber(_loadedLineCount)} of ${_formatNumber(_totalLineCount)} lines ($percent%)',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scroll down to load more lines automatically, or load in batches below.',
              style: AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                QuietButton(
                  label: 'Load next 1,000 lines',
                  icon: Icons.expand_more_rounded,
                  variant: QuietButtonVariant.secondary,
                  onPressed: _loadNextChunk,
                ),
                QuietButton(
                  label: 'Load all lines',
                  icon: Icons.unfold_more_rounded,
                  variant: QuietButtonVariant.ghost,
                  onPressed: _loadAll,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  double _calculateGutterWidth(int lineCount, double fontSize) {
    final digits = lineCount.toString().length;
    final charWidth = fontSize * 0.65;
    return (digits * charWidth) + 20.0;
  }
}
