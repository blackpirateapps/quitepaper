import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart' hide SyntaxHighlighter;
import 'package:markdown/markdown.dart' as md;
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../features/settings/domain/typography_settings.dart';
import '../syntax/application/syntax_highlighter.dart';
import '../syntax/application/syntax_language_resolver.dart';
import '../syntax/domain/highlight_result.dart';
import '../syntax/domain/syntax_theme.dart';
import '../syntax/presentation/syntax_text_spans.dart';
import '../utils/font_family_helper.dart';

/// A custom MarkdownElementBuilder for `<pre>` elements in [QuietMarkdownPreview].
/// Renders syntax-highlighted code blocks styled according to Quiet Paper's
/// warm editorial design philosophy, complete with a clean header bar displaying
/// the language name, an animated "Copy" button, and horizontal scrolling.
class QuietCodeBlockElementBuilder extends MarkdownElementBuilder {
  QuietCodeBlockElementBuilder({
    required this.colors,
    required this.typography,
    required this.highlighter,
    required this.resolver,
    this.searchQuery,
  });

  final AppColors colors;
  final TypographySettings typography;
  final SyntaxHighlighter highlighter;
  final SyntaxLanguageResolver resolver;
  final String? searchQuery;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return const SizedBox();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // 1. Locate the child <code> element inside <pre>
    md.Element? codeElement;
    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && child.tag == 'code') {
          codeElement = child;
          break;
        }
      }
    }

    // 2. Extract language identifier from class="language-..."
    String rawLanguage = '';
    if (codeElement != null && codeElement.attributes.containsKey('class')) {
      final classVal = codeElement.attributes['class']!;
      if (classVal.startsWith('language-')) {
        rawLanguage = classVal.substring('language-'.length);
      } else {
        rawLanguage = classVal;
      }
    }

    // 3. Extract source text (stripping single trailing newline if present)
    final rawSource = codeElement != null ? codeElement.textContent : element.textContent;
    final source = rawSource.replaceAll(RegExp(r'\n$'), '');

    // 4. Resolve language and highlight tokens
    final resolvedLang = resolver.resolveFromFence(rawLanguage.isNotEmpty ? rawLanguage : null);
    final HighlightResult hlResult;
    if (resolvedLang != null && resolvedLang.isSupported && source.isNotEmpty) {
      hlResult = highlighter.highlight(source: source, language: resolvedLang);
    } else {
      hlResult = HighlightResult.plain(source: source);
    }

    // 5. Build syntax text spans
    final syntaxTheme = SyntaxTheme.fromColors(colors, typography: typography);
    final codeFont = typography.codeFontFamily ?? 'monospace';
    final fallbackStyle = FontFamilyHelper.getTextStyle(
      fontFamily: codeFont,
      baseStyle: TextStyle(
        fontSize: typography.scaledCodeSize,
        height: typography.lineHeight,
        color: colors.textPrimary,
      ),
    );

    final textSpan = SyntaxTextSpans.buildTextSpan(
      text: source,
      highlightResult: hlResult,
      theme: syntaxTheme,
      fallbackStyle: fallbackStyle,
      searchQuery: searchQuery,
    );

    final displayName = resolvedLang?.name ?? (rawLanguage.isNotEmpty ? rawLanguage : 'Plain Text');

    return _QuietCodeBlockCard(
      languageName: displayName,
      source: source,
      textSpan: textSpan,
      colors: colors,
      typography: typography,
    );
  }
}

class _QuietCodeBlockCard extends StatelessWidget {
  const _QuietCodeBlockCard({
    required this.languageName,
    required this.source,
    required this.textSpan,
    required this.colors,
    required this.typography,
  });

  final String languageName;
  final String source;
  final TextSpan textSpan;
  final AppColors colors;
  final TypographySettings typography;

  @override
  Widget build(BuildContext context) {
    final codeFont = typography.codeFontFamily ?? 'monospace';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Editorial Header Bar
        Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4.0,
          ),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Language tag in uppercase
              Text(
                languageName.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.0,
                  letterSpacing: 0.8,
                ),
              ),
              // Copy button with feedback
              _CodeBlockCopyButton(
                source: source,
                colors: colors,
              ),
            ],
          ),
        ),

        // 2. Hairline separator
        Divider(
          height: 1.0,
          thickness: 0.8,
          color: colors.codeBorder.withValues(alpha: 0.6),
        ),

        // 3. Horizontally scrollable code body
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text.rich(
            textSpan,
            style: FontFamilyHelper.getTextStyle(
              fontFamily: codeFont,
              baseStyle: TextStyle(
                fontSize: typography.scaledCodeSize,
                height: typography.lineHeight,
                color: colors.codeText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeBlockCopyButton extends StatefulWidget {
  const _CodeBlockCopyButton({
    required this.source,
    required this.colors,
  });

  final String source;
  final AppColors colors;

  @override
  State<_CodeBlockCopyButton> createState() => _CodeBlockCopyButtonState();
}

class _CodeBlockCopyButtonState extends State<_CodeBlockCopyButton> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    HapticFeedback.lightImpact();

    if (!mounted) return;
    setState(() {
      _copied = true;
    });

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4.0),
        onTap: _handleCopy,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey<bool>(_copied),
                  size: 13.0,
                  color: _copied ? colors.accent : colors.textTertiary,
                ),
              ),
              const SizedBox(width: 4.0),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.caption.copyWith(
                  color: _copied ? colors.accent : colors.textTertiary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11.0,
                ),
                child: Text(_copied ? 'Copied' : 'Copy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
