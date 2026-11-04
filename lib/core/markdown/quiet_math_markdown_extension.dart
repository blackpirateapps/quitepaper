import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Markdown [md.InlineSyntax] for matching LaTeX inline math delimiters: `\( ... \)`.
class MathBracketInlineSyntax extends md.InlineSyntax {
  MathBracketInlineSyntax() : super(r'\\\(([\s\S]+?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final latex = match.group(1)?.trim() ?? '';
    final el = md.Element('math', [md.Text(latex)]);
    el.attributes['display'] = 'false';
    parser.addNode(el);
    return true;
  }
}

/// Markdown [md.InlineSyntax] for matching TeX inline math dollar delimiters: `$ ... $`.
class MathDollarInlineSyntax extends md.InlineSyntax {
  MathDollarInlineSyntax()
      : super(r'(?<!\$)\$(?!\$)([^\$\n]+?)(?<!\$)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final latex = match.group(1)?.trim() ?? '';
    final el = md.Element('math', [md.Text(latex)]);
    el.attributes['display'] = 'false';
    parser.addNode(el);
    return true;
  }
}

/// Markdown [md.BlockSyntax] for parsing display math blocks: `\[ ... \]` and `$$ ... $$`.
class MathBlockSyntax extends md.BlockSyntax {
  const MathBlockSyntax();

  static final RegExp _singleLineBracket =
      RegExp(r'^\s*\\\[([\s\S]*?)\\\]\s*$');
  static final RegExp _singleLineDollar =
      RegExp(r'^\s*\$\$([\s\S]*?)\$\$\s*$');

  @override
  RegExp get pattern => RegExp(r'^\s*(?:\\\[|\$\$)');

  @override
  md.Node parse(md.BlockParser parser) {
    final firstLine = parser.current.content;

    // Single-line bracket `\[ ... \]`
    final singleBracketMatch = _singleLineBracket.firstMatch(firstLine);
    if (singleBracketMatch != null) {
      parser.advance();
      final latex = singleBracketMatch.group(1)?.trim() ?? '';
      // Use md.Element.empty with tag 'mathblock' so no inlines are generated,
      // avoiding flutter_markdown's null parent inline assertion crashes.
      return md.Element.empty('mathblock')
        ..attributes['latex'] = latex
        ..attributes['display'] = 'true';
    }

    // Single-line dollar `$$ ... $$`
    final singleDollarMatch = _singleLineDollar.firstMatch(firstLine);
    if (singleDollarMatch != null) {
      parser.advance();
      final latex = singleDollarMatch.group(1)?.trim() ?? '';
      return md.Element.empty('mathblock')
        ..attributes['latex'] = latex
        ..attributes['display'] = 'true';
    }

    // Multi-line block
    final isBracket = firstLine.trim().startsWith(r'\[');
    final closingPattern = isBracket ? r'\]' : r'$$';
    final lines = <String>[];

    // Remove opening delimiter if on same line
    final openingDelimiter = isBracket ? r'\[' : r'$$';
    final remainingFirst =
        firstLine.trim().substring(openingDelimiter.length).trim();
    if (remainingFirst.isNotEmpty) {
      lines.add(remainingFirst);
    }
    parser.advance();

    while (!parser.isDone) {
      final currentLine = parser.current.content;
      final trimmed = currentLine.trim();
      if (trimmed.endsWith(closingPattern)) {
        final content =
            trimmed.substring(0, trimmed.length - closingPattern.length).trim();
        if (content.isNotEmpty) {
          lines.add(content);
        }
        parser.advance();
        break;
      }
      lines.add(currentLine);
      parser.advance();
    }

    final latex = lines.join('\n').trim();
    return md.Element.empty('mathblock')
      ..attributes['latex'] = latex
      ..attributes['display'] = 'true';
  }
}

/// Custom [MarkdownElementBuilder] for display math blocks (`<mathblock>`).
/// Explicitly marks [isBlockElement] as true so [MarkdownBuilder] in flutter_markdown
/// properly manages block containers without invoking `_addParentInlineIfNeeded`.
class QuietMathBlockElementBuilder extends MarkdownElementBuilder {
  QuietMathBlockElementBuilder({this.textStyle});

  final TextStyle? textStyle;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final latex = (element.attributes['latex'] ?? element.textContent).trim();
    final effectiveStyle = textStyle ?? preferredStyle;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Math.tex(
            latex,
            mathStyle: MathStyle.display,
            textStyle: effectiveStyle,
            onErrorFallback: (err) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                latex,
                style: (effectiveStyle ?? const TextStyle()).copyWith(
                  color: Colors.red,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom [MarkdownElementBuilder] that renders `<math>` elements with [Math.tex].
class QuietMathElementBuilder extends MarkdownElementBuilder {
  QuietMathElementBuilder({this.textStyle});

  final TextStyle? textStyle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final latex = (element.attributes['latex'] ?? element.textContent).trim();
    final isDisplay = element.attributes['display'] == 'true';
    final effectiveStyle = textStyle ?? preferredStyle;

    if (isDisplay) {
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Math.tex(
              latex,
              mathStyle: MathStyle.display,
              textStyle: effectiveStyle,
              onErrorFallback: (err) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  latex,
                  style: (effectiveStyle ?? const TextStyle()).copyWith(
                    color: Colors.red,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Math.tex(
        latex,
        mathStyle: MathStyle.text,
        textStyle: effectiveStyle,
        onErrorFallback: (err) => Text(
          latex,
          style: (effectiveStyle ?? const TextStyle()).copyWith(
            color: Colors.red,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
