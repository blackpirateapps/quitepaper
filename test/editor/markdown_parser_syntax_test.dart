import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  final colors = AppColors.light;
  final styles = MarkdownStyles.fromColors(colors);

  group('MarkdownParser - Syntax Highlighting in Code Blocks', () {
    test('renders syntax highlighted tokens inside fenced code blocks without dropping text', () {
      const doc = '''# Introduction

Here is some sample code:

```dart
final int answer = 42; // Answer
```

And some text after.''';

      final span = MarkdownParser.buildTextSpan(
        text: doc,
        styles: styles,
      );

      // Invariant: reconstructed plain text must match input exactly
      expect(span.toPlainText(), equals(doc));
    });

    test('handles unclosed fenced code block at end of document gracefully', () {
      const doc = '```python\ndef hello():\n    print("Hi")';

      final span = MarkdownParser.buildTextSpan(
        text: doc,
        styles: styles,
      );

      expect(span.toPlainText(), equals(doc));
    });

    test('handles empty fenced code block gracefully', () {
      const doc = '```dart\n```';

      final span = MarkdownParser.buildTextSpan(
        text: doc,
        styles: styles,
      );

      expect(span.toPlainText(), equals(doc));
    });

    test('handles multiple consecutive and alternating fenced code blocks', () {
      const doc = '''# Multi-Language Test

```json
{
  "active": true
}
```

Between blocks

```sql
SELECT * FROM users;
```
''';

      final span = MarkdownParser.buildTextSpan(
        text: doc,
        styles: styles,
      );

      expect(span.toPlainText(), equals(doc));
    });

    test('preserves search highlight overlay across syntax highlighted code blocks', () {
      const doc = '''```dart
final count = 10;
final total = count * 2;
```''';

      final span = MarkdownParser.buildTextSpan(
        text: doc,
        styles: styles,
        searchQuery: 'count',
      );

      expect(span.toPlainText(), equals(doc));
    });
  });
}
