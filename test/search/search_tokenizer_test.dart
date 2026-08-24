import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/search_tokenizer.dart';

void main() {
  group('SearchTokenizer', () {
    test('Tokenizes standard query strings into lowercase tokens', () {
      final tokens = SearchTokenizer.tokenize('Meeting with Team at 10am');
      expect(tokens, ['meeting', 'with', 'team', 'at', '10am']);
    });

    test('Strips punctuation and special characters during tokenization', () {
      final tokens = SearchTokenizer.tokenize('Hello, world! (Test: [123])');
      expect(tokens, ['hello', 'world', 'test', '123']);
    });

    test('Escapes FTS5 special characters and protects against injection', () {
      expect(SearchTokenizer.escapeFts5Token('invoice"'), '"invoice"');
      expect(SearchTokenizer.escapeFts5Token('hello*world'), '"helloworld"');
      expect(SearchTokenizer.escapeFts5Token('title:secret'), '"titlesecret"');
      expect(SearchTokenizer.escapeFts5Token('NEAR(a, b)'), '"NEARa, b"');
      expect(SearchTokenizer.escapeFts5Token('^prefix'), '"prefix"');
    });

    test('Compiles query into prefix and trigram expressions', () {
      final compiled = SearchTokenizer.compileQuery('sync plan');
      expect(compiled.isEmpty, false);
      expect(compiled.cleanQuery, 'sync plan');
      expect(compiled.tokens, ['sync', 'plan']);
      expect(compiled.ftsPrefixExpression, '"sync"* "plan"*');
      expect(compiled.isTrigramEligible, true);
      expect(compiled.ftsTrigramExpression, '"sync" "plan"');
    });

    test('Handles short tokens (< 3 chars) for trigram vs prefix', () {
      final compiled = SearchTokenizer.compileQuery('go to db');
      expect(compiled.tokens, ['go', 'to', 'db']);
      // None of the tokens are >= 3 chars
      expect(compiled.isTrigramEligible, false);
      expect(compiled.ftsTrigramExpression, '');
      // Prefix index still indexes and searches them
      expect(compiled.ftsPrefixExpression, '"go"* "to"* "db"*');
    });

    test('Compiles single character or mixed length queries correctly', () {
      final compiled = SearchTokenizer.compileQuery('a test');
      expect(compiled.tokens, ['a', 'test']);
      expect(compiled.isTrigramEligible, true);
      // Only 'test' (>= 3 chars) is in trigram expression
      expect(compiled.ftsTrigramExpression, '"test"');
      expect(compiled.ftsPrefixExpression, '"a"* "test"*');
    });

    test('Returns empty CompiledSearchQuery for empty or punctuation-only input', () {
      final empty = SearchTokenizer.compileQuery('   ');
      expect(empty.isEmpty, true);
      expect(empty.tokens, isEmpty);
      expect(empty.ftsPrefixExpression, '');
      expect(empty.ftsTrigramExpression, '');

      final punct = SearchTokenizer.compileQuery('*** ,,, !!!');
      expect(punct.isEmpty, true);
    });
  });
}
