import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';

void main() {
  group('TagParser.extractTags', () {
    test('extracts single and multiple hashtags', () {
      expect(
        TagParser.extractTags('Hello #work and #project'),
        equals(['project', 'work']),
      );
    });

    test('extracts nested/hierarchical tags', () {
      expect(
        TagParser.extractTags('Note with #work/client/project'),
        equals(['work/client/project']),
      );
    });

    test('ignores markdown headers', () {
      expect(
        TagParser.extractTags('# Header 1\n## Header 2\n### Header 3'),
        isEmpty,
      );
    });

    test('ignores hashtags inside code blocks and inline code', () {
      const text = '''
#real_tag
```dart
// #fake_code_tag
```
`#fake_inline_tag`
''';
      expect(
        TagParser.extractTags(text),
        equals(['real_tag']),
      );
    });
  });

  group('TagParser.removeTagFromText', () {
    test('removes hashtag from middle of sentence without leaving double spaces', () {
      const text = 'Hello #work world';
      expect(TagParser.removeTagFromText(text, 'work'), equals('Hello world'));
    });

    test('removes hashtag at beginning of sentence', () {
      const text = '#work Meeting with client';
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('Meeting with client'),
      );
    });

    test('removes hashtag at end of sentence', () {
      const text = 'Meeting with client #work';
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('Meeting with client'),
      );
    });

    test('removes standalone hashtag line cleanly without blank line', () {
      const text = 'First line\n#work\nSecond line';
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('First line\nSecond line'),
      );
    });

    test('removes solitary hashtag resulting in empty string', () {
      expect(TagParser.removeTagFromText('#work', 'work'), equals(''));
      expect(TagParser.removeTagFromText('   #work   ', 'work'), equals(''));
    });

    test('removes case-insensitively', () {
      expect(
        TagParser.removeTagFromText('Important #WORK item', 'work'),
        equals('Important item'),
      );
      expect(
        TagParser.removeTagFromText('Important #Work item', 'work'),
        equals('Important item'),
      );
    });

    test('removes multiple occurrences of the same tag', () {
      const text = 'First #work and second #work';
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('First and second'),
      );
    });

    test('handles tag followed by punctuation cleanly', () {
      expect(
        TagParser.removeTagFromText('Review #work, then send.', 'work'),
        equals('Review, then send.'),
      );
      expect(
        TagParser.removeTagFromText('Review #work.', 'work'),
        equals('Review.'),
      );
      expect(
        TagParser.removeTagFromText('Tagged (#work) here', 'work'),
        equals('Tagged () here'),
      );
    });

    test('preserves other hashtags when deleting a specific tag', () {
      const text = 'Meeting #work #urgent notes';
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('Meeting #urgent notes'),
      );
    });

    test('does not remove partial nested tag matches', () {
      const text = 'Check #work/project/v1';
      // Removing 'work' should not corrupt '#work/project/v1'
      expect(
        TagParser.removeTagFromText(text, 'work'),
        equals('Check #work/project/v1'),
      );
      // Removing 'work/project/v1' should remove it cleanly
      expect(
        TagParser.removeTagFromText(text, 'work/project/v1'),
        equals('Check'),
      );
    });

    test('preserves code blocks and inline code containing matching hashtag', () {
      const text = '#work\n'
          '```\n'
          '#work inside code block\n'
          '```\n'
          '`#work inline code`\n'
          'End #work';
      final result = TagParser.removeTagFromText(text, 'work');
      expect(
        result,
        equals('```\n#work inside code block\n```\n`#work inline code`\nEnd'),
      );
    });

    test('removes tags from YAML frontmatter array format', () {
      const text = '''---
title: My Note
tags: [work, urgent]
---
Body text #work''';

      final result = TagParser.removeTagFromText(text, 'work');
      expect(
        result,
        equals('---'
            '\ntitle: My Note'
            '\ntags: [urgent]'
            '\n---'
            '\nBody text'),
      );
    });

    test('removes tags from YAML frontmatter multiline list format', () {
      const text = '''---
title: My Note
tags:
  - work
  - urgent
---
Body text''';

      final result = TagParser.removeTagFromText(text, 'work');
      expect(
        result,
        equals('---'
            '\ntitle: My Note'
            '\ntags:'
            '\n  - urgent'
            '\n---'
            '\nBody text'),
      );
    });

    test('removes single tag from YAML frontmatter leaving empty list', () {
      const text = '''---
title: My Note
tags: [work]
---
Body text''';

      final result = TagParser.removeTagFromText(text, 'work');
      expect(
        result,
        equals('---'
            '\ntitle: My Note'
            '\ntags: []'
            '\n---'
            '\nBody text'),
      );
    });
  });

  group('TagParser.renameTagInText', () {
    test('renames tag in middle of sentence', () {
      const text = 'Working on #programming today';
      expect(
        TagParser.renameTagInText(text, 'programming', 'development'),
        equals('Working on #development today'),
      );
    });

    test('renames tag at start and end of line', () {
      const text = '#programming is cool\nI love #programming';
      expect(
        TagParser.renameTagInText(text, 'programming', 'development'),
        equals('#development is cool\nI love #development'),
      );
    });

    test('renames tag inside punctuation and parentheses', () {
      const text = 'Tags: (#programming), [#programming], "#programming"';
      expect(
        TagParser.renameTagInText(text, 'programming', 'development'),
        equals('Tags: (#development), [#development], "#development"'),
      );
    });

    test('does NOT rename markdown headers', () {
      const text = '# Header 1\n## Header 2\n#programming';
      expect(
        TagParser.renameTagInText(text, 'programming', 'development'),
        equals('# Header 1\n## Header 2\n#development'),
      );
    });

    test('does NOT rename tags inside fenced code blocks', () {
      const text = '''
#programming
```dart
// #programming should remain intact
```
~~~
#programming should also remain intact
~~~
#programming
''';
      final result = TagParser.renameTagInText(text, 'programming', 'development');
      expect(result.contains('#development'), isTrue);
      expect(result.contains('// #programming should remain intact'), isTrue);
      expect(result.contains('#programming should also remain intact'), isTrue);
    });

    test('does NOT rename tags inside inline code spans', () {
      const text = 'Use `#programming` tag, but see #programming here';
      expect(
        TagParser.renameTagInText(text, 'programming', 'development'),
        equals('Use `#programming` tag, but see #development here'),
      );
    });

    test('renames in YAML frontmatter inline list and multiline list', () {
      const text = '''---
title: Project Note
tags: [programming, flutter]
---
#programming in body''';

      final result = TagParser.renameTagInText(text, 'programming', 'development');
      expect(
        result,
        equals('---'
            '\ntitle: Project Note'
            '\ntags: [development, flutter]'
            '\n---'
            '\n#development in body'),
      );
    });

    test('renames in YAML frontmatter multiline list', () {
      const text = '''---
tags:
  - programming
  - mobile
---
Note body''';

      final result = TagParser.renameTagInText(text, 'programming', 'development');
      expect(
        result,
        equals('---'
            '\ntags:'
            '\n  - development'
            '\n  - mobile'
            '\n---'
            '\nNote body'),
      );
    });
  });

  group('TagParser.mergeTagsInText', () {
    test('renames source tag to destination when destination does not exist', () {
      const text = 'Note about #flutter-dev';
      expect(
        TagParser.mergeTagsInText(text, 'flutter-dev', 'flutter'),
        equals('Note about #flutter'),
      );
    });

    test('removes source tag when destination tag already exists to avoid duplicates', () {
      const text = 'Note about #flutter and #flutter-dev';
      expect(
        TagParser.mergeTagsInText(text, 'flutter-dev', 'flutter'),
        equals('Note about #flutter and'),
      );
    });
  });
}
