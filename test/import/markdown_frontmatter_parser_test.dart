import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/import/application/markdown_frontmatter_parser.dart';

void main() {
  group('MarkdownFrontmatterParser', () {
    test('extracts title, tags, date and cleans body with standard frontmatter', () {
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
      expect(
        parsed.body,
        equals('# Introduction to Deep Learning\n\nNeural networks have revolutionized artificial intelligence.'),
      );
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
      expect(parsed.body, equals('This is a note about state management in Flutter.'));
    });

    test('handles unquoted title and comma-separated tags', () {
      const content = '''---
title: Simple Unquoted Title
tags: ideas, design, typography
date: 2022/05/10
---
Body text here
''';

      final parsed = MarkdownFrontmatterParser.parse(content);

      expect(parsed.title, equals('Simple Unquoted Title'));
      expect(parsed.tags, containsAll(['ideas', 'design', 'typography']));
      expect(parsed.createdAt, equals(DateTime.parse('2022-05-10')));
      expect(parsed.body, equals('Body text here'));
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
      expect(parsed.body, equals('# Just a normal markdown file\n\nWithout any frontmatter header.'));
    });

    test('handles empty content gracefully', () {
      final parsed = MarkdownFrontmatterParser.parse('');
      expect(parsed.title, isNull);
      expect(parsed.tags, isEmpty);
      expect(parsed.body, isEmpty);
    });

    test('handles frontmatter with only title', () {
      const content = '''---
title: Minimal Note
---
Body only
''';
      final parsed = MarkdownFrontmatterParser.parse(content);
      expect(parsed.title, equals('Minimal Note'));
      expect(parsed.tags, isEmpty);
      expect(parsed.body, equals('Body only'));
    });
  });
}
