import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/fuzzy_search_engine.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';

/// Feature B — Unicode-aware search & tags (Bengali content support, spec §4).
void main() {
  group('SearchTokenizer Unicode awareness', () {
    test('tokenizes a Bengali string into word tokens (was previously empty)', () {
      final tokens = SearchTokenizer.tokenize('আমি বাংলা লিখি');
      expect(tokens, ['আমি', 'বাংলা', 'লিখি']);
    });

    test('tokenizes a mixed Bengali + Latin string', () {
      final tokens = SearchTokenizer.tokenize('Hello আমি 2024');
      expect(tokens, ['hello', 'আমি', '2024']);
    });

    test('keeps a Bengali hashtag token intact', () {
      final tokens = SearchTokenizer.tokenize('note #বাংলা here');
      expect(tokens, contains('#বাংলা'));
    });
  });

  group('TagParser Unicode awareness', () {
    test('extracts a Bengali #tag', () {
      final tags = TagParser.extractTags('এটি একটি #বাংলা নোট');
      expect(tags, ['বাংলা']);
    });

    test('extracts a nested Bengali tag', () {
      final tags = TagParser.extractTags('খরচ #খাবার/দুপুর আজ');
      expect(tags, ['খাবার/দুপুর']);
    });

    test('accepts a Bengali tag as valid', () {
      expect(TagParser.isValidTag('বাংলা'), isTrue);
    });

    test('still rejects a purely-numeric ASCII tag', () {
      expect(TagParser.isValidTag('123'), isFalse);
    });
  });

  group('FuzzySearchEngine Bengali matching', () {
    test('a Bengali query matches a Bengali note end-to-end', () {
      final res = FuzzySearchEngine.evaluate(
        query: 'বাংলা',
        text: 'আমি বাংলা ভাষায় লিখছি।',
      );
      expect(res.hasMatch, isTrue);
    });

    test('a non-matching Bengali query does not match', () {
      final res = FuzzySearchEngine.evaluate(
        query: 'ইংরেজি',
        text: 'আমি বাংলা ভাষায় লিখছি।',
      );
      expect(res.hasMatch, isFalse);
    });
  });
}
