import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_frontmatter.dart';

void main() {
  group('CliFrontmatter Tests', () {
    test('parses frontmatter with title, journal, date, and tags list', () {
      const content = '''---
title: "November 10, 2026"
journal: true
date: 2026-11-10
tags: [journal/2026, reflection]
---
Body text begins here.
More content.
''';

      final result = CliFrontmatter.parse(content);
      expect(result.hasFrontmatter, isTrue);
      expect(result.title, 'November 10, 2026');
      expect(result.isJournal, isTrue);
      expect(result.journalDate, '2026-11-10');
      expect(result.tags, containsAll(['journal/2026', 'reflection']));
      expect(result.contentBody.trim(), 'Body text begins here.\nMore content.');
    });

    test('parses multiline tags format', () {
      const content = '''---
journal: true
tags:
  - work/projects
  - deepwork
---
Work log details.
''';

      final result = CliFrontmatter.parse(content);
      expect(result.hasFrontmatter, isTrue);
      expect(result.title, isNull);
      expect(result.isJournal, isTrue);
      expect(result.tags, containsAll(['work/projects', 'deepwork']));
      expect(result.contentBody.trim(), 'Work log details.');
    });

    test('updateTitle replaces existing title in frontmatter', () {
      const content = '''---
title: Old Title
journal: true
date: 2026-11-10
---
Body.
''';

      final updated = CliFrontmatter.updateTitle(
        documentText: content,
        newTitle: 'New Title',
      );

      final parsed = CliFrontmatter.parse(updated);
      expect(parsed.title, 'New Title');
      expect(parsed.isJournal, isTrue);
      expect(parsed.contentBody.trim(), 'Body.');
    });

    test('updateTitle injects title when frontmatter exists without title key', () {
      const content = '''---
journal: true
date: 2026-11-10
---
Body text.
''';

      final updated = CliFrontmatter.updateTitle(
        documentText: content,
        newTitle: 'November 10, 2026',
      );

      final parsed = CliFrontmatter.parse(updated);
      expect(parsed.title, 'November 10, 2026');
      expect(parsed.isJournal, isTrue);
      expect(parsed.journalDate, '2026-11-10');
      expect(parsed.contentBody.trim(), 'Body text.');
    });

    test('updateTitle returns document unchanged when no frontmatter is present', () {
      const content = '# Regular Note\n\nNo frontmatter here.';
      final result = CliFrontmatter.updateTitle(
        documentText: content,
        newTitle: 'Other Title',
      );
      expect(result, content);
    });
  });
}
