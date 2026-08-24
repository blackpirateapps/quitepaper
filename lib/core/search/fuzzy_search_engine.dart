import 'dart:math';
import 'markdown_offset_mapper.dart';
import 'search_models.dart';
import 'search_tokenizer.dart';

export 'search_models.dart';
export 'search_tokenizer.dart';

/// Representation of a highlightable text span with character offsets.
class TokenSpan {
  final int start;
  final int end;
  final bool isExact;

  const TokenSpan({
    required this.start,
    required this.end,
    required this.isExact,
  });

  TokenSpanDto toDto() => TokenSpanDto(start: start, end: end, isExact: isExact);
}

/// Result of matching a query against a text segment.
class TextMatchResult {
  final double score;
  final int matchedTokensCount;
  final bool isFuzzy;
  final bool hasExactPhrase;
  final List<TokenSpanDto> highlightSpans;
  final String snippet;
  final int? bestMatchOffset;
  final int? bestMatchLength;

  const TextMatchResult({
    required this.score,
    required this.matchedTokensCount,
    required this.isFuzzy,
    required this.hasExactPhrase,
    required this.highlightSpans,
    required this.snippet,
    this.bestMatchOffset,
    this.bestMatchLength,
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

/// High-performance, pure computational search & ranking engine.
///
/// Features bounded Damerau-Levenshtein calculation, zero-allocation row buffers,
/// multi-tier scoring hierarchy, and Markdown-safe offset mapping.
class FuzzySearchEngine {
  const FuzzySearchEngine();

  /// Calculates Damerau-Levenshtein distance with length pruning and zero 2D array allocation.
  static int damerauLevenshtein(String a, String b, {int maxDistance = 2}) {
    final la = a.length;
    final lb = b.length;

    if (la == 0) return lb <= maxDistance ? lb : maxDistance + 1;
    if (lb == 0) return la <= maxDistance ? la : maxDistance + 1;

    // 1. Length difference pruning
    if ((la - lb).abs() > maxDistance) {
      return maxDistance + 1;
    }

    // 2. Exact match fast path
    if (a == b) return 0;

    // 3. Fast single-row buffer allocation
    var prev2 = List<int>.filled(lb + 1, 0);
    var prev = List<int>.filled(lb + 1, 0);
    var curr = List<int>.filled(lb + 1, 0);

    for (var j = 0; j <= lb; j++) {
      prev[j] = j;
    }

    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      var minRowVal = curr[0];

      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        var val = min(
          prev[j] + 1, // deletion
          min(
            curr[j - 1] + 1, // insertion
            prev[j - 1] + cost, // substitution
          ),
        );

        // Transposition check
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1]) {
          val = min(val, prev2[j - 2] + 1);
        }

        curr[j] = val;
        if (val < minRowVal) minRowVal = val;
      }

      // Early termination if entire row exceeds threshold
      if (minRowVal > maxDistance) {
        return maxDistance + 1;
      }

      // Rotate row buffers
      final temp = prev2;
      prev2 = prev;
      prev = curr;
      curr = temp;
    }

