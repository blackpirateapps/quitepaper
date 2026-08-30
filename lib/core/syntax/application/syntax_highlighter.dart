import '../domain/highlight_result.dart';
import '../domain/syntax_language.dart';

/// Abstract application-level syntax highlighter contract.
/// Isolates the rest of the application from third-party highlight engines.
abstract class SyntaxHighlighter {
  /// Monotonic version for cache invalidation when grammar mappings or versions change.
  static const int version = 1;

  /// Tokenizes [source] code into a [HighlightResult] containing semantic tokens.
  HighlightResult highlight({
    required String source,
    required SyntaxLanguage language,
  });
}
