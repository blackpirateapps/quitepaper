import 'dart:math';

/// Representation of a highlightable text span with character offsets
class TokenSpan {
  final int start;
  final int end;
  final bool isExact;

  const TokenSpan({
    required this.start,
    required this.end,
    required this.isExact,
  });
}

/// Result of matching a query against a text segment
class TextMatchResult {
  final double score;
  final int matchedTokensCount;
  final bool isFuzzy;
  final bool hasExactPhrase;
  final List<TokenSpan> highlightSpans;
  final String snippet;

  const TextMatchResult({
    required this.score,
    required this.matchedTokensCount,
    required this.isFuzzy,
    required this.hasExactPhrase,
    required this.highlightSpans,
    required this.snippet,
  });

  static const TextMatchResult none = TextMatchResult(
    score: 0.0,
    matchedTokensCount: 0,
    isFuzzy: false,
    hasExactPhrase: false,
    highlightSpans: [],
    snippet: '',
  );

  bool get hasMatch => score > 0.0;
}

/// High-performance fuzzy and multi-token search engine with adaptive edit distance
/// and relevance scoring.
class FuzzySearchEngine {
  const FuzzySearchEngine();

  /// Computes Damerau-Levenshtein distance (insertions, deletions, substitutions, transpositions)
  static int damerauLevenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;

    final d = List.generate(la + 1, (_) => List<int>.filled(lb + 1, 0));

    for (var i = 0; i <= la; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= lb; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= la; i++) {
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        var minVal = min(
          d[i - 1][j] + 1, // deletion
          min(
            d[i][j - 1] + 1, // insertion
            d[i - 1][j - 1] + cost, // substitution
          ),
        );

        // Transposition check
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          minVal = min(minVal, d[i - 2][j - 2] + 1);
        }

