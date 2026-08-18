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
