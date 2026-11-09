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

    test('parseTitleAndContent extracts title from YAML frontmatter title property', () {
      const text = '''---
title: November 10, 2026
journal: true
date: 2026-11-10
tags: [journal/2026]
---
Journal entry content continues here.
''';

      final parsed = runner.parseTitleAndContent(text, fallbackTitle: 'November 10, 2026');
      expect(parsed.$1, 'November 10, 2026');
      expect(parsed.$1.startsWith('title:'), isFalse);
    });

    test('parseTitleAndContent cleans quoted titles and accidental title prefix in frontmatter', () {
      const text = '''---
title: "Midnapore Trip & Reflections"
date: 2026-11-10
---
Trip details.
''';

      final parsed = runner.parseTitleAndContent(text);
      expect(parsed.$1, 'Midnapore Trip & Reflections');
    });

    test('parseTitleAndContent with journal frontmatter lacking title falls back to fallbackTitle rather than YAML key', () {
      const text = '''---
journal: true
date: 2026-11-10
tags: [journal/2026]
---
I am finally getting back on track about studying.
''';

      final parsed = runner.parseTitleAndContent(text, fallbackTitle: 'November 10, 2026');
      expect(parsed.$1, 'November 10, 2026');
      expect(parsed.$1, isNot('journal: true'));
      expect(parsed.$1, isNot('date: 2026-11-10'));
    });

    test('parseTitleAndContent with frontmatter lacking title extracts H1 heading in body', () {
      const text = '''---
journal: true
date: 2026-11-10
---
# Morning Routine

Started day with meditation.
''';

      final parsed = runner.parseTitleAndContent(text);
      expect(parsed.$1, 'Morning Routine');
    });

    test('cleanTitle strips leading title: and enclosing quotes', () {
      expect(ExternalEditorRunner.cleanTitle('title: November 10, 2026'), 'November 10, 2026');
      expect(ExternalEditorRunner.cleanTitle('title: "Important Notes"'), 'Important Notes');
      expect(ExternalEditorRunner.cleanTitle("'Single Quoted'"), 'Single Quoted');
      expect(ExternalEditorRunner.cleanTitle('Regular Title'), 'Regular Title');
    });

    test('resolveEditor respects explicit editor parameter', () {
      final editor = runner.resolveEditor('nvim -u NONE');
      expect(editor, 'nvim -u NONE');
    });
  });
}
