import 'package:flutter/foundation.dart';
import 'syntax_language.dart';
import 'syntax_token.dart';
import 'syntax_token_type.dart';

/// Immutable result of a syntax highlighting operation.
@immutable
class HighlightResult {
  const HighlightResult({
    required this.language,
    required this.sourceLength,
    required this.tokens,
    this.isSuccess = true,
  });

  /// The language used for highlighting.
  final SyntaxLanguage language;

  /// The total UTF-16 character length of the highlighted source.
  final int sourceLength;

  /// Semantic tokens extracted from the source.
  final List<SyntaxToken> tokens;

  /// Whether highlighting executed successfully without fallback/error.
  final bool isSuccess;

  /// Creates a fallback highlight result with a single plain-text token.
  factory HighlightResult.plain({
    required String source,
    SyntaxLanguage language = SyntaxLanguage.plainText,
  }) {
    return HighlightResult(
      language: language,
      sourceLength: source.length,
      tokens: [
        if (source.isNotEmpty)
          SyntaxToken(
            start: 0,
            end: source.length,
            type: SyntaxTokenType.plain,
            text: source,
          ),
      ],
      isSuccess: false,
    );
  }

  @override
  String toString() =>
      'HighlightResult(language: ${language.id}, length: $sourceLength, tokens: ${tokens.length}, success: $isSuccess)';
}
