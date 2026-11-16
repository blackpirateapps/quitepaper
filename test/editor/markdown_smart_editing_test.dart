import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_text_input_formatter.dart';

void main() {
  const formatter = MarkdownTextInputFormatter();

  for (final entry in <String, String>{
    '> - [ ] Alpha': '> - [ ] ',
    '> > - [x] Alpha': '> > - [ ] ',
    '1. [ ] Alpha': '2. [ ] ',
    '  9) [X] Alpha': '  10) [ ] ',
    '> 3. [x] Alpha': '> 4. [ ] ',
  }.entries) {
    test('CL-07 continues compound task ${entry.key}', () {
      final text = entry.key;
      final result = formatter.formatEditUpdate(
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
        TextEditingValue(text: '$text\n', selection: TextSelection.collapsed(offset: text.length + 1)),
      );
      expect(result.text, '$text\n${entry.value}');
      expect(result.selection.extentOffset, result.text.length);
    });
  }
  for (final reversed in [false, true]) {
    test('CL-07 selected task text is replaced and continuation retained reverse=$reversed', () {
      const text = '- [ ] AlphaBeta';
      final result = formatter.formatEditUpdate(
        TextEditingValue(text: text, selection: TextSelection(baseOffset: reversed ? 13 : 8, extentOffset: reversed ? 8 : 13)),
        const TextEditingValue(text: '- [ ] Al\nta', selection: TextSelection.collapsed(offset: 9)),
      );
      expect(result.text, '- [ ] Al\n- [ ] ta');
      expect(result.selection.extentOffset, 15);
    });
  }

  group('MarkdownTextInputFormatter - Smart Checklists', () {
    test('continues checklist on Enter: - [ ] Task -> - [ ] Task\\n- [ ] ', () {
      const oldVal = TextEditingValue(
        text: '- [ ] Buy groceries',
        selection: TextSelection.collapsed(offset: 19),
      );
      const newVal = TextEditingValue(
        text: '- [ ] Buy groceries\n',
        selection: TextSelection.collapsed(offset: 20),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('- [ ] Buy groceries\n- [ ] '));
      expect(result.selection.baseOffset, equals(26));
    });

    test('continues completed task with new uncompleted task: - [x] Done -> - [ ] ', () {
      const oldVal = TextEditingValue(
        text: '- [x] Completed task',
        selection: TextSelection.collapsed(offset: 20),
      );
      const newVal = TextEditingValue(
        text: '- [x] Completed task\n',
        selection: TextSelection.collapsed(offset: 21),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('- [x] Completed task\n- [ ] '));
      expect(result.selection.baseOffset, equals(27));
    });

    test('clears empty checklist on Enter: - [ ] -> empty', () {
      const oldVal = TextEditingValue(
        text: '- [ ] Task 1\n- [ ] ',
        selection: TextSelection.collapsed(offset: 19),
      );
      const newVal = TextEditingValue(
        text: '- [ ] Task 1\n- [ ] \n',
        selection: TextSelection.collapsed(offset: 20),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('- [ ] Task 1\n'));
      expect(result.selection.baseOffset, equals(13));
    });
  });

  group('MarkdownTextInputFormatter - Code Block Safety', () {
    test('does not insert list/quote prefix inside fenced code blocks', () {
      const oldVal = TextEditingValue(
        text: '```\nconst a = 1;',
        selection: TextSelection.collapsed(offset: 16),
      );
      const newVal = TextEditingValue(
        text: '```\nconst a = 1;\n',
        selection: TextSelection.collapsed(offset: 17),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('```\nconst a = 1;\n'));
      expect(result.selection.baseOffset, equals(17));
    });
  });

  group('MarkdownTextInputFormatter - Auto-Pairing & Delimiter Skipping', () {
    test('wraps selected text when typing *', () {
      const oldVal = TextEditingValue(
        text: 'Hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11), // "world"
      );
      const newVal = TextEditingValue(
        text: 'Hello *',
        selection: TextSelection.collapsed(offset: 7),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('Hello *world*'));
      expect(result.selection.baseOffset, equals(7));
      expect(result.selection.extentOffset, equals(12));
    });

    test('wraps selected text when typing [', () {
      const oldVal = TextEditingValue(
        text: 'Visit Google',
        selection: TextSelection(baseOffset: 6, extentOffset: 12), // "Google"
      );
      const newVal = TextEditingValue(
        text: 'Visit [',
        selection: TextSelection.collapsed(offset: 7),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('Visit [Google]'));
      expect(result.selection.baseOffset, equals(7));
      expect(result.selection.extentOffset, equals(13));
    });

    test('skips closing delimiter when typing * before existing *', () {
      const oldVal = TextEditingValue(
        text: 'Hello *world*',
        selection: TextSelection.collapsed(offset: 12), // right before trailing *
      );
      const newVal = TextEditingValue(
        text: 'Hello *world**',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, equals('Hello *world*'));
      expect(result.selection.baseOffset, equals(13));
    });
  });
}