        d[i][j] = minVal;
      }
    }

    return d[la][lb];
  }

  /// Returns maximum allowable edit distance based on token length:
  /// - 1-3 chars: 0 (exact match only)
  /// - 4-6 chars: 1 typo allowed
  /// - 7+ chars: 2 typos allowed
  static int maxAllowedEditDistance(int tokenLength) {
    if (tokenLength <= 3) return 0;
    if (tokenLength <= 6) return 1;
    return 2;
  }

  /// Tokenizes a string into lowercased search words
  static List<String> tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s#]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Evaluates query against a target text and calculates relevance score
  static TextMatchResult evaluate({
    required String query,
    required String text,
    bool isTitle = false,
    bool isTag = false,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty || text.trim().isEmpty) {
      return TextMatchResult.none;
    }

    final queryTokens = tokenize(cleanQuery);
    if (queryTokens.isEmpty) return TextMatchResult.none;

    final lowerText = text.toLowerCase();
    double totalScore = 0.0;
    int matchedTokensCount = 0;
    bool hasFuzzy = false;
    bool hasExactPhrase = false;
    final spans = <TokenSpan>[];
    int? bestMatchOffset;

    // 1. Exact continuous phrase match bonus (especially for multi-word queries)
    final exactPhraseIdx = lowerText.indexOf(cleanQuery);
    if (exactPhraseIdx != -1) {
      hasExactPhrase = true;
      if (queryTokens.length > 1) {
        totalScore += isTitle ? 180.0 : (isTag ? 140.0 : 100.0);
      }
      spans.add(TokenSpan(
        start: exactPhraseIdx,
        end: exactPhraseIdx + cleanQuery.length,
        isExact: true,
      ));
      bestMatchOffset = exactPhraseIdx;
    }

    // 2. Tokenized word by word matching
    final wordRegex = RegExp(r'\b[\w#]+\b');
    final wordMatches = wordRegex.allMatches(text).toList();

    for (final qToken in queryTokens) {
      final cleanQToken = qToken.replaceAll(RegExp(r'^#'), '');
      if (cleanQToken.isEmpty) continue;

      final maxDistance = maxAllowedEditDistance(cleanQToken.length);
      bool tokenMatched = false;
      int bestDistance = 999;
      TokenSpan? bestSpanForToken;
      bool isExactTokenMatch = false;

      // First check substring containment in target text
      final subIdx = lowerText.indexOf(cleanQToken);
      if (subIdx != -1) {
        tokenMatched = true;
        isExactTokenMatch = true;
        bestSpanForToken = TokenSpan(
          start: subIdx,
          end: subIdx + cleanQToken.length,
          isExact: true,
        );
        bestMatchOffset ??= subIdx;
      } else {
        // Evaluate against distinct words using Damerau-Levenshtein
        for (final m in wordMatches) {
          final word = m.group(0)!.toLowerCase().replaceAll(RegExp(r'^#'), '');
          if (word.isEmpty) continue;

          // Prefix match check
          if (word.startsWith(cleanQToken)) {
            tokenMatched = true;
            isExactTokenMatch = true;
            bestSpanForToken = TokenSpan(
              start: m.start,
              end: m.start + cleanQToken.length,
              isExact: true,
            );
            bestMatchOffset ??= m.start;
            break;
          }

          // Infix match check
          if (word.contains(cleanQToken)) {
            tokenMatched = true;
            isExactTokenMatch = true;
            final inWordIdx = word.indexOf(cleanQToken);
            bestSpanForToken = TokenSpan(
              start: m.start + inWordIdx,
              end: m.start + inWordIdx + cleanQToken.length,
              isExact: true,
            );
            bestMatchOffset ??= m.start;
            break;
          }

          // Fuzzy edit distance check (only if length differences are within bound)
          if ((word.length - cleanQToken.length).abs() <= maxDistance) {
            final distance = damerauLevenshtein(cleanQToken, word);
            if (distance <= maxDistance && distance < bestDistance) {
              bestDistance = distance;
              tokenMatched = true;
              hasFuzzy = true;
              bestSpanForToken = TokenSpan(
                start: m.start,
                end: m.end,
                isExact: false,
              );
              bestMatchOffset ??= m.start;
            }
          }
        }
      }

      if (tokenMatched) {
        matchedTokensCount++;
        if (bestSpanForToken != null) {
          spans.add(bestSpanForToken);
        }

        if (isExactTokenMatch) {
          if (isTitle) {
            totalScore += 120.0;
          } else if (isTag) {
            totalScore += 100.0;
          } else {
            totalScore += 60.0;
          }
        } else {
          // Fuzzy match score scaled by distance
          final penalty = bestDistance * 15.0;
          if (isTitle) {
            totalScore += max(30.0, 90.0 - penalty);
          } else if (isTag) {
            totalScore += max(25.0, 75.0 - penalty);
          } else {
            totalScore += max(15.0, 45.0 - penalty);
          }
        }
      }
    }

    if (matchedTokensCount == 0 && totalScore == 0.0) {
      return TextMatchResult.none;
    }

    // Multi-token coverage bonus (rewards items containing more matching query terms)
    totalScore += matchedTokensCount * 50.0;
    if (matchedTokensCount == queryTokens.length) {
      totalScore += 80.0; // All query tokens matched bonus
    }

    // Extract context snippet
    final snippet = _extractSnippet(
      text: text,
      focusOffset: bestMatchOffset ?? 0,
      focusLength: cleanQuery.length,
    );

    return TextMatchResult(
      score: totalScore,
      matchedTokensCount: matchedTokensCount,
      isFuzzy: hasFuzzy,
      hasExactPhrase: hasExactPhrase,
      highlightSpans: spans,
      snippet: snippet,
    );
  }

  static String _extractSnippet({
    required String text,
    required int focusOffset,
    required int focusLength,
    int contextRadius = 40,
  }) {
    if (text.isEmpty) return '';

    final start = (focusOffset - contextRadius).clamp(0, text.length);
    final end = (focusOffset + focusLength + contextRadius).clamp(0, text.length);

    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';

    final raw = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    return '$prefix$raw$suffix';
  }
}
