import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/note_link_autocomplete_trigger.dart';

void main() {
  group('NoteLinkAutocompleteTrigger', () {
    test('detects double bracket trigger with empty query', () {
      const text = 'Check out [[';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 12),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 10);
      expect(trigger.queryStart, 12);
      expect(trigger.queryEnd, 12);
      expect(trigger.query, '');
    });

    test('detects double bracket trigger with active query', () {
      const text = 'Check out [[Quantum Physics';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 27),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 10);
      expect(trigger.queryStart, 12);
      expect(trigger.queryEnd, 27);
      expect(trigger.query, 'Quantum Physics');
    });

    test('ignores closed bracket [[query]]', () {
      const text = 'Check out [[Quantum Physics]] and more';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 38),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('ignores trigger inside code block', () {
      const text = '```dart\nfinal x = [[foo;\n```';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 23),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('ignores escaped brackets', () {
      const text = r'Escaped \[[not a trigger';
      final value = TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 24),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('ignores when selection is not collapsed', () {
      const text = 'Check out [[Quantum';
      final value = const TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 12, extentOffset: 19),
      );

      final trigger = NoteLinkAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });
  });
}
