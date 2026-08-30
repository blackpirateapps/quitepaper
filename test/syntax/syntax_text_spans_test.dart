import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/syntax/domain/highlight_result.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';
import 'package:quitepaper/core/syntax/domain/syntax_theme.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token_type.dart';
import 'package:quitepaper/core/syntax/presentation/syntax_text_spans.dart';

void main() {
  final colors = AppColors.light;
  final theme = SyntaxTheme.fromColors(colors);
  const fallbackStyle = TextStyle(color: Colors.black, fontSize: 14);

  group('SyntaxTextSpans', () {
    test('builds styled TextSpan tree from highlight tokens without dropping characters', () {
      const source = 'final x = 42;';
      final tokens = [
        const SyntaxToken(start: 0, end: 5, type: SyntaxTokenType.keyword, text: 'final'),
        const SyntaxToken(start: 5, end: 10, type: SyntaxTokenType.plain, text: ' x = '),
        const SyntaxToken(start: 10, end: 12, type: SyntaxTokenType.number, text: '42'),
        const SyntaxToken(start: 12, end: 13, type: SyntaxTokenType.punctuation, text: ';'),
      ];
      final result = HighlightResult(
        language: const SyntaxLanguage(id: 'dart', name: 'Dart'),
        tokens: tokens,
        sourceLength: source.length,
      );

      final span = SyntaxTextSpans.buildTextSpan(
        text: source,
        highlightResult: result,
        theme: theme,
        fallbackStyle: fallbackStyle,
      );

      expect(span.toPlainText(), equals(source));
    });

    test('overlays search match highlights across token boundaries without mutating text', () {
      const source = 'final answer = 42; // answer variable';
      // Search for 'answer'
      final matchOffsets = [6, 22]; // offsets of 'answer'
      final tokens = [
        const SyntaxToken(start: 0, end: 5, type: SyntaxTokenType.keyword, text: 'final'),
        const SyntaxToken(start: 6, end: 12, type: SyntaxTokenType.variable, text: 'answer'),
        const SyntaxToken(start: 19, end: 37, type: SyntaxTokenType.comment, text: '// answer variable'),
      ];
      final result = HighlightResult(
        language: const SyntaxLanguage(id: 'dart', name: 'Dart'),
        tokens: tokens,
        sourceLength: source.length,
      );

      final span = SyntaxTextSpans.buildTextSpan(
        text: source,
        highlightResult: result,
        theme: theme,
        fallbackStyle: fallbackStyle,
        searchQuery: 'answer',
        searchMatchOffsets: matchOffsets,
        activeSearchMatchIndex: 0,
        searchHighlightStyle: const TextStyle(backgroundColor: Colors.yellow),
        activeSearchHighlightStyle: const TextStyle(backgroundColor: Colors.orange),
      );

      expect(span.toPlainText(), equals(source));
    });

    test('applies IME composing range underline decoration accurately', () {
      const source = 'final text = "typing";';
      final result = HighlightResult.plain(source: source);

      final span = SyntaxTextSpans.buildTextSpan(
        text: source,
        highlightResult: result,
        theme: theme,
        fallbackStyle: fallbackStyle,
        composingRange: const TextRange(start: 14, end: 20), // "typing"
      );

      expect(span.toPlainText(), equals(source));
    });
  });
}
