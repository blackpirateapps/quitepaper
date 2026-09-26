import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/code_block_scanner.dart';

void main() {
  group('isInsideFencedCodeBlock (P3-4 shared scanner)', () {
    test('returns false when there are no fences', () {
      expect(isInsideFencedCodeBlock('plain text', 5), isFalse);
    });

    test('returns false at offset 0 or on empty text', () {
      expect(isInsideFencedCodeBlock('```\ncode', 0), isFalse);
      expect(isInsideFencedCodeBlock('', 3), isFalse);
    });

    test('detects a caret inside an open ``` fence', () {
      const text = '```dart\nfinal x = 1;';
      expect(isInsideFencedCodeBlock(text, text.length), isTrue);
    });

    test('detects a caret inside an open ~~~ fence', () {
      const text = '~~~\nsome code';
      expect(isInsideFencedCodeBlock(text, text.length), isTrue);
    });

    test('returns false after a closed fence pair', () {
      const text = '```\ncode\n```\nafter';
      expect(isInsideFencedCodeBlock(text, text.length), isFalse);
    });

    test('P3-4 counts fence lines, not raw occurrences (multi-fence)', () {
      // Three separate code blocks then plain text. A naive backward search
      // that miscounts overlapping ``` occurrences would flip the parity; the
      // line-based scanner must report the caret is OUTSIDE (even fence count).
      const text = '```\na\n```\n```\nb\n```\nplain';
      expect(isInsideFencedCodeBlock(text, text.length), isFalse);

      // Caret inside the third (still-open) block is inside.
      const openText = '```\na\n```\n```\nb\n```\n```\nstill open';
      expect(isInsideFencedCodeBlock(openText, openText.length), isTrue);
    });

    test('inline backticks on the caret line are not treated as a fence', () {
      const text = 'here is `inline code` and #tag';
      expect(isInsideFencedCodeBlock(text, text.length), isFalse);
    });

    test('fence on the caret own line does not count', () {
      // Caret sits on the opening fence line itself -> not yet inside.
      const text = 'text\n```dart';
      expect(isInsideFencedCodeBlock(text, text.length), isFalse);
    });

    test('respects leading whitespace before a fence', () {
      const text = '   ```\ncode';
      expect(isInsideFencedCodeBlock(text, text.length), isTrue);
    });
  });
}
