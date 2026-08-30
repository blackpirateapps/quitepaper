import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/markdown/markdown_helper.dart';

void main() {
  group('MarkdownHelper - Code Block Language Helpers', () {
    test('detects active code block language when cursor is inside', () {
      const text = '# Header\n\n```dart\nfinal x = 42;\n```\n\nAfter';
      // Cursor inside Dart block at "final x"
      final val = const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 20),
      );

      final lang = MarkdownHelper.getCodeBlockLanguageAtCursor(val);
      expect(lang, equals('dart'));
    });

    test('returns null when cursor is outside any code block', () {
      const text = '# Header\n\n```dart\nfinal x = 42;\n```\n\nAfter';
      // Cursor at "# Header"
      final val = const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 2),
      );

      final lang = MarkdownHelper.getCodeBlockLanguageAtCursor(val);
      expect(lang, isNull);
    });

    test('changes code block language seamlessly without moving cursor offset undesirably', () {
      const text = '```dart\nfinal x = 42;\n```';
      final val = const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 12),
      );

      final updated = MarkdownHelper.changeCodeBlockLanguage(
        value: val,
        newLanguage: 'python',
      );

      expect(updated.text, equals('```python\nfinal x = 42;\n```'));
      expect(updated.selection.isValid, isTrue);
    });

    test('inserts code block with specified language', () {
      const val = TextEditingValue.empty;
      final updated = MarkdownHelper.insertCodeBlock(val, language: 'rust');

      expect(updated.text, contains('```rust\n'));
      expect(updated.text, contains('\n```\n'));
    });
  });
}
