import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_formatter.dart';
import 'package:quitepaper/features/editor/application/wysiwyg_editing_controller.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  group('WysiwygEditingController Unit Tests', () {
    final styles = MarkdownStyles.fromColors(AppColors.light);

    test('initializes with projected visual text and mapped selection', () {
      final controller = WysiwygEditingController(
        sourceText: '# Hello **world**',
        styles: styles,
      );

      expect(controller.text, equals('Hello world'));
      expect(controller.sourceText, equals('# Hello **world**'));
    });

    test('updates sourceText when setting new value', () {
      final controller = WysiwygEditingController(
        sourceText: 'Initial text',
        styles: styles,
      );

      controller.sourceText = '## New Heading';
      expect(controller.text, equals('New Heading'));
      expect(controller.sourceText, equals('## New Heading'));
    });

    test('translates visual typing into sourceText and notifies callback', () {
      String? changedSource;
      final controller = WysiwygEditingController(
        sourceText: 'Hello **world**',
        styles: styles,
        onSourceChanged: (src) => changedSource = src,
      );

      expect(controller.text, equals('Hello world'));

      // Simulate typing '!' at end of visual text
      controller.value = const TextEditingValue(
        text: 'Hello world!',
        selection: TextSelection.collapsed(offset: 12),
      );

      expect(controller.sourceText, equals('Hello **world**!'));
      expect(changedSource, equals('Hello **world**!'));
    });

    test('setSourceValue updates canonical source and rebuilds visual projection with correct selection', () {
      final controller = WysiwygEditingController(
        sourceText: 'Hello world',
        styles: styles,
      );

      // Programmatically format "world" as bold in source
      controller.setSourceValue(const TextEditingValue(
        text: 'Hello **world**',
        selection: TextSelection(baseOffset: 8, extentOffset: 13),
      ));

      expect(controller.sourceText, equals('Hello **world**'));
      expect(controller.text, equals('Hello world'));
      expect(controller.selection.baseOffset, equals(6));
      expect(controller.selection.extentOffset, equals(11));
    });

    test('buildTextSpan styles runs with correct typography', () {
      final controller = WysiwygEditingController(
        sourceText: '# Title\nThis is **bold** text.',
        styles: styles,
      );

      final BuildContext context = _MockBuildContext();
      final span = controller.buildTextSpan(context: context, withComposing: false);

      expect(span.children, isNotEmpty);
    });

    test('continuous typing inside bold and toggling bold off', () {
      final controller = WysiwygEditingController(
        sourceText: '',
        styles: styles,
      );

      // 1. User taps bold
      controller.applyFormat(MarkdownFormatter.toggleBold);
      expect(controller.sourceText, equals('****'));
      expect(controller.text, equals(''));
      expect(controller.isBoldActive, isTrue);

      // 2. User types 'H'
      controller.value = const TextEditingValue(
        text: 'H',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(controller.sourceText, equals('**H**'));
      expect(controller.text, equals('H'));
      expect(controller.isBoldActive, isTrue);

      // 3. User types 'e'
      controller.value = const TextEditingValue(
        text: 'He',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(controller.sourceText, equals('**He**'));
      expect(controller.text, equals('He'));
      expect(controller.isBoldActive, isTrue);

      // 4. User types 'llo'
      controller.value = const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      expect(controller.sourceText, equals('**Hello**'));
      expect(controller.text, equals('Hello'));
      expect(controller.isBoldActive, isTrue);

      // 5. User taps bold again to turn it off
      controller.applyFormat(MarkdownFormatter.toggleBold);
      expect(controller.sourceText, equals('**Hello**'));
      expect(controller.isBoldActive, isFalse);

      // 6. User types ' world'
      controller.value = const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 11),
      );
      expect(controller.sourceText, equals('**Hello** world'));
      expect(controller.text, equals('Hello world'));
      expect(controller.isBoldActive, isFalse);
    });

    test('continuous typing inside italic and strikethrough', () {
      final controller = WysiwygEditingController(
        sourceText: '',
        styles: styles,
      );

      // Italic
      controller.applyFormat(MarkdownFormatter.toggleItalic);
      expect(controller.sourceText, equals('**'));
      expect(controller.isItalicActive, isTrue);

      controller.value = const TextEditingValue(
        text: 'I',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(controller.sourceText, equals('*I*'));

      controller.value = const TextEditingValue(
        text: 'Italic',
        selection: TextSelection.collapsed(offset: 6),
      );
      expect(controller.sourceText, equals('*Italic*'));

      // Toggle italic off
      controller.applyFormat(MarkdownFormatter.toggleItalic);
      expect(controller.isItalicActive, isFalse);

      // Type space after italic
      controller.value = const TextEditingValue(
        text: 'Italic ',
        selection: TextSelection.collapsed(offset: 7),
      );
      expect(controller.sourceText, equals('*Italic* '));

      // Strikethrough
      controller.applyFormat(MarkdownFormatter.toggleStrikethrough);
      expect(controller.isStrikethroughActive, isTrue);

      controller.value = const TextEditingValue(
        text: 'Italic Strike',
        selection: TextSelection.collapsed(offset: 13),
      );
      expect(controller.sourceText, equals('*Italic* ~~Strike~~'));
    });
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
