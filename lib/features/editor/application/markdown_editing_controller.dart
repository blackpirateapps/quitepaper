import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/syntax/application/syntax_highlighter.dart';
import '../../../core/syntax/application/syntax_language_resolver.dart';
import '../domain/markdown_styles.dart';
import 'markdown_formatter.dart';
import 'markdown_parser.dart';

/// A [TextEditingController] that dynamically styles Markdown syntax into a rich
/// [TextSpan] tree without modifying the underlying source Markdown text.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({
    super.text,
    this.styles,
    this.maxStyledCharacters = MarkdownParser.defaultMaxStyledCharacters,
    this.syntaxHighlighter,
    this.syntaxLanguageResolver,
    this._searchQuery,
    this._activeSearchRange,
  });

  /// Optional static styles override. If null, styles will dynamically adapt to
  /// the active [AppColors] from the build context.
  MarkdownStyles? styles;

  /// Optional syntax highlighter override.
  SyntaxHighlighter? syntaxHighlighter;

  /// Optional syntax language resolver override.
  SyntaxLanguageResolver? syntaxLanguageResolver;

  /// Maximum character count threshold for full AST Markdown styling.
  int maxStyledCharacters;

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

  /// Checks if bold formatting is active at current selection or cursor.
  bool get isBoldActive => MarkdownFormatter.isBoldAt(value);

  /// Checks if italic formatting is active at current selection or cursor.
  bool get isItalicActive => MarkdownFormatter.isItalicAt(value);

  /// Checks if strikethrough formatting is active at current selection or cursor.
  bool get isStrikethroughActive => MarkdownFormatter.isStrikethroughAt(value);

  /// Checks if inline code formatting is active at current selection or cursor.
  bool get isInlineCodeActive => MarkdownFormatter.isInlineCodeAt(value);

  /// Checks if heading formatting is active at current selection or cursor.
  bool get isHeadingActive => MarkdownFormatter.isHeadingAt(value);

  /// Checks if checklist formatting is active at current selection or cursor.
  bool get isChecklistActive => MarkdownFormatter.isChecklistAt(value);

  /// Checks if bullet list formatting is active at current selection or cursor.
  bool get isBulletListActive => MarkdownFormatter.isBulletListAt(value);

  /// Checks if ordered list formatting is active at current selection or cursor.
  bool get isOrderedListActive => MarkdownFormatter.isOrderedListAt(value);

  /// Checks if blockquote formatting is active at current selection or cursor.
  bool get isQuoteActive => MarkdownFormatter.isQuoteAt(value);

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
      maxStyledCharacters: maxStyledCharacters,
      syntaxHighlighter: syntaxHighlighter,
      syntaxLanguageResolver: syntaxLanguageResolver,
    );
  }
}
