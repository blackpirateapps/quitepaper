import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/syntax/application/syntax_language_registry.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';

void main() {
  late SyntaxLanguageRegistry registry;

  setUp(() {
    registry = SyntaxLanguageRegistry.instance;
  });

  group('SyntaxLanguageRegistry', () {
    test('initializes with all 189 bundled languages', () {
      expect(registry.allLanguages.length, greaterThanOrEqualTo(40));
      expect(registry.allLanguageIds.length, greaterThanOrEqualTo(180));
      expect(registry.allLanguages.contains(SyntaxLanguage.plainText), isTrue);
    });

    test('finds languages by canonical ID and case-insensitively', () {
      expect(registry.findByIdOrAlias('dart')?.id, equals('dart'));
      expect(registry.findByIdOrAlias('DART')?.id, equals('dart'));
      expect(registry.findByIdOrAlias('python')?.id, equals('python'));
      expect(registry.findByIdOrAlias('Python')?.id, equals('python'));
      expect(registry.findByIdOrAlias('javascript')?.id, equals('javascript'));
      expect(registry.findByIdOrAlias('json')?.id, equals('json'));
      expect(registry.findByIdOrAlias('yaml')?.id, equals('yaml'));
      expect(registry.findByIdOrAlias('sql')?.id, equals('sql'));
      expect(registry.findByIdOrAlias('bash')?.id, equals('bash'));
    });

    test('finds languages by common aliases', () {
      expect(registry.findByIdOrAlias('js')?.id, equals('javascript'));
      expect(registry.findByIdOrAlias('ts')?.id, equals('typescript'));
      expect(registry.findByIdOrAlias('py')?.id, equals('python'));
      expect(registry.findByIdOrAlias('sh')?.id, equals('bash'));
      expect(registry.findByIdOrAlias('shell')?.id, anyOf(equals('bash'), equals('shell')));
      expect(registry.findByIdOrAlias('yml')?.id, equals('yaml'));
      expect(registry.findByIdOrAlias('c++')?.id, equals('cpp'));
      expect(registry.findByIdOrAlias('c#')?.id, equals('cs'));
      expect(registry.findByIdOrAlias('rs')?.id, equals('rust'));
      expect(registry.findByIdOrAlias('golang')?.id, equals('go'));
      expect(registry.findByIdOrAlias('rb')?.id, equals('ruby'));
    });

    test('finds languages by file extension', () {
      expect(registry.findByExtension('dart')?.id, equals('dart'));
      expect(registry.findByExtension('.dart')?.id, equals('dart'));
      expect(registry.findByExtension('py')?.id, equals('python'));
      expect(registry.findByExtension('js')?.id, equals('javascript'));
      expect(registry.findByExtension('ts')?.id, equals('typescript'));
      expect(registry.findByExtension('tsx')?.id, equals('typescript'));
      expect(registry.findByExtension('jsx')?.id, equals('javascript'));
      expect(registry.findByExtension('json')?.id, equals('json'));
      expect(registry.findByExtension('yaml')?.id, equals('yaml'));
      expect(registry.findByExtension('yml')?.id, equals('yaml'));
      expect(registry.findByExtension('md')?.id, equals('markdown'));
      expect(registry.findByExtension('rs')?.id, equals('rust'));
      expect(registry.findByExtension('go')?.id, equals('go'));
      expect(registry.findByExtension('cpp')?.id, equals('cpp'));
      expect(registry.findByExtension('h')?.id, equals('c'));
      expect(registry.findByExtension('sql')?.id, equals('sql'));
    });

    test('finds languages by MIME type', () {
      expect(registry.findByMimeType('application/json')?.id, equals('json'));
      expect(registry.findByMimeType('application/x-yaml')?.id, equals('yaml'));
      expect(registry.findByMimeType('text/yaml')?.id, equals('yaml'));
      expect(registry.findByMimeType('text/javascript')?.id, equals('javascript'));
      expect(registry.findByMimeType('application/javascript')?.id, equals('javascript'));
      expect(registry.findByMimeType('text/x-python')?.id, equals('python'));
      expect(registry.findByMimeType('text/x-dart')?.id, equals('dart'));
      expect(registry.findByMimeType('text/markdown')?.id, equals('markdown'));
      expect(registry.findByMimeType('text/html')?.id, equals('xml'));
    });

    test('searches languages with query matching name, ID, or aliases', () {
      final pythonResults = registry.search('pyth');
      expect(pythonResults.any((l) => l.id == 'python'), isTrue);

      final jsResults = registry.search('javascript');
      expect(jsResults.any((l) => l.id == 'javascript'), isTrue);

      final emptyQueryResults = registry.search('');
      expect(emptyQueryResults.length, equals(registry.allLanguages.length));
    });

    test('returns null for unknown language, extension, or MIME', () {
      expect(registry.findByIdOrAlias('nonexistent_lang_xyz'), isNull);
      expect(registry.findByExtension('unknown_ext_xyz'), isNull);
      expect(registry.findByMimeType('application/x-unknown-xyz'), isNull);
    });
  });
}
