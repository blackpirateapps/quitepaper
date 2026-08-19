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
  });
}
