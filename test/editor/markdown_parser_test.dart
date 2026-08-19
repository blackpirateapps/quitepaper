import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  final styles = MarkdownStyles.fromColors(AppColors.light);

  group('MarkdownParser - 1:1 Text Invariant', () {
    test('plain text of generated TextSpan exactly matches input Markdown source', () {
      const inputs = [
        '# Heading 1\n## Heading 2\n### Heading 3\n#### H4\n##### H5\n###### H6',
        'This is **bold** text and *italic* and ***both*** and ~~strike~~ and ==highlight==.',
        'Here is `inline code` and a [link](https://example.com) and #tag.',
        '> Blockquote line 1\n> Blockquote line 2',
        '- List item 1\n  - Nested list item 2\n* Star item\n+ Plus item',
        '1. Ordered 1\n2. Ordered 2\n10. Ordered 10',
        '```dart\nvoid main() {\n  print("hello");\n}\n```',
        '---\ntitle: Frontmatter\n---\n\nBody content.',
        r'\*not italic\* and \_not italic\_ and \`not code\`',
        '***\n---\n___\n',
        'Partial **bold [unclosed link `unclosed code',
        '',
      ];

      for (final input in inputs) {
        final span = MarkdownParser.buildTextSpan(
          text: input,
          styles: styles,
        );
        expect(span.toPlainText(), equals(input),
            reason: 'Span text must match input exactly: "$input"');
      }
    });
  });

  group('MarkdownParser - Styling Rules', () {
    test('heading lines apply heading font styles to content and subdued style to hashes', () {
      final span = MarkdownParser.buildTextSpan(
        text: '# Big Title',
        styles: styles,
      );

      final children = span.children!;
      expect(children, isNotEmpty);
      // Hash marker
      final hashSpan = children.first as TextSpan;
      expect(hashSpan.text, equals('#'));
      expect(hashSpan.style?.color, equals(styles.headingMarker.color));

      // Title text
      final textSpan = children.last as TextSpan;
      expect(textSpan.text, equals('Big Title'));
      expect(textSpan.style?.fontSize, equals(styles.heading1.fontSize));
      expect(textSpan.style?.fontWeight, equals(styles.heading1.fontWeight));
    });

    test('nested bold inside heading preserves heading font size with bold weight', () {
      final span = MarkdownParser.buildTextSpan(
        text: '## Heading with **bold** word',
        styles: styles,
      );

      final text = span.toPlainText();
      expect(text, equals('## Heading with **bold** word'));

      final boldSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'bold',
      ) as TextSpan;

      expect(boldSpan.style?.fontWeight, equals(FontWeight.w700));
      expect(boldSpan.style?.fontSize, equals(styles.heading2.fontSize));
    });

    test('inline code applies monospace font family', () {
      final span = MarkdownParser.buildTextSpan(
        text: 'Use `print("hello")` in Dart',
        styles: styles,
      );

      final codeSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'print("hello")',
      ) as TextSpan;

      expect(codeSpan.style?.fontFamily, equals('monospace'));
    });

    test('strikethrough applies lineThrough decoration', () {
      final span = MarkdownParser.buildTextSpan(
        text: 'This is ~~old text~~ to remove',
        styles: styles,
      );

      final strikeSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'old text',
      ) as TextSpan;

      expect(strikeSpan.style?.decoration, equals(TextDecoration.lineThrough));
    });

    test('highlight applies background color', () {
      final span = MarkdownParser.buildTextSpan(
        text: 'This is ==important== text',
        styles: styles,
      );

      final hlSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'important',
      ) as TextSpan;

      expect(hlSpan.style?.backgroundColor, equals(styles.highlight.backgroundColor));
    });

    test('link title applies link styling and url receives subdued styling', () {
      final span = MarkdownParser.buildTextSpan(
        text: 'Visit [Google](https://google.com)',
        styles: styles,
      );

      final titleSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'Google',
      ) as TextSpan;

      expect(titleSpan.style?.color, equals(styles.link.color));

      final urlSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'https://google.com',
      ) as TextSpan;

      expect(urlSpan.style?.color, equals(styles.linkUrl.color));
    });

    test('checklists render with checklist marker and completed task styling', () {
      const text = '- [ ] Todo item\n- [x] Done item';
      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);

      expect(span.toPlainText(), equals(text));

      final todoMarkerSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == '- [ ]',
      ) as TextSpan;
      expect(todoMarkerSpan.style?.color, equals(styles.checklistMarker.color));

      final doneMarkerSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == '- [x]',
      ) as TextSpan;
      expect(doneMarkerSpan.style?.color, equals(styles.checklistMarkerChecked.color));
    });

    test('composing range applies underline decoration to active IME composing characters', () {
      const text = 'Writing a note with composing text';
      // Composing range covering "composing" (index 20 to 29)
      final span = MarkdownParser.buildTextSpan(
        text: text,
        styles: styles,
        composingRange: const TextRange(start: 20, end: 29),
      );

      expect(span.toPlainText(), equals(text));

      final composingSpan = span.children!.firstWhere(
        (s) => (s as TextSpan).text == 'composing',
      ) as TextSpan;

      expect(composingSpan.style?.decoration, equals(TextDecoration.underline));
    });
  });

  group('MarkdownParser - Performance Tests', () {
    test('parses 1 KB note in under 10ms', () {
      final text = List.generate(10, (i) => '## Section $i\nThis is a **bold** paragraph with *italic* text and a [link $i](https://example.com).\n- Bullet item $i\n').join('\n');
      expect(text.length, greaterThanOrEqualTo(1000));

      final stopwatch = Stopwatch()..start();
      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);
      stopwatch.stop();

      expect(span.toPlainText(), equals(text));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('parses 10 KB note with high responsiveness', () {
      final text = List.generate(120, (i) => '### Note $i\nLine with `code $i` and ==highlight== and #tag$i.\n> Quote $i\n1. Step A\n2. Step B\n').join('\n');
      expect(text.length, greaterThanOrEqualTo(10000));

      final stopwatch = Stopwatch()..start();
      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);
      stopwatch.stop();

      expect(span.toPlainText(), equals(text));
      expect(stopwatch.elapsedMilliseconds, lessThan(250));
    });

    test('parses 50 KB note safely without crash', () {
      final text = List.generate(500, (i) => '# Title $i\nParagraph with **bold** and *italic* and ~~strike~~ and [link](https://foo.bar).\n```dart\nint x = $i;\n```\n').join('\n');
      expect(text.length, greaterThanOrEqualTo(50000));

      final stopwatch = Stopwatch()..start();
      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);
      stopwatch.stop();

      expect(span.toPlainText(), equals(text));
    });

    test('parses 100 KB note safely', () {
      final text = List.generate(1500, (i) => '## Line $i: Sample content with **formatting** and *italic* and `code`\n').join();
      expect(text.length, greaterThanOrEqualTo(100000));

      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);
      expect(span.toPlainText(), equals(text));
    });
  });
}
