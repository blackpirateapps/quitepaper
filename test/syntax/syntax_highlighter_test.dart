import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/syntax/application/syntax_language_registry.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token_type.dart';
import 'package:quitepaper/core/syntax/infrastructure/highlight_package_adapter.dart';

void main() {
  late HighlightPackageAdapter highlighter;
  late SyntaxLanguageRegistry registry;

  setUp(() {
    highlighter = HighlightPackageAdapter();
    registry = SyntaxLanguageRegistry.instance;
  });

  group('SyntaxHighlighter - Tokenization across Languages', () {
    test('tokenizes Dart code correctly', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      const code = 'final int answer = 42; // The meaning of life\nString text = "hello";';
      final result = highlighter.highlight(source: code, language: dartLang);

      expect(result.language.id, equals('dart'));
      expect(result.tokens, isNotEmpty);
      expect(result.sourceLength, equals(code.length));

      // Keywords and types
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.keyword || t.type == SyntaxTokenType.type), isTrue);
      // Comments
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.comment), isTrue);
      // Numbers
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.number), isTrue);
      // Strings
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.string), isTrue);

      // Verify every token offset is valid and in ascending order
      int lastEnd = 0;
      for (final t in result.tokens) {
        expect(t.start, greaterThanOrEqualTo(lastEnd));
        expect(t.end, greaterThan(t.start));
        expect(t.end, lessThanOrEqualTo(code.length));
        lastEnd = t.end;
      }
    });

    test('tokenizes Python code correctly', () {
      final pyLang = registry.findByIdOrAlias('python')!;
      const code = 'def calculate_sum(a: int, b: int) -> int:\n    # Return sum\n    return a + b\n';
      final result = highlighter.highlight(source: code, language: pyLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.keyword), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.comment), isTrue);
    });

    test('tokenizes JavaScript and TypeScript correctly', () {
      final tsLang = registry.findByIdOrAlias('typescript')!;
      const code = 'interface User {\n  id: string;\n  count: number;\n}\nconst u: User = { id: "1", count: 10 };';
      final result = highlighter.highlight(source: code, language: tsLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.keyword), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.string), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.number), isTrue);
    });

    test('tokenizes JSON correctly', () {
      final jsonLang = registry.findByIdOrAlias('json')!;
      const code = '{\n  "name": "Quiet Paper",\n  "version": 1,\n  "active": true\n}';
      final result = highlighter.highlight(source: code, language: jsonLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.string || t.type == SyntaxTokenType.attribute), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.number), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.literal || t.type == SyntaxTokenType.keyword), isTrue);
    });

    test('tokenizes YAML correctly', () {
      final yamlLang = registry.findByIdOrAlias('yaml')!;
      const code = 'app:\n  name: Quiet Paper\n  enabled: true\n  tags:\n    - markdown\n    - offline\n';
      final result = highlighter.highlight(source: code, language: yamlLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.property || t.type == SyntaxTokenType.attribute || t.type == SyntaxTokenType.string), isTrue);
    });

    test('tokenizes SQL correctly', () {
      final sqlLang = registry.findByIdOrAlias('sql')!;
      const code = 'SELECT id, title, created_at FROM notes WHERE is_archived = 0 ORDER BY created_at DESC;';
      final result = highlighter.highlight(source: code, language: sqlLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.keyword), isTrue);
    });

    test('tokenizes Shell / Bash correctly', () {
      final bashLang = registry.findByIdOrAlias('bash')!;
      const code = '#!/bin/bash\necho "Running tests..."\nexport PATH="\$PATH:/home/dog/flutter/bin"\n';
      final result = highlighter.highlight(source: code, language: bashLang);

      expect(result.tokens, isNotEmpty);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.annotation || t.type == SyntaxTokenType.builtin || t.type == SyntaxTokenType.variable || t.type == SyntaxTokenType.comment), isTrue);
      expect(result.tokens.any((t) => t.type == SyntaxTokenType.string), isTrue);
    });

    test('tokenizes Rust and Go correctly', () {
      final rustLang = registry.findByIdOrAlias('rust')!;
      const rustCode = 'fn main() {\n    let message = "Hello Rust";\n    println!("{}", message);\n}';
      final rustRes = highlighter.highlight(source: rustCode, language: rustLang);
      expect(rustRes.tokens, isNotEmpty);

      final goLang = registry.findByIdOrAlias('go')!;
      const goCode = 'package main\n\nimport "fmt"\n\nfunc main() {\n    fmt.Println("Hello Go")\n}';
      final goRes = highlighter.highlight(source: goCode, language: goLang);
      expect(goRes.tokens, isNotEmpty);
    });
  });

  group('SyntaxHighlighter - Edge Cases & Robustness', () {
    test('handles empty source string gracefully', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      final result = highlighter.highlight(source: '', language: dartLang);
      expect(result.tokens, isEmpty);
      expect(result.sourceLength, equals(0));
    });

    test('handles whitespace-only string', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      const code = '   \n\t  \n';
      final result = highlighter.highlight(source: code, language: dartLang);
      expect(result.isSuccess, isFalse);
      expect(result.tokens.single.type, equals(SyntaxTokenType.plain));
    });

    test('handles incomplete syntax and unclosed quotes/brackets gracefully', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      const code = 'class Foo {\n  String bar = "unclosed string without end\n  int y = (1 + 2';
      final result = highlighter.highlight(source: code, language: dartLang);
      expect(result.tokens, isNotEmpty);
      expect(result.sourceLength, equals(code.length));
    });

    test('handles Unicode and emoji characters with exact UTF-16 code unit offsets', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      const code = 'final greeting = "こんにちは 🌍"; // 🚀 rocket\nfinal int count = 100;';
      final result = highlighter.highlight(source: code, language: dartLang);

      expect(result.tokens, isNotEmpty);
      expect(result.sourceLength, equals(code.length));

      for (final tok in result.tokens) {
        final substring = code.substring(tok.start, tok.end);
        if (tok.text != null) {
          expect(tok.text, equals(substring));
        }
      }
    });

    test('handles plain text / unhighlighted language without parsing overhead', () {
      const code = 'Just some standard plain text line 1\nLine 2';
      final result = highlighter.highlight(source: code, language: SyntaxLanguage.plainText);
      expect(result.isSuccess, isFalse);
      expect(result.tokens.single.type, equals(SyntaxTokenType.plain));
      expect(result.sourceLength, equals(code.length));
    });

    test('falls back safely for massive payloads beyond safety threshold', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      final hugeCode = 'final x = 1;\n' * 6000; // > 50,000 characters
      expect(hugeCode.length, greaterThan(50000));

      final result = highlighter.highlight(source: hugeCode, language: dartLang);
      expect(result.isSuccess, isFalse);
      expect(result.tokens.single.type, equals(SyntaxTokenType.plain));
      expect(result.sourceLength, equals(hugeCode.length));
    });

    test('uses bounded cache for repeated invocations of the same code', () {
      final dartLang = registry.findByIdOrAlias('dart')!;
      const code = 'final int speed = 120;';

      final firstResult = highlighter.highlight(source: code, language: dartLang);
      final secondResult = highlighter.highlight(source: code, language: dartLang);

      expect(identical(firstResult, secondResult), isTrue);
    });
  });
}
