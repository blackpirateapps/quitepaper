import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/import/application/markdown_frontmatter_parser.dart';

void main() {
  group('MarkdownFrontmatterParser', () {
    test('extracts title, tags, date and preserves full body with frontmatter as is', () {
      const content = '''---
title: "Deep Learning Architectures"
tags: [machine-learning, ai, neural-nets]
date: 2024-03-15T10:30:00Z
---

# Introduction to Deep Learning

Neural networks have revolutionized artificial intelligence.
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, equals('Deep Learning Architectures'));
      expect(parsed.tags, containsAll(['machine-learning', 'ai', 'neural-nets']));
      expect(parsed.createdAt, equals(DateTime.parse('2024-03-15T10:30:00Z')));
      expect(parsed.updatedAt, equals(DateTime.parse('2024-03-15T10:30:00Z')));
      // Body preserves full content as-is (do not remove frontmatter)
      expect(parsed.body, equals(content));
    });

    test('extracts single quoted title and multiline yaml list tags', () {
      const content = """---
title: 'Flutter & Riverpod Guide'
tags:
  - flutter
  - riverpod
  - state-management
created: 2023-11-20 14:00:00
updated: 2023-12-01 18:30:00
---
This is a note about state management in Flutter.
""";

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, equals('Flutter & Riverpod Guide'));
      expect(parsed.tags, containsAll(['flutter', 'riverpod', 'state-management']));
      expect(parsed.createdAt, equals(DateTime.parse('2023-11-20 14:00:00')));
      expect(parsed.updatedAt, equals(DateTime.parse('2023-12-01 18:30:00')));
      expect(parsed.body, equals(content));
    });

    test('handles unquoted title, epoch timestamp date, and comma-separated tags', () {
      const content = '''---
title: Simple Unquoted Title
tags: ideas, design, typography
created_at: 1683715200
updated_at: 1683801600
---
Body text here
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, equals('Simple Unquoted Title'));
      expect(parsed.tags, containsAll(['ideas', 'design', 'typography']));
      expect(parsed.createdAt, equals(DateTime.fromMillisecondsSinceEpoch(1683715200 * 1000)));
      expect(parsed.updatedAt, equals(DateTime.fromMillisecondsSinceEpoch(1683801600 * 1000)));
      expect(parsed.body, equals(content));
    });

    test('returns null title and full content when no frontmatter is present', () {
      const content = '''# Just a normal markdown file

Without any frontmatter header.
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, isNull);
      expect(parsed.tags, isEmpty);
      expect(parsed.createdAt, isNull);
      expect(parsed.updatedAt, isNull);
      expect(parsed.body, equals(content));
    });

    test('extracts author, source, created, description and strips frontmatter into contentBody', () {
      const content = '''---
title: "Obsidian & Bear Research"
author: Jane Doe
source: https://quietpaper.app/research
created: 2026-08-15
description: A study on minimal note taking tools.
status: published
rating: 5
custom_key: hidden_property
---

# Introduction
This is the actual note content body.
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, equals('Obsidian & Bear Research'));
      expect(parsed.author, equals('Jane Doe'));
      expect(parsed.source, equals('https://quietpaper.app/research'));
      expect(parsed.createdAt, equals(DateTime.parse('2026-08-15')));
      expect(parsed.createdRaw, equals('2026-08-15'));
      expect(parsed.description, equals('A study on minimal note taking tools.'));
      expect(parsed.hasFrontmatter, isTrue);
      expect(parsed.hasDisplayableMetadata, isTrue);
      expect(parsed.body, equals(content));
      expect(parsed.contentBody.trim(), startsWith('# Introduction'));
      expect(parsed.contentBody, isNot(contains('---')));
      expect(parsed.contentBody, isNot(contains('custom_key')));
    });

    test('handles multiline author list and folded multiline description', () {
      const content = '''---
author:
  - Alice Walker
  - Bob Dylan
source: 'https://example.com/multi'
created: August 18, 2026
description: >
  This is a folded multiline description
  that spans multiple lines of text.
---
Body text here
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.author, equals('Alice Walker, Bob Dylan'));
      expect(parsed.source, equals('https://example.com/multi'));
      expect(parsed.createdRaw, equals('August 18, 2026'));
      expect(parsed.description, equals('This is a folded multiline description that spans multiple lines of text.'));
      expect(parsed.hasFrontmatter, isTrue);
      expect(parsed.hasDisplayableMetadata, isTrue);
      expect(parsed.contentBody.trim(), equals('Body text here'));
    });

    test('correctly identifies frontmatter with only unrecognized keys', () {
      const content = '''---
status: draft
reviewer: John
custom_id: 12345
---
# Clean Body
Only this body should be rendered.
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, isNull);
      expect(parsed.author, isNull);
      expect(parsed.source, isNull);
      expect(parsed.description, isNull);
      expect(parsed.hasFrontmatter, isTrue);
      expect(parsed.hasDisplayableMetadata, isFalse);
      expect(parsed.contentBody.trim(), equals('# Clean Body\nOnly this body should be rendered.'));
    });
  });
}

