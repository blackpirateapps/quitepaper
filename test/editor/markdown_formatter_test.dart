import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_formatter.dart';

void main() {
  group('MarkdownFormatter - Bold', () {
    test('wraps selected text in **', () {
      const initial = TextEditingValue(
        text: 'Hello world today',
        selection: TextSelection(baseOffset: 6, extentOffset: 11), // "world"
      );

      final result = MarkdownFormatter.toggleBold(value: initial);
      expect(result.text, equals('Hello **world** today'));
      expect(result.selection.baseOffset, equals(8));
      expect(result.selection.extentOffset, equals(13));
    });

    test('toggles off when selection includes **', () {
      const initial = TextEditingValue(
        text: 'Hello **world** today',
        selection: TextSelection(baseOffset: 6, extentOffset: 15), // "**world**"
      );

      final result = MarkdownFormatter.toggleBold(value: initial);
      expect(result.text, equals('Hello world today'));
      expect(result.selection.baseOffset, equals(6));
      expect(result.selection.extentOffset, equals(11));
    });

    test('toggles off when selection is surrounded by ** in text', () {
      const initial = TextEditingValue(
        text: 'Hello **world** today',
        selection: TextSelection(baseOffset: 8, extentOffset: 13), // "world"
      );

      final result = MarkdownFormatter.toggleBold(value: initial);
      expect(result.text, equals('Hello world today'));
      expect(result.selection.baseOffset, equals(6));
      expect(result.selection.extentOffset, equals(11));
    });

    test('inserts **** at cursor when collapsed', () {
      const initial = TextEditingValue(
        text: 'Hello ',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = MarkdownFormatter.toggleBold(value: initial);
      expect(result.text, equals('Hello ****'));
      expect(result.selection.baseOffset, equals(8));
    });
  });

  group('MarkdownFormatter - Italic', () {
    test('wraps selected text in *', () {
      const initial = TextEditingValue(
        text: 'Hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );

      final result = MarkdownFormatter.toggleItalic(value: initial);
      expect(result.text, equals('Hello *world*'));
      expect(result.selection.baseOffset, equals(7));
      expect(result.selection.extentOffset, equals(12));
    });

    test('toggles off when selection is surrounded by *', () {
      const initial = TextEditingValue(
        text: 'Hello *world*',
        selection: TextSelection(baseOffset: 7, extentOffset: 12),
      );

      final result = MarkdownFormatter.toggleItalic(value: initial);
      expect(result.text, equals('Hello world'));
    });
  });

  group('MarkdownFormatter - Strikethrough & Inline Code', () {
    test('toggles strikethrough ~~ on selection', () {
      const initial = TextEditingValue(
        text: 'Delete this item',
        selection: TextSelection(baseOffset: 7, extentOffset: 11), // "this"
      );

      final result = MarkdownFormatter.toggleStrikethrough(value: initial);
      expect(result.text, equals('Delete ~~this~~ item'));

      final toggledOff = MarkdownFormatter.toggleStrikethrough(value: result);
      expect(toggledOff.text, equals('Delete this item'));
    });

    test('toggles inline code ` on selection', () {
      const initial = TextEditingValue(
        text: 'Use print() in Dart',
        selection: TextSelection(baseOffset: 4, extentOffset: 11), // "print()"
      );

      final result = MarkdownFormatter.toggleInlineCode(value: initial);
      expect(result.text, equals('Use `print()` in Dart'));

      final toggledOff = MarkdownFormatter.toggleInlineCode(value: result);
      expect(toggledOff.text, equals('Use print() in Dart'));
    });
  });

  group('MarkdownFormatter - Links', () {
    test('creates markdown link with selected text', () {
      const initial = TextEditingValue(
        text: 'Visit Google today',
        selection: TextSelection(baseOffset: 6, extentOffset: 12), // "Google"
      );

      final result = MarkdownFormatter.createLink(
        value: initial,
        url: 'https://google.com',
      );

      expect(result.text, equals('Visit [Google](https://google.com) today'));
      expect(result.selection.baseOffset, equals(34));
    });

    test('creates markdown link with custom title when no selection', () {
      const initial = TextEditingValue(
        text: 'Visit ',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = MarkdownFormatter.createLink(
        value: initial,
        url: 'https://openai.com',
        title: 'OpenAI',
      );

      expect(result.text, equals('Visit [OpenAI](https://openai.com)'));
    });
  });

  group('MarkdownFormatter - Multi-line Lists & Checklists', () {
    test('toggles checklist across multiple lines', () {
      const initial = TextEditingValue(
        text: 'Buy milk\nBuy eggs\nWash car',
        selection: TextSelection(baseOffset: 0, extentOffset: 26),
      );

      final result = MarkdownFormatter.toggleChecklist(value: initial);
      expect(result.text, equals('- [ ] Buy milk\n- [ ] Buy eggs\n- [ ] Wash car'));

      // Toggling again marks them all as checked
      final checked = MarkdownFormatter.toggleChecklist(value: result);
      expect(checked.text, equals('- [x] Buy milk\n- [x] Buy eggs\n- [x] Wash car'));

      // Toggling again marks them all as unchecked
      final unchecked = MarkdownFormatter.toggleChecklist(value: checked);
      expect(unchecked.text, equals('- [ ] Buy milk\n- [ ] Buy eggs\n- [ ] Wash car'));
    });

    test('converts existing bullets to checklists', () {
      const initial = TextEditingValue(
        text: '- Item A\n- Item B',
        selection: TextSelection(baseOffset: 0, extentOffset: 16),
      );

      final result = MarkdownFormatter.toggleChecklist(value: initial);
      expect(result.text, equals('- [ ] Item A\n- [ ] Item B'));
    });

    test('toggles bullet list across multiple lines', () {
      const initial = TextEditingValue(
        text: 'First\nSecond\nThird',
        selection: TextSelection(baseOffset: 0, extentOffset: 17),
      );

      final result = MarkdownFormatter.toggleBulletList(value: initial);
      expect(result.text, equals('- First\n- Second\n- Third'));

      final toggledOff = MarkdownFormatter.toggleBulletList(value: result);
      expect(toggledOff.text, equals('First\nSecond\nThird'));
    });

    test('toggles numbered list sequentially across multiple lines', () {
      const initial = TextEditingValue(
        text: 'First\nSecond\nThird',
        selection: TextSelection(baseOffset: 0, extentOffset: 17),
      );

      final result = MarkdownFormatter.toggleOrderedList(value: initial);
      expect(result.text, equals('1. First\n2. Second\n3. Third'));

      final toggledOff = MarkdownFormatter.toggleOrderedList(value: result);
      expect(toggledOff.text, equals('First\nSecond\nThird'));
    });

    test('toggling list with collapsed cursor keeps cursor collapsed at end of line without selecting line', () {
      const initial = TextEditingValue(
        text: 'Single line item',
        selection: TextSelection.collapsed(offset: 16),
      );

      final bulletResult = MarkdownFormatter.toggleBulletList(value: initial);
      expect(bulletResult.text, equals('- Single line item'));
      expect(bulletResult.selection.isCollapsed, isTrue);
      expect(bulletResult.selection.baseOffset, equals(18));

      final orderedResult = MarkdownFormatter.toggleOrderedList(value: initial);
      expect(orderedResult.text, equals('1. Single line item'));
      expect(orderedResult.selection.isCollapsed, isTrue);
      expect(orderedResult.selection.baseOffset, equals(19));

      final checkResult = MarkdownFormatter.toggleChecklist(value: initial);
      expect(checkResult.text, equals('- [ ] Single line item'));
      expect(checkResult.selection.isCollapsed, isTrue);
      expect(checkResult.selection.baseOffset, equals(22));
    });
  });
}
