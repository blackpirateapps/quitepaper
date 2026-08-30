import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/syntax/application/syntax_language_resolver.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';

void main() {
  late SyntaxLanguageResolver resolver;

  setUp(() {
    resolver = SyntaxLanguageResolver();
  });

  group('SyntaxLanguageResolver - Markdown Code Fences', () {
    test('returns null for empty, null, or whitespace info strings', () {
      expect(resolver.resolveFromFence(null), isNull);
      expect(resolver.resolveFromFence(''), isNull);
      expect(resolver.resolveFromFence('   '), isNull);
    });

    test('resolves canonical language identifiers and aliases', () {
      expect(resolver.resolveFromFence('dart')?.id, equals('dart'));
      expect(resolver.resolveFromFence('python')?.id, equals('python'));
      expect(resolver.resolveFromFence('py')?.id, equals('python'));
      expect(resolver.resolveFromFence('js')?.id, equals('javascript'));
      expect(resolver.resolveFromFence('typescript')?.id, equals('typescript'));
      expect(resolver.resolveFromFence('ts')?.id, equals('typescript'));
      expect(resolver.resolveFromFence('json')?.id, equals('json'));
      expect(resolver.resolveFromFence('yaml')?.id, equals('yaml'));
      expect(resolver.resolveFromFence('yml')?.id, equals('yaml'));
      expect(resolver.resolveFromFence('bash')?.id, equals('bash'));
      expect(resolver.resolveFromFence('sh')?.id, equals('bash'));
      expect(resolver.resolveFromFence('shell')?.id, anyOf(equals('bash'), equals('shell')));
      expect(resolver.resolveFromFence('sql')?.id, equals('sql'));
      expect(resolver.resolveFromFence('rust')?.id, equals('rust'));
      expect(resolver.resolveFromFence('rs')?.id, equals('rust'));
      expect(resolver.resolveFromFence('cpp')?.id, equals('cpp'));
      expect(resolver.resolveFromFence('c++')?.id, equals('cpp'));
      expect(resolver.resolveFromFence('go')?.id, equals('go'));
    });

    test('strips trailing info string flags and whitespace', () {
      expect(resolver.resolveFromFence('dart {lineNumbers: true}')?.id, equals('dart'));
      expect(resolver.resolveFromFence('python title="test.py"')?.id, equals('python'));
      expect(resolver.resolveFromFence('json highlight=1-5')?.id, equals('json'));
    });

    test('returns plainText for text / plaintext / txt', () {
      expect(resolver.resolveFromFence('text'), equals(SyntaxLanguage.plainText));
      expect(resolver.resolveFromFence('plaintext'), equals(SyntaxLanguage.plainText));
      expect(resolver.resolveFromFence('txt'), equals(SyntaxLanguage.plainText));
    });

    test('returns unsupported SyntaxLanguage representation for unknown identifiers', () {
      final unk = resolver.resolveFromFence('customlang123');
      expect(unk, isNotNull);
      expect(unk!.isSupported, isFalse);
      expect(unk.id, equals('customlang123'));
    });
  });

  group('SyntaxLanguageResolver - Attachments', () {
    test('priority 1: explicit user override takes precedence', () {
      final lang = resolver.resolveForAttachment(
        overrideLanguageId: 'python',
        fileName: 'script.dart',
        mimeType: 'text/x-dart',
      );
      expect(lang.id, equals('python'));
    });

    test('priority 2: MIME type when override is not specified', () {
      final lang = resolver.resolveForAttachment(
        fileName: 'unknown_file_without_ext',
        mimeType: 'application/json',
      );
      expect(lang.id, equals('json'));
    });

    test('priority 3: file extension when MIME is generic or unknown', () {
      final lang = resolver.resolveForAttachment(
        fileName: 'main.dart',
        mimeType: 'application/octet-stream',
      );
      expect(lang.id, equals('dart'));
    });

    test('priority 4: fallback to plainText when unresolvable', () {
      final lang = resolver.resolveForAttachment(
        fileName: 'readme',
        mimeType: 'application/octet-stream',
      );
      expect(lang, equals(SyntaxLanguage.plainText));
    });
  });
}
