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
    this._searchQuery,
    this._activeSearchRange,
  });

  /// Optional static styles override. If null, styles will dynamically adapt to
  /// the active [AppColors] from the build context.
  MarkdownStyles? styles;

  String? _searchQuery;
  String? get searchQuery => _searchQuery;
  set searchQuery(String? value) {
    if (_searchQuery != value) {
      _searchQuery = value;
      notifyListeners();
    }
  }

  TextRange? _activeSearchRange;
  TextRange? get activeSearchRange => _activeSearchRange;
  set activeSearchRange(TextRange? value) {
    if (_activeSearchRange != value) {
      _activeSearchRange = value;
      notifyListeners();
    }
  }

  void setSearchHighlight({
    required String? query,
    required TextRange? activeRange,
  }) {
    if (_searchQuery != query || _activeSearchRange != activeRange) {
      _searchQuery = query;
      _activeSearchRange = activeRange;
      notifyListeners();
    }
  }

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
      searchQuery: _searchQuery,
      activeSearchRange: _activeSearchRange,
    );
  }
}
