import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:super_editor/super_editor.dart';

import 'quiet_math_parser.dart';

/// Placeholder object stored in [AttributedText.placeholders] representing
/// a folded inline LaTeX math equation.
class InlineMathPlaceholder {
  const InlineMathPlaceholder({
    required this.latex,
    required this.isBracket,
    required this.rawStart,
    required this.rawEnd,
  });

  /// The raw LaTeX formula (e.g. `n=17`).
  final String latex;

  /// Whether this was delimited by `\(...\)` (true) or `$...$` (false).
  final bool isBracket;

  /// Start offset in canonical document text.
  final int rawStart;

  /// End offset in canonical document text.
  final int rawEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InlineMathPlaceholder &&
          runtimeType == other.runtimeType &&
          latex == other.latex &&
          isBracket == other.isBracket &&
          rawStart == other.rawStart &&
          rawEnd == other.rawEnd;

  @override
  int get hashCode => Object.hash(latex, isBracket, rawStart, rawEnd);
}

/// Factory for building [InlineMathWidget] when [computeInlineSpan] encounters
/// an [InlineMathPlaceholder].
Widget? inlineMathWidgetBuilder(
  BuildContext context,
  TextStyle textStyle,
  Object placeholder,
) {
  if (placeholder is! InlineMathPlaceholder) {
    return null;
  }

  return InlineMathWidget(
    latex: placeholder.latex,
    style: textStyle,
  );
}

/// Widget displaying a rendered inline LaTeX math equation using [Math.tex].
class InlineMathWidget extends StatelessWidget {
  const InlineMathWidget({
    super.key,
    required this.latex,
    required this.style,
    this.onTap,
  });

  final String latex;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mathWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Math.tex(
        latex,
        mathStyle: MathStyle.text,
        textStyle: style,
        onErrorFallback: (err) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            latex,
            style: style.copyWith(
              color: Colors.red,
              fontFamily: 'monospace',
              fontSize: style.fontSize != null ? style.fontSize! * 0.9 : null,
            ),
          ),
        ),
      ),
    );

    if (onTap == null) {
      return mathWidget;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: mathWidget,
      ),
    );
  }
}

/// Helper that folds inactive inline math matches in [canonicalText] into
/// [InlineMathPlaceholder]s, while leaving active matches (where caret resides)
/// unfolded for fluid direct editing.
AttributedText foldInlineMathText({
  required AttributedText canonicalText,
  required List<InlineMathMatch> matches,
  required int? caretOffset,
}) {
  if (matches.isEmpty) return canonicalText;

  // Determine which matches are active (caret is on/inside the formula).
  // Active matches remain unfolded as raw LaTeX text.
  final activeMatches = <InlineMathMatch>{};
  if (caretOffset != null) {
    for (final m in matches) {
      if (caretOffset >= m.start && caretOffset <= m.end) {
        activeMatches.add(m);
      }
    }
  }

  // If every match is active, no folding is needed.
  if (activeMatches.length == matches.length) {
    return canonicalText;
  }

  final plainText = canonicalText.toPlainText();
  final buffer = StringBuffer();
  final newPlaceholders = <int, Object>{};

  int cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      buffer.write(plainText.substring(cursor, match.start));
    }

    if (activeMatches.contains(match)) {
      // Unfolded: write raw characters verbatim.
      buffer.write(plainText.substring(match.start, match.end));
    } else {
      // Folded: register placeholder at current buffer length.
      // Note: AttributedText automatically inserts '\uFFFC' for each placeholder in toPlainText().
      final placeholderIndex = buffer.length;
      newPlaceholders[placeholderIndex] = InlineMathPlaceholder(
        latex: match.latex,
        isBracket: match.isBracket,
        rawStart: match.start,
        rawEnd: match.end,
      );
    }
    cursor = match.end;
  }

  if (cursor < plainText.length) {
    buffer.write(plainText.substring(cursor));
  }

  return AttributedText(
    buffer.toString(),
    null,
    newPlaceholders,
  );
}

/// Custom [ComponentBuilder] for SuperEditor that renders paragraphs containing
/// inline math with Bear/Typora-style folding.
class QuietMathParagraphComponentBuilder implements ComponentBuilder {
  QuietMathParagraphComponentBuilder(this._editor);

