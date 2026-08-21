import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/fuzzy_search_engine.dart';

void main() {
  group('FuzzySearchEngine Distance & Threshold Tests', () {
    test('Calculates Damerau-Levenshtein distance including transpositions', () {
      expect(FuzzySearchEngine.damerauLevenshtein('invoice', 'invoice'), 0);
      expect(FuzzySearchEngine.damerauLevenshtein('invioce', 'invoice'), 1); // transposition
      expect(FuzzySearchEngine.damerauLevenshtein('invoce', 'invoice'), 1);  // deletion
      expect(FuzzySearchEngine.damerauLevenshtein('invoiice', 'invoice'), 1); // insertion
      expect(FuzzySearchEngine.damerauLevenshtein('invoise', 'invoice'), 1);  // substitution
      expect(FuzzySearchEngine.damerauLevenshtein('imvoise', 'invoice'), 2);  // 2 substitutions
    });

    test('Enforces adaptive edit distance thresholds', () {
      expect(FuzzySearchEngine.maxAllowedEditDistance(2), 0);
      expect(FuzzySearchEngine.maxAllowedEditDistance(3), 0);
      expect(FuzzySearchEngine.maxAllowedEditDistance(4), 1);
      expect(FuzzySearchEngine.maxAllowedEditDistance(6), 1);
      expect(FuzzySearchEngine.maxAllowedEditDistance(7), 2);
      expect(FuzzySearchEngine.maxAllowedEditDistance(12), 2);
    });

    test('Short words (<= 3 chars) do not match with typos', () {
      final res = FuzzySearchEngine.evaluate(query: 'tax', text: 'take');
      expect(res.hasMatch, isFalse);
    });

    test('Medium words (4-6 chars) match with 1 typo', () {
      final res = FuzzySearchEngine.evaluate(query: 'reciept', text: 'Check the attached receipt for payment.');
      expect(res.hasMatch, isTrue);
      expect(res.isFuzzy, isTrue);
      expect(res.matchedTokensCount, 1);
    });

    test('Long words (7+ chars) match with up to 2 typos', () {
      final res = FuzzySearchEngine.evaluate(
        query: 'artifical intellgense',
        text: 'Advances in artificial intelligence technology.',
      );
      expect(res.hasMatch, isTrue);
      expect(res.matchedTokensCount, 2);
      expect(res.isFuzzy, isTrue);
    });
  });

  group('FuzzySearchEngine Scoring & Relevance Tests', () {
    test('Exact phrase match yields higher score than fuzzy match', () {
      final exactRes = FuzzySearchEngine.evaluate(
        query: 'cloud architecture',
        text: 'cloud architecture design document',
        isTitle: true,
      );

      final fuzzyRes = FuzzySearchEngine.evaluate(
        query: 'cloud archtecture',
        text: 'cloud architecture design document',
        isTitle: true,
      );

      expect(exactRes.hasMatch, isTrue);
      expect(fuzzyRes.hasMatch, isTrue);
      expect(exactRes.score, greaterThan(fuzzyRes.score));
    });

    test('Multi-token match scores higher when more tokens match', () {
      const doc = 'Acme corporation annual report and tax summary';
      final singleTokenMatch = FuzzySearchEngine.evaluate(query: 'acme', text: doc);
      final twoTokenMatch = FuzzySearchEngine.evaluate(query: 'acme report', text: doc);
      final threeTokenMatch = FuzzySearchEngine.evaluate(query: 'acme annual report', text: doc);

      expect(twoTokenMatch.score, greaterThan(singleTokenMatch.score));
      expect(threeTokenMatch.score, greaterThan(twoTokenMatch.score));
    });

    test('Extracts highlight spans and context snippet', () {
      const text = 'The total amount due on final invoice #9402 is \$500.';
      final res = FuzzySearchEngine.evaluate(query: 'invioce', text: text);

      expect(res.hasMatch, isTrue);
      expect(res.highlightSpans.isNotEmpty, isTrue);
      expect(res.snippet, contains('invoice #9402'));
    });
  });
}
