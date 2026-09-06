import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/markdown/markdown_checklist_helper.dart';

void main() {
  group('MarkdownChecklistHelper.countChecklistItems', () {
    test('returns 0 for empty or plain text without checklist items', () {
      expect(MarkdownChecklistHelper.countChecklistItems(''), equals(0));
      expect(
        MarkdownChecklistHelper.countChecklistItems('Hello world\nAnother line'),
        equals(0),
      );
      expect(
        MarkdownChecklistHelper.countChecklistItems('- Bullet item\n1. Numbered item'),
        equals(0),
      );
    });

    test('counts standard unordered checklist items', () {
      const text = '''
- [ ] Item 1
- [x] Item 2
* [ ] Item 3
* [x] Item 4
+ [ ] Item 5
+ [X] Item 6
''';
      expect(MarkdownChecklistHelper.countChecklistItems(text), equals(6));
    });

    test('counts ordered, indented, and blockquote checklist items', () {
      const text = '''
1. [ ] Ordered task
  - [ ] Indented task
    - [x] Sub-task
> - [ ] Task in quote
''';
      expect(MarkdownChecklistHelper.countChecklistItems(text), equals(4));
    });

    test('ignores checklist syntax inside fenced code blocks', () {
      const text = '''
- [ ] Real task 1
```markdown
- [ ] Fake task in fence
- [x] Another fake task
```
- [x] Real task 2
~~~dart
- [ ] Fake task in tilde fence
~~~
- [ ] Real task 3
''';
      expect(MarkdownChecklistHelper.countChecklistItems(text), equals(3));
    });
  });

  group('MarkdownChecklistHelper.toggleChecklistItem', () {
    test('toggles unchecked item to checked', () {
      const input = '- [ ] Buy groceries';
      final result = MarkdownChecklistHelper.toggleChecklistItem(input, 0);
      expect(result, equals('- [x] Buy groceries'));
    });

    test('toggles checked lowercase item to unchecked', () {
      const input = '- [x] Buy groceries';
      final result = MarkdownChecklistHelper.toggleChecklistItem(input, 0);
      expect(result, equals('- [ ] Buy groceries'));
    });

    test('toggles checked uppercase item to unchecked', () {
      const input = '- [X] Buy groceries';
      final result = MarkdownChecklistHelper.toggleChecklistItem(input, 0);
      expect(result, equals('- [ ] Buy groceries'));
    });

    test('toggles correct item by targetIndex across multiple items', () {
      const input = '''
- [ ] Task A
- [x] Task B
- [ ] Task C
''';
      // Toggle Task B (index 1) to unchecked
      final res1 = MarkdownChecklistHelper.toggleChecklistItem(input, 1);
      expect(res1, equals('''
- [ ] Task A
- [ ] Task B
- [ ] Task C
'''));

      // Toggle Task C (index 2) to checked
      final res2 = MarkdownChecklistHelper.toggleChecklistItem(input, 2);
      expect(res2, equals('''
- [ ] Task A
- [x] Task B
- [x] Task C
'''));
    });

    test('ignores code blocks when indexing and toggling items', () {
      const input = '''
- [ ] Task 1
```
- [ ] Fake task
```
- [ ] Task 2
''';
      // Toggling index 1 should toggle Task 2, NOT Fake task!
      final result = MarkdownChecklistHelper.toggleChecklistItem(input, 1);
      expect(result, equals('''
- [ ] Task 1
```
- [ ] Fake task
```
- [x] Task 2
'''));
    });

    test('preserves YAML frontmatter completely intact', () {
      const input = '''---
title: My Note
tags: [test, checklist]
---
# Header
- [ ] First task
- [ ] Second task
''';
      final result = MarkdownChecklistHelper.toggleChecklistItem(input, 0);
      expect(result, equals('''---
title: My Note
tags: [test, checklist]
---
# Header
- [x] First task
- [ ] Second task
'''));
    });

    test('returns original string if index is out of bounds or negative', () {
      const input = '- [ ] Only task';
      expect(MarkdownChecklistHelper.toggleChecklistItem(input, -1), equals(input));
      expect(MarkdownChecklistHelper.toggleChecklistItem(input, 5), equals(input));
    });
  });

  group('MarkdownChecklistHelper.preparePreviewMarkdown', () {
    test('wraps checked item text with strikethrough delimiters', () {
      const input = '''
- [ ] Unchecked task
- [x] Checked task
* [X] Asterisk checked task
''';
      final output = MarkdownChecklistHelper.preparePreviewMarkdown(input);
      expect(output, contains('- [ ] Unchecked task'));
      expect(output, contains('- [x] ~~Checked task~~'));
      expect(output, contains('* [X] ~~Asterisk checked task~~'));
    });

    test('does not double-wrap if already wrapped in strikethrough', () {
      const input = '- [x] ~~Already struck~~';
      final output = MarkdownChecklistHelper.preparePreviewMarkdown(input);
      expect(output, equals('- [x] ~~Already struck~~'));
    });

    test('handles empty tasks without breaking', () {
      const input = '- [x] ';
      final output = MarkdownChecklistHelper.preparePreviewMarkdown(input);
      expect(output, equals('- [x] '));
    });

    test('preserves code blocks without applying strikethrough inside them', () {
      const input = '''
```
- [x] Inside code
```
- [x] Outside code
''';
      final output = MarkdownChecklistHelper.preparePreviewMarkdown(input);
      expect(output, contains('- [x] Inside code'));
      expect(output, isNot(contains('- [x] ~~Inside code~~')));
      expect(output, contains('- [x] ~~Outside code~~'));
    });
  });
}
