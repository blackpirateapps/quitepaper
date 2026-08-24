import 'package:flutter/foundation.dart';

/// Compiled representation of a search query with FTS5-safe expressions.
@immutable
class CompiledSearchQuery {
  final String rawQuery;
  final String cleanQuery;
  final List<String> tokens;
  final String ftsPrefixExpression;
  final String ftsTrigramExpression;
  final bool isTrigramEligible;
  final bool isExactPhraseCandidate;

  const CompiledSearchQuery({
    required this.rawQuery,
    required this.cleanQuery,
    required this.tokens,
    required this.ftsPrefixExpression,
    required this.ftsTrigramExpression,
    required this.isTrigramEligible,
    required this.isExactPhraseCandidate,
  });

  bool get isEmpty => tokens.isEmpty;
  bool get isNotEmpty => tokens.isNotEmpty;

  static const CompiledSearchQuery empty = CompiledSearchQuery(
    rawQuery: '',
    cleanQuery: '',
    tokens: [],
    ftsPrefixExpression: '',
    ftsTrigramExpression: '',
    isTrigramEligible: false,
    isExactPhraseCandidate: false,
  );
}

/// Deterministic query compiler and tokenizer for FTS5 and fuzzy matching.
class SearchTokenizer {
  const SearchTokenizer();

  /// Tokenizes an input string into clean lowercased search terms.
  static List<String> tokenize(String input) {
    if (input.trim().isEmpty) return const [];

    final clean = input.toLowerCase();
    final matches = RegExp(r'[\w#]+').allMatches(clean);
    final tokens = <String>[];

    for (final m in matches) {
      final t = m.group(0)?.trim() ?? '';
      if (t.isNotEmpty) {
        tokens.add(t);
      }
    }
    return tokens;
  }

  /// Escapes a token for safe inclusion in SQLite FTS5 queries without syntax injection.
  static String escapeFts5Token(String token) {
    // Remove characters that could break FTS5 expression grammar
    final sanitized = token
        .replaceAll('"', '')
        .replaceAll('*', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll(':', '')
        .replaceAll('^', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('-', '')
        .trim();

    if (sanitized.isEmpty) return '';

    // If token matches reserved FTS5 operator, escape in double quotes
    return '"$sanitized"';
  }

  /// Compiles a raw user search query into deterministic FTS expressions.
  static CompiledSearchQuery compileQuery(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return CompiledSearchQuery.empty;

    final clean = trimmed.toLowerCase();
    final tokens = tokenize(clean);
    if (tokens.isEmpty) return CompiledSearchQuery.empty;

    // 1. Build prefix expression for unicode61 FTS: e.g. "sync"* "note"*
    final prefixParts = <String>[];
    for (final t in tokens) {
      final cleanToken = t.replaceAll(RegExp(r'^#'), '');
      if (cleanToken.isEmpty) continue;
      final escaped = escapeFts5Token(cleanToken);
      if (escaped.isNotEmpty) {
        prefixParts.add('$escaped*');
      }
    }
    final ftsPrefixExpression = prefixParts.join(' ');

    // 2. Build trigram expression for trigram FTS:
    // Trigram index supports exact/substring matches for tokens of length >= 3
    final trigramParts = <String>[];
    for (final t in tokens) {
      final cleanToken = t.replaceAll(RegExp(r'^#'), '');
      if (cleanToken.length >= 3) {
        final escaped = escapeFts5Token(cleanToken);
        if (escaped.isNotEmpty) {
          trigramParts.add(escaped);
        }
      }
    }
    final ftsTrigramExpression = trigramParts.join(' ');
    final isTrigramEligible = trigramParts.isNotEmpty;

    return CompiledSearchQuery(
      rawQuery: rawQuery,
      cleanQuery: clean,
      tokens: tokens,
      ftsPrefixExpression: ftsPrefixExpression,
      ftsTrigramExpression: ftsTrigramExpression,
      isTrigramEligible: isTrigramEligible,
      isExactPhraseCandidate: tokens.length > 1,
    );
  }
}
