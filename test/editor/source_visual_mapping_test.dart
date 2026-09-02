import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/wysiwyg_projection_builder.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  group('WysiwygProjectionBuilder & SourceVisualMapping Tests', () {
    final styles = MarkdownStyles.fromColors(AppColors.light);

    test('hides heading markers and maps coordinates correctly', () {
      const source = '# Heading One\n## Heading Two\nNormal paragraph.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('Heading One\nHeading Two\nNormal paragraph.'));

      // Check coordinate mapping
      // Visual offset 0 -> Source offset 2 (after "# ")
      expect(mapping.visualToSource(0), equals(2));
      // Visual offset 11 ("Heading One" end) -> Source offset 13
      expect(mapping.visualToSource(11), equals(13));

      // Source offset 0 (start of "# ") -> Visual offset 0
      expect(mapping.sourceToVisual(0), equals(0));
      expect(mapping.sourceToVisual(2), equals(0));
      expect(mapping.sourceToVisual(5), equals(3));
    });

    test('hides inline bold, italic, strikethrough, highlight, and code delimiters', () {
      const source = 'This is **bold**, *italic*, ~~strike~~, ==highlight==, and `code`.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(
        mapping.visualText,
        equals('This is bold, italic, strike, highlight, and code.'),
      );

      // Verify delimiter runs are marked as hidden
      final hiddenRuns = mapping.runs.where((r) => r.isHiddenSyntax).toList();
      expect(hiddenRuns, isNotEmpty);
    });

    test('replaces unordered list marker "- " with bullet "• "', () {
      const source = '- Item 1\n- Item 2\n- Item 3';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('• Item 1\n• Item 2\n• Item 3'));
    });

    test('formats checklist markers as visual checkbox symbols', () {
      const source = '- [ ] Task pending\n- [x] Task done';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('☐ Task pending\n☑ Task done'));
    });

    test('hides link url part in WYSIWYG projection', () {
      const source = 'Check [Quiet Paper](https://quitepaper.app) for details.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('Check Quiet Paper for details.'));
    });

    test('hides note link brackets [[...]] in projection', () {
      const source = 'See [[Architecture Roadmap]] for info.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('See Architecture Roadmap for info.'));
    });

    test('hides blockquote marker "> "', () {
      const source = '> A quiet quote.\nNormal text.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      expect(mapping.visualText, equals('A quiet quote.\nNormal text.'));
    });

    test('stripFrontmatter excludes YAML frontmatter block from visual text', () {
      const source = '---\ntitle: Doc\nauthor: John\n---\n# Body Title\nBody text.';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
        stripFrontmatter: true,
      );

      expect(mapping.visualText, equals('Body Title\nBody text.'));
    });

    test('mapVisualSelectionToSource translates selection ranges accurately', () {
      const source = 'Hello **world** test';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      // visualText: "Hello world test"
      // "world" in visual text is at [6, 11]
      final visualSel = const TextSelection(baseOffset: 6, extentOffset: 11);
      final sourceSel = mapping.mapVisualSelectionToSource(visualSel);

      // "world" in source is inside "**world**" at [6, 15]
      expect(sourceSel.baseOffset, equals(6));
      expect(sourceSel.extentOffset, equals(15));
      expect(source.substring(sourceSel.start, sourceSel.end), equals('**world**'));
    });

    test('mapVisualEditToSource translates typing inside formatted text to canonical source', () {
      const source = 'Hello **world** test';
      final mapping = WysiwygProjectionBuilder.build(
        sourceText: source,
        styles: styles,
      );

      // Old visual: "Hello world test" (cursor at index 9: "Hello wor|ld test")
      final oldVal = const TextEditingValue(
        text: 'Hello world test',
        selection: TextSelection.collapsed(offset: 9),
      );

      // New visual: user types "x" -> "Hello worxld test"
      final newVal = const TextEditingValue(
        text: 'Hello worxld test',
        selection: TextSelection.collapsed(offset: 10),
      );

      final newSourceVal = mapping.mapVisualEditToSource(
        oldVisualValue: oldVal,
        newVisualValue: newVal,
      );

      expect(newSourceVal.text, equals('Hello **worxld** test'));
    });
  });
}
