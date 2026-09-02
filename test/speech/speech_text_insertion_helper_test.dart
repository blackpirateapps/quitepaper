import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/speech/application/speech_text_insertion_helper.dart';

void main() {
  group('SpeechTextInsertionHelper Tests', () {
    test('inserts at end of text with context-aware leading space', () {
      const text = 'Hello world';
      const selection = TextSelection.collapsed(offset: 11);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'and everyone',
      );

      expect(result.text, equals('Hello world and everyone'));
      expect(result.selection,
          equals(const TextSelection.collapsed(offset: 24)));
    });

    test('inserts at start of text with trailing space before existing word',
        () {
      const text = 'world';
      const selection = TextSelection.collapsed(offset: 0);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'Hello',
      );

      expect(result.text, equals('Hello world'));
      expect(result.selection,
          equals(const TextSelection.collapsed(offset: 6)));
    });

    test('replaces selected range with transcript', () {
      const text = 'This is the old text here.';
      // Selection around "the old text" (indices 8 to 20)
      const selection = TextSelection(baseOffset: 8, extentOffset: 20);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'the new text',
      );

      expect(result.text, equals('This is the new text here.'));
      expect(result.selection,
          equals(const TextSelection.collapsed(offset: 20)));
    });

    test('inserts inside empty text without redundant spaces', () {
      const text = '';
      const selection = TextSelection.collapsed(offset: 0);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'First sentence',
      );

      expect(result.text, equals('First sentence'));
      expect(result.selection,
          equals(const TextSelection.collapsed(offset: 14)));
    });

    test('empty transcript returns original text and selection unmodified',
        () {
      const text = 'Untouched note body';
      const selection = TextSelection.collapsed(offset: 9);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: '   ',
      );

      expect(result.text, equals(text));
      expect(result.selection, equals(selection));
    });

    test('inserts after newline without leading space', () {
      const text = '# Title\n';
      const selection = TextSelection.collapsed(offset: 8);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'Body paragraph',
      );

      expect(result.text, equals('# Title\nBody paragraph'));
    });

    test('inserts inside bold markdown preserving delimiters', () {
      const text = '**Hello **';
      // Cursor between "Hello " and "**" (offset 8)
      const selection = TextSelection.collapsed(offset: 8);
      final result = SpeechTextInsertionHelper.insertTranscript(
        currentText: text,
        selection: selection,
        transcript: 'beautiful',
      );

      expect(result.text, equals('**Hello beautiful **'));
    });
  });
}
