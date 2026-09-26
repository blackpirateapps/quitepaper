import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/tag_autocomplete_trigger.dart';

void main() {
  group('TagAutocompleteTrigger Tests', () {
    test('returns null when # is typed alone', () {
      const value = TextEditingValue(
        text: '#',
        selection: TextSelection.collapsed(offset: 1),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('returns null when # is followed by a space (# )', () {
      const value = TextEditingValue(
        text: '# ',
        selection: TextSelection.collapsed(offset: 2),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('detects trigger when # is followed immediately by a single character (#a)', () {
      const value = TextEditingValue(
        text: '#a',
        selection: TextSelection.collapsed(offset: 2),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 0);
      expect(trigger.queryStart, 1);
      expect(trigger.queryEnd, 2);
      expect(trigger.query, 'a');
      expect(trigger.fullLength, 2);
    });

    test('detects trigger with multi-character query (#apple)', () {
      const value = TextEditingValue(
        text: '#apple',
        selection: TextSelection.collapsed(offset: 6),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 0);
      expect(trigger.queryStart, 1);
      expect(trigger.queryEnd, 6);
      expect(trigger.query, 'apple');
    });

    test('detects trigger in the middle of a line after whitespace', () {
      const value = TextEditingValue(
        text: 'Notes for #work',
        selection: TextSelection.collapsed(offset: 15),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 10);
      expect(trigger.queryStart, 11);
      expect(trigger.queryEnd, 15);
      expect(trigger.query, 'work');
    });

    test('detects trigger inside brackets (#nested/tag)', () {
      const value = TextEditingValue(
        text: '(#nested/tag',
        selection: TextSelection.collapsed(offset: 12),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 1);
      expect(trigger.query, 'nested/tag');
    });

    test('returns null when preceded by alphanumeric character (word#tag)', () {
      const value = TextEditingValue(
        text: 'word#tag',
        selection: TextSelection.collapsed(offset: 8),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('returns null when escaped with backslash (\\#tag)', () {
      const value = TextEditingValue(
        text: r'\#tag',
        selection: TextSelection.collapsed(offset: 5),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('returns null when inside fenced code block', () {
      const text = '```\n#code\n```';
      const value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 9), // inside #code
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('returns null when tag contains whitespace or punctuation after query', () {
      const value = TextEditingValue(
        text: '#work done',
        selection: TextSelection.collapsed(offset: 10),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('P3-3 returns null inside an in-progress ATX heading marker (##S)', () {
      const value = TextEditingValue(
        text: '##S',
        selection: TextSelection.collapsed(offset: 3),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('P3-3 returns null for a deeper in-progress heading marker (###Head)', () {
      const value = TextEditingValue(
        text: '###Head',
        selection: TextSelection.collapsed(offset: 7),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('P3-3 still detects a genuine single-hash tag at line start (#flutter)', () {
      const value = TextEditingValue(
        text: '#flutter',
        selection: TextSelection.collapsed(offset: 8),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.query, 'flutter');
    });

    test('P3-3 still detects a tag when hashes are mid-line, not a heading', () {
      const value = TextEditingValue(
        text: 'see ##S',
        selection: TextSelection.collapsed(offset: 7),
      );
      final trigger = TagAutocompleteTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.query, 'S');
    });
  });
}