  final Editor _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode) return null;
    final plainText = node.text.toPlainText();
    final matches = QuietMathParser.findInlineMathMatches(plainText);
    if (matches.isEmpty) return null;

    int? caretOffset;
    final selection = _editor.composer.selection;
    if (selection != null &&
        selection.isCollapsed &&
        selection.extent.nodeId == node.id &&
        selection.extent.nodePosition is TextNodePosition) {
      caretOffset = (selection.extent.nodePosition as TextNodePosition).offset;
    }

    final displayText = foldInlineMathText(
      canonicalText: node.text,
      matches: matches,
      caretOffset: caretOffset,
    );

    final textDirection = getParagraphDirection(plainText);
    TextAlign textAlign = (textDirection == TextDirection.ltr)
        ? TextAlign.left
        : TextAlign.right;
    final textAlignName = node.getMetadataValue('textAlign');
    switch (textAlignName) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    return ParagraphComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      blockType: node.getMetadataValue(NodeMetadata.blockType),
      indent: node.indent,
      indentCalculator: defaultParagraphIndentCalculator,
      text: displayText,
      textStyleBuilder: noStyleBuilder,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ParagraphComponentViewModel) return null;

    final node = _editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! ParagraphNode) return null;

    return ParagraphComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
    );
  }
}

/// Custom [ComponentBuilder] for SuperEditor that renders list items containing
/// inline math with Bear/Typora-style folding.
class QuietMathListItemComponentBuilder implements ComponentBuilder {
  QuietMathListItemComponentBuilder(this._editor);

  final Editor _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ListItemNode) return null;
    final plainText = node.text.toPlainText();
    final matches = QuietMathParser.findInlineMathMatches(plainText);
    if (matches.isEmpty) return null;

    int? caretOffset;
    final selection = _editor.composer.selection;
    if (selection != null &&
        selection.isCollapsed &&
        selection.extent.nodeId == node.id &&
        selection.extent.nodePosition is TextNodePosition) {
      caretOffset = (selection.extent.nodePosition as TextNodePosition).offset;
    }

    final displayText = foldInlineMathText(
      canonicalText: node.text,
      matches: matches,
      caretOffset: caretOffset,
    );

    final textDirection = getParagraphDirection(plainText);
    TextAlign textAlign = (textDirection == TextDirection.ltr)
        ? TextAlign.left
        : TextAlign.right;

    if (node.type == ListItemType.unordered) {
      return UnorderedListItemComponentViewModel(
        nodeId: node.id,
        createdAt: node.metadata[NodeMetadata.createdAt],
        indent: node.indent,
        text: displayText,
        textStyleBuilder: noStyleBuilder,
        textDirection: textDirection,
        textAlignment: textAlign,
        selectionColor: const Color(0x00000000),
      );
    } else {
      return OrderedListItemComponentViewModel(
        nodeId: node.id,
        createdAt: node.metadata[NodeMetadata.createdAt],
        indent: node.indent,
        ordinalValue: 1,
        text: displayText,
        textStyleBuilder: noStyleBuilder,
        textDirection: textDirection,
        textAlignment: textAlign,
        selectionColor: const Color(0x00000000),
      );
    }
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is UnorderedListItemComponentViewModel) {
      return UnorderedListItemComponent(
        componentKey: componentContext.componentKey,
        text: componentViewModel.text,
        styleBuilder: componentViewModel.textStyleBuilder,
        indent: componentViewModel.indent,
        dotStyle: componentViewModel.dotStyle,
        textSelection: componentViewModel.selection,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    } else if (componentViewModel is OrderedListItemComponentViewModel) {
      return OrderedListItemComponent(
        componentKey: componentContext.componentKey,
        indent: componentViewModel.indent,
        listIndex: componentViewModel.ordinalValue ?? 1,
        text: componentViewModel.text,
        textDirection: componentViewModel.textDirection,
        textAlignment: componentViewModel.textAlignment,
        styleBuilder: componentViewModel.textStyleBuilder,
        numeralStyle: componentViewModel.numeralStyle,
        textSelection: componentViewModel.selection,
        selectionColor: componentViewModel.selectionColor,
        highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
        underlines: componentViewModel.createUnderlines(),
        inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      );
    }

    return null;
  }
}
