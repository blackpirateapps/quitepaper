import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/markdown_styles.dart';
import 'markdown_parser.dart';

/// A [TextEditingController] that dynamically styles Markdown syntax into a rich
/// [TextSpan] tree without modifying the underlying source Markdown text.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({
    super.text,
    this.styles,
  });

  /// Optional static styles override. If null, styles will dynamically adapt to
  /// the active [AppColors] from the build context.
  MarkdownStyles? styles;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyles = styles ??
        MarkdownStyles.fromColors(
          context.appColors,
          baseStyle: style,
        );

    final composingRange =
        (withComposing && value.isComposingRangeValid) ? value.composing : null;

    return MarkdownParser.buildTextSpan(
      text: text,
      styles: effectiveStyles,
      composingRange: composingRange,
    );
  }
}
