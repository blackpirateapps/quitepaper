import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../app/theme/app_colors.dart';

/// Markdown syntax rule to match `==highlighted text==` and parse into `<mark>` AST nodes.
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==([^=\n\r]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[1]!;
    final el = md.Element.text('mark', text);
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<mark>` tags produced by [HighlightSyntax].
/// Renders a soft warm highlight background container matching Quiet Paper's aesthetic.
class HighlightElementBuilder extends MarkdownElementBuilder {
  HighlightElementBuilder(this.colors);

  final AppColors colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final effectiveStyle = (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        element.textContent,
        style: effectiveStyle,
      ),
    );
  }
}

/// Markdown syntax rule to match a search query and parse into `<searchmark>` AST nodes.
class SearchMatchSyntax extends md.InlineSyntax {
  SearchMatchSyntax(String query)
      : super(RegExp.escape(query), caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[0]!;
    final el = md.Element.text('searchmark', text);
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<searchmark>` tags.
class SearchMatchElementBuilder extends MarkdownElementBuilder {
  SearchMatchElementBuilder(this.colors);

  final AppColors colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final isDark = colors.background.computeLuminance() < 0.5;
    final effectiveStyle =
        (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
      color: isDark ? const Color(0xFFFFFAED) : const Color(0xFF242018),
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7A5C1E) : const Color(0xFFFFE066),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        element.textContent,
        style: effectiveStyle,
      ),
    );
  }
}
