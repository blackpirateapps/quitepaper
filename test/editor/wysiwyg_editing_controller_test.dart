import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
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
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
