import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/external_editor_runner.dart';

void main() {
  const runner = ExternalEditorRunner();

  group('ExternalEditorRunner Tests', () {
    test('parseTitleAndContent extracts title from Markdown H1', () {
      const text = '''
# My Vacation Plans

We are visiting the coast and packing light.
#travel #summer
''';

      final parsed = runner.parseTitleAndContent(text);
      expect(parsed.$1, 'My Vacation Plans');
      expect(parsed.$2, text);
    });

    test('parseTitleAndContent falls back to first non-empty line if no H1', () {
      const text = '''
Thoughts on architecture and modularity.

Content continues here.
''';

      final parsed = runner.parseTitleAndContent(text);
      expect(parsed.$1, 'Thoughts on architecture and modularity.');
    });

    test('parseTitleAndContent respects fallbackTitle when text is blank or only headers', () {
      final parsed = runner.parseTitleAndContent('', fallbackTitle: 'Explicit Title');
      expect(parsed.$1, 'Explicit Title');
    });

    test('resolveEditor respects explicit editor parameter', () {
      final editor = runner.resolveEditor('nvim -u NONE');
      expect(editor, 'nvim -u NONE');
    });
  });
}
