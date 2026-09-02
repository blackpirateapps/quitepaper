import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_text_input_formatter.dart';

void main() {
  const formatter = MarkdownTextInputFormatter();

  group('MarkdownTextInputFormatter', () {
    test('auto-continues unordered list on newline', () {
      const oldValue = TextEditingValue(
        text: '- First item',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '- First item\n',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- First item\n- '));
      expect(result.selection.baseOffset, equals(15));
    });

    test('auto-increments ordered list on newline', () {
      const oldValue = TextEditingValue(
        text: '1. Step one',
        selection: TextSelection.collapsed(offset: 11),
      );
      const newValue = TextEditingValue(
        text: '1. Step one\n',
        selection: TextSelection.collapsed(offset: 12),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Step one\n2. '));
      expect(result.selection.baseOffset, equals(15));
    });

    test('auto-continues blockquote on newline', () {
      const oldValue = TextEditingValue(
        text: '> A wise thought',
        selection: TextSelection.collapsed(offset: 16),
      );
      const newValue = TextEditingValue(
        text: '> A wise thought\n',
        selection: TextSelection.collapsed(offset: 17),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('> A wise thought\n> '));
      expect(result.selection.baseOffset, equals(19));
    });

    test('clears empty unordered bullet when pressing Enter on empty bullet', () {
      const oldValue = TextEditingValue(
        text: '- First\n- ',
        selection: TextSelection.collapsed(offset: 10),
      );
      const newValue = TextEditingValue(
        text: '- First\n- \n',
        selection: TextSelection.collapsed(offset: 11),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- First\n'));
      expect(result.selection.baseOffset, equals(8));
    });

    test('clears empty ordered list item when pressing Enter on empty number', () {
      const oldValue = TextEditingValue(
        text: '1. First\n2. ',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '1. First\n2. \n',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. First\n'));
      expect(result.selection.baseOffset, equals(9));
    });

    test('clears empty blockquote when pressing Enter on empty quote marker', () {
      const oldValue = TextEditingValue(
        text: '> Quote\n> ',
        selection: TextSelection.collapsed(offset: 10),
      );
      const newValue = TextEditingValue(
        text: '> Quote\n> \n',
        selection: TextSelection.collapsed(offset: 11),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('> Quote\n'));
      expect(result.selection.baseOffset, equals(8));
    });

    test('leaves normal text typing unchanged', () {
      const oldValue = TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 11),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Hello world'));
    });

    test('leaves multiline paste unchanged', () {
      const oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      const newValue = TextEditingValue(
        text: '# Pasted\n- Item 1\n- Item 2',
        selection: TextSelection.collapsed(offset: 26),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('# Pasted\n- Item 1\n- Item 2'));
    });

    test('auto-continues visual bullet list (• item) on newline', () {
      const oldValue = TextEditingValue(
        text: '• First visual item',
        selection: TextSelection.collapsed(offset: 19),
      );
      const newValue = TextEditingValue(
        text: '• First visual item\n',
        selection: TextSelection.collapsed(offset: 20),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('• First visual item\n• '));
      expect(result.selection.baseOffset, equals(22));
    });

    test('clears empty visual bullet list (• ) when pressing Enter', () {
      const oldValue = TextEditingValue(
        text: '• First\n• ',
        selection: TextSelection.collapsed(offset: 10),
      );
      const newValue = TextEditingValue(
        text: '• First\n• \n',
        selection: TextSelection.collapsed(offset: 11),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('• First\n'));
      expect(result.selection.baseOffset, equals(8));
    });

    test('auto-continues visual checklist (Phosphor glyph) on newline', () {
      const oldValue = TextEditingValue(
        text: '\uE45E Buy grocery',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: '\uE45E Buy grocery\n',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('\uE45E Buy grocery\n\uE45E '));
      expect(result.selection.baseOffset, equals(16));
    });

    test('clears empty visual checklist (\uE45E ) when pressing Enter', () {
      const oldValue = TextEditingValue(
        text: '\uE45E Task 1\n\uE45E ',
        selection: TextSelection.collapsed(offset: 11),
      );
      const newValue = TextEditingValue(
        text: '\uE45E Task 1\n\uE45E \n',
        selection: TextSelection.collapsed(offset: 12),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('\uE45E Task 1\n'));
      expect(result.selection.baseOffset, equals(9));
    });

    test('auto-completes divider shortcut when typing 3rd dash on empty line', () {
      const oldValue = TextEditingValue(
        text: '--',
        selection: TextSelection.collapsed(offset: 2),
      );
      const newValue = TextEditingValue(
        text: '---',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('---\n'));
      expect(result.selection.baseOffset, equals(4));
    });

    test('pressing Enter on horizontal rule line advances to new line', () {
      const oldValue = TextEditingValue(
        text: '---',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '---\n',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('---\n'));
      expect(result.selection.baseOffset, equals(4));
    });
  });
}