    final finalDist = prev[lb];
    return finalDist <= maxDistance ? finalDist : maxDistance + 1;
  }

  /// Maximum allowable edit distance based on token length:
  /// - 1-3 chars: 0 (exact match only)
  /// - 4-6 chars: 1 typo allowed
  /// - 7+ chars: 2 typos allowed
  static int maxAllowedEditDistance(int tokenLength) {
    if (tokenLength <= 3) return 0;
    if (tokenLength <= 6) return 1;
    return 2;
  }

  /// Tokenizes a string into lowercased search words.
  static List<String> tokenize(String input) {
    return SearchTokenizer.tokenize(input);
  }

  /// Evaluates query against a text segment with field-specific weighting.
  static TextMatchResult evaluate({
    required String query,
    required String text,
    bool isTitle = false,
    bool isTag = false,
    SearchRankingConfig config = const SearchRankingConfig(),
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
    final spans = <TokenSpanDto>[];
    int? bestMatchOffset;
    int? bestMatchLength;

    // 1. Exact continuous phrase match check
    final exactPhraseIdx = lowerText.indexOf(cleanQuery);
    if (exactPhraseIdx != -1) {
      hasExactPhrase = true;
      if (queryTokens.length > 1) {
        totalScore += isTitle
            ? config.exactPhraseTitle
            : (isTag ? config.exactPhraseTag : config.exactPhraseBody);
      }
      spans.add(TokenSpanDto(
        start: exactPhraseIdx,
        end: exactPhraseIdx + cleanQuery.length,
        isExact: true,
      ));
      bestMatchOffset = exactPhraseIdx;
      bestMatchLength = cleanQuery.length;
    }

    // 2. Tokenized word-by-word matching
    final wordRegex = RegExp(r'\b[\w#]+\b');
    final wordMatches = wordRegex.allMatches(text).toList();

    for (final qToken in queryTokens) {
      final cleanQToken = qToken.replaceAll(RegExp(r'^#'), '');
      if (cleanQToken.isEmpty) continue;

      final maxDistance = maxAllowedEditDistance(cleanQToken.length);
      bool tokenMatched = false;
      int bestDistance = 999;
      TokenSpanDto? bestSpanForToken;
      var matchType = _MatchType.none;

      // Check exact substring containment in text
      final subIdx = lowerText.indexOf(cleanQToken);
      if (subIdx != -1) {
        tokenMatched = true;
        matchType = _MatchType.exact;
        bestSpanForToken = TokenSpanDto(
          start: subIdx,
          end: subIdx + cleanQToken.length,
          isExact: true,
        );
        bestMatchOffset ??= subIdx;
        bestMatchLength ??= cleanQToken.length;
      } else {
        // Evaluate against individual words
        for (final m in wordMatches) {
          final word = m.group(0)!.toLowerCase().replaceAll(RegExp(r'^#'), '');
          if (word.isEmpty) continue;

          // Prefix match
          if (word.startsWith(cleanQToken)) {
            tokenMatched = true;
            matchType = _MatchType.prefix;
            bestSpanForToken = TokenSpanDto(
              start: m.start,
              end: m.start + cleanQToken.length,
              isExact: true,
            );
            bestMatchOffset ??= m.start;
            bestMatchLength ??= cleanQToken.length;
            break;
          }

          // Infix / substring match
          if (word.contains(cleanQToken)) {
            tokenMatched = true;
            matchType = _MatchType.substring;
            final inWordIdx = word.indexOf(cleanQToken);
            bestSpanForToken = TokenSpanDto(
              start: m.start + inWordIdx,
              end: m.start + inWordIdx + cleanQToken.length,
              isExact: true,
            );
            bestMatchOffset ??= m.start + inWordIdx;
            bestMatchLength ??= cleanQToken.length;
            break;
          }

          // Bounded fuzzy match (only if length bounds allow)
          if (maxDistance > 0 && (word.length - cleanQToken.length).abs() <= maxDistance) {
            final distance = damerauLevenshtein(cleanQToken, word, maxDistance: maxDistance);
            if (distance <= maxDistance && distance < bestDistance) {
              bestDistance = distance;
              tokenMatched = true;
              hasFuzzy = true;
              matchType = (distance == 1) ? _MatchType.fuzzy1 : _MatchType.fuzzy2;
              bestSpanForToken = TokenSpanDto(
                start: m.start,
                end: m.end,
                isExact: false,
              );
              bestMatchOffset ??= m.start;
              bestMatchLength ??= m.end - m.start;
            }
          }
        }
      }

      if (tokenMatched) {
        matchedTokensCount++;
        if (bestSpanForToken != null) {
          spans.add(bestSpanForToken);
        }

        switch (matchType) {
          case _MatchType.exact:
            totalScore += isTitle
                ? config.exactTokenTitle
                : (isTag ? config.exactTokenTag : config.exactTokenBody);
            break;
          case _MatchType.prefix:
            totalScore += isTitle
                ? config.prefixTitle
                : (isTag ? config.prefixTag : config.prefixBody);
            break;
          case _MatchType.substring:
            totalScore += isTitle
                ? config.substringTitle
                : (isTag ? config.substringTag : config.substringBody);
            break;
          case _MatchType.fuzzy1:
            totalScore += isTitle
                ? config.fuzzyDist1Title
                : (isTag ? config.fuzzyDist1Tag : config.fuzzyDist1Body);
            break;
          case _MatchType.fuzzy2:
            totalScore += isTitle
                ? config.fuzzyDist2Title
                : (isTag ? config.fuzzyDist2Tag : config.fuzzyDist2Body);
            break;
          case _MatchType.none:
            break;
        }
      }
    }

    if (matchedTokensCount == 0 && totalScore == 0.0) {
      return TextMatchResult.none;
    }

    // Multi-token coverage rewards
    totalScore += matchedTokensCount * config.perMatchedTokenBonus;
    if (matchedTokensCount == queryTokens.length) {
      totalScore += config.allTokensMatchedBonus;
    }

    String snippet = '';
    if (bestMatchOffset != null) {
      final snippetRes = MarkdownOffsetMapper.extractSnippet(
        text: text,
        focusOffset: bestMatchOffset,
        focusLength: bestMatchLength ?? cleanQuery.length,
        normalizedSpans: spans,
        contextRadius: config.snippetContextRadius,
      );
      snippet = snippetRes.snippet;
    } else if (text.isNotEmpty) {
      snippet = text.length > 120 ? '${text.substring(0, 117)}…' : text;
    }

    return TextMatchResult(
      score: totalScore,
      matchedTokensCount: matchedTokensCount,
      isFuzzy: hasFuzzy,
      hasExactPhrase: hasExactPhrase,
      highlightSpans: spans,
      snippet: snippet,
      bestMatchOffset: bestMatchOffset,
      bestMatchLength: bestMatchLength,
    );
  }

  /// Evaluates a Note candidate DTO producing NoteSearchMatchDto or null if no match.
  static NoteSearchMatchDto? evaluateCandidate({
    required SearchCandidateDto candidate,
    required CompiledSearchQuery query,
    SearchRankingConfig config = const SearchRankingConfig(),
  }) {
    if (query.isEmpty) return null;

    final titleMatch = evaluate(
      query: query.cleanQuery,
      text: candidate.title,
      isTitle: true,
      config: config,
    );

    final tagsText = candidate.tags.map((t) => '#$t $t').join(' ');
    final tagMatch = evaluate(
      query: query.cleanQuery,
      text: tagsText,
      isTag: true,
      config: config,
    );

    // Normalize markdown content for accurate body evaluation and offset mapping
    final normalized = MarkdownOffsetMapper.normalize(candidate.content);
    final contentMatch = evaluate(
      query: query.cleanQuery,
      text: normalized.normalizedText,
      isTitle: false,
      config: config,
    );

    if (!titleMatch.hasMatch && !tagMatch.hasMatch && !contentMatch.hasMatch) {
      return null;
    }

    var totalScore = titleMatch.score + tagMatch.score + contentMatch.score;

    // Recency decay boost (up to 15 points for recent notes)
    final daysSinceUpdate = DateTime.now().difference(candidate.updatedAt).inDays;
    if (daysSinceUpdate >= 0) {
      final recencyBoost = config.recencyMaxBonus / (1.0 + (daysSinceUpdate / 30.0));
      totalScore += recencyBoost;
    }

    // Pinned note boost
    if (candidate.isPinned) {
      totalScore += 10.0;
    }

    final isFuzzy = titleMatch.isFuzzy || tagMatch.isFuzzy || contentMatch.isFuzzy;
    final maxTokensMatched = max(
      titleMatch.matchedTokensCount,
      max(tagMatch.matchedTokensCount, contentMatch.matchedTokensCount),
    );

    // Generate bounded snippet
    String finalSnippet = '';
    List<TokenSpanDto> snippetSpans = const [];

    if (contentMatch.hasMatch && contentMatch.bestMatchOffset != null) {
      final snippetRes = MarkdownOffsetMapper.extractSnippet(
        text: normalized.normalizedText,
        focusOffset: contentMatch.bestMatchOffset!,
        focusLength: contentMatch.bestMatchLength ?? query.cleanQuery.length,
        normalizedSpans: contentMatch.highlightSpans,
        contextRadius: config.snippetContextRadius,
      );
      finalSnippet = snippetRes.snippet;
      snippetSpans = snippetRes.highlightSpans;
    } else {
      // Fallback snippet from note preview
      final previewText = normalized.normalizedText.length > 120
          ? '${normalized.normalizedText.substring(0, 117).trim()}…'
          : normalized.normalizedText;
      finalSnippet = previewText;
    }

    return NoteSearchMatchDto(
      noteId: candidate.id,
      score: totalScore,
      snippet: finalSnippet,
      titleHighlightSpans: titleMatch.highlightSpans,
      snippetHighlightSpans: snippetSpans,
      matchedInTitle: titleMatch.hasMatch,
      matchedInContent: contentMatch.hasMatch,
      matchedInTags: tagMatch.hasMatch,
      isFuzzy: isFuzzy,
      matchedTokensCount: maxTokensMatched,
    );
  }

  /// Evaluates an OCR page candidate producing DocumentSearchMatchDto or null if no match.
  static DocumentSearchMatchDto? evaluateOcrPage({
    required OcrPageCandidateDto candidate,
    required CompiledSearchQuery query,
    SearchRankingConfig config = const SearchRankingConfig(),
  }) {
    if (query.isEmpty) return null;

    final titleMatch = evaluate(
      query: query.cleanQuery,
      text: candidate.documentTitle,
      isTitle: true,
      config: config,
    );

    final pageMatch = evaluate(
      query: query.cleanQuery,
      text: candidate.plainText,
      isTitle: false,
      config: config,
    );

    if (!titleMatch.hasMatch && !pageMatch.hasMatch) {
      return null;
    }

    final totalScore = pageMatch.score + (titleMatch.hasMatch ? 40.0 : 0.0);
    final isOcrMatch = pageMatch.hasMatch;

    String snippet = '';
    List<TokenSpanDto> snippetSpans = const [];

    if (pageMatch.hasMatch && pageMatch.bestMatchOffset != null) {
      final snippetRes = MarkdownOffsetMapper.extractSnippet(
        text: candidate.plainText,
        focusOffset: pageMatch.bestMatchOffset!,
        focusLength: pageMatch.bestMatchLength ?? query.cleanQuery.length,
        normalizedSpans: pageMatch.highlightSpans,
        contextRadius: config.snippetContextRadius,
      );
      snippet = snippetRes.snippet;
      snippetSpans = snippetRes.highlightSpans;
    } else {
      snippet = 'Document Title: ${candidate.documentTitle}';
    }

    return DocumentSearchMatchDto(
      documentId: candidate.documentId,
      attachmentId: candidate.attachmentId,
      documentTitle: candidate.documentTitle,
      parentNoteTitle: candidate.parentNoteTitle,
      parentNoteId: candidate.parentNoteId,
      matchedPageNumber: candidate.pageNumber,
      snippet: snippet,
      snippetHighlightSpans: snippetSpans,
      titleHighlightSpans: titleMatch.highlightSpans,
      isOcrMatch: isOcrMatch,
      isFuzzy: pageMatch.isFuzzy || titleMatch.isFuzzy,
      matchedTokensCount: max(pageMatch.matchedTokensCount, titleMatch.matchedTokensCount),
      score: totalScore,
    );
  }
}

enum _MatchType {
  none,
  exact,
  prefix,
  substring,
  fuzzy1,
  fuzzy2,
}
