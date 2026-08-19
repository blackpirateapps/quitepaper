import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_tokenizer.dart';
import 'package:quitepaper/features/editor/domain/markdown_token.dart';

void main() {
  const tokenizer = MarkdownTokenizer();

  group('MarkdownTokenizer - Headings', () {
    test('tokenizes H1 to H6 headings with markers and content', () {
      final text = '# Heading 1\n## Heading 2\n### Heading 3\n#### Heading 4\n##### Heading 5\n###### Heading 6';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '#'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1 && t.text == 'Heading 1'), isTrue);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '##'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading2 && t.text == 'Heading 2'), isTrue);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '###'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading3 && t.text == 'Heading 3'), isTrue);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '######'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading6 && t.text == 'Heading 6'), isTrue);
    });

    test('handles heading with inline bold', () {
      final text = '# Title with **bold text**';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.bold && t.text == 'bold text'), isTrue);
    });

    test('tokenizes heading with multiple spaces and trailing spaces', () {
      final text = '#   Heading with   spaces   ';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '#'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1 && t.text == '  Heading with   spaces   '), isTrue);
    });

    test('tokenizes hash followed only by spaces without dropping spaces', () {
      final text = '#   ';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.headingMarker && t.text == '#'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1 && t.text == '  '), isTrue);
    });
  });

  group('MarkdownTokenizer - Inline Formatting', () {
    test('tokenizes bold with asterisks and underscores', () {
      final text = 'This is **bold** and __also bold__';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.bold && t.text == 'bold'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.bold && t.text == 'also bold'), isTrue);
    });

    test('tokenizes italic with asterisks and underscores', () {
      final text = 'This is *italic* and _also italic_';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.italic && t.text == 'italic'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.italic && t.text == 'also italic'), isTrue);
    });

    test('tokenizes bold + italic', () {
      final text = 'This is ***bold italic*** and ___also bold italic___';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.boldItalic && t.text == 'bold italic'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.boldItalic && t.text == 'also bold italic'), isTrue);
    });

    test('tokenizes strikethrough', () {
      final text = 'This is ~~deleted text~~';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.strikethrough && t.text == 'deleted text'), isTrue);
    });

    test('tokenizes highlight', () {
      final text = 'This is ==highlighted text==';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.highlight && t.text == 'highlighted text'), isTrue);
    });

    test('tokenizes inline code', () {
      final text = 'Use `const x = 1;` here';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.inlineCode && t.text == 'const x = 1;'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.inlineCodeMarker && t.text == '`'), isTrue);
    });
  });

  group('MarkdownTokenizer - Links and Tags', () {
    test('tokenizes markdown links', () {
      final text = 'Visit [Google](https://google.com) today';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.linkText && t.text == 'Google'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.linkUrl && t.text == 'https://google.com'), isTrue);
    });

    test('tokenizes bare URLs', () {
      final text = 'Check out https://github.com/blackpirateapps for updates';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.link && (t.text?.startsWith('https://') ?? false)), isTrue);
    });

    test('tokenizes tags', () {
      final text = 'Organize notes with #ideas and #project/v1';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.tag && t.text == '#ideas'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.tag && t.text == '#project/v1'), isTrue);
    });
  });

  group('MarkdownTokenizer - Block Elements', () {
    test('tokenizes blockquotes', () {
      final text = '> This is a quote\n> Second line';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.blockquoteMarker && t.text == '>'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.blockquote && t.text == 'This is a quote'), isTrue);
    });

    test('tokenizes unordered lists with -, *, +', () {
      final text = '- Item 1\n* Item 2\n+ Item 3';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.unorderedListMarker && t.text == '-'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.unorderedList && t.text == 'Item 1'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.unorderedListMarker && t.text == '*'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.unorderedListMarker && t.text == '+'), isTrue);
    });

    test('tokenizes checklists', () {
      final text = '- [ ] Task unchecked\n- [x] Task checked\n  - [X] Nested done';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.checklistMarkerUnchecked && t.text == '- [ ]'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.taskText && t.text == 'Task unchecked'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.checklistMarkerChecked && t.text == '- [x]'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.taskTextCompleted && t.text == 'Task checked'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.checklistMarkerChecked && t.text == '- [X]'), isTrue);
    });

    test('tokenizes ordered lists', () {
      final text = '1. First\n2. Second\n10. Tenth';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.orderedListMarker && t.text == '1.'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.orderedList && t.text == 'First'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.orderedListMarker && t.text == '10.'), isTrue);
    });

    test('tokenizes fenced code blocks', () {
      final text = '```dart\nvoid main() {\n  print("hello");\n}\n```';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.codeBlockFence && (t.text?.contains('```dart') ?? false)), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.codeBlock && (t.text?.contains('void main()') ?? false)), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.codeBlockFence && t.text == '```'), isTrue);
    });

    test('tokenizes horizontal rules', () {
      final text = 'Paragraph\n---\nAnother paragraph\n***\nFinal';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.horizontalRule && t.text == '---'), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.horizontalRule && t.text == '***'), isTrue);
    });

    test('tokenizes frontmatter at document start', () {
      final text = '---\ntitle: Sample Note\ntags: [test]\n---\n\n# Heading';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.frontmatterDelimiter), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.frontmatter && (t.text?.contains('title: Sample Note') ?? false)), isTrue);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1), isTrue);
    });
  });

  group('MarkdownTokenizer - Escaping and Malformed Input', () {
    test('escaped markdown characters are not tokenized as formatting', () {
      final text = r'\*not italic\* and \_not italic\_ and \`not code\`';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.italic), isFalse);
      expect(tokens.any((t) => t.type == MarkdownTokenType.inlineCode), isFalse);
    });

    test('tolerates incomplete and malformed markdown without throwing', () {
      const inputs = [
        '**',
        '*',
        '_',
        '__',
        '[foo',
        '[foo](',
        '`',
        '```',
        '> ',
        '# ',
        '######',
        '- ',
        '1. ',
        '**foo *bar**',
        '~~foo **bar~~',
      ];

      for (final input in inputs) {
        expect(() => tokenizer.tokenize(input), returnsNormally);
      }
    });

    test('plain text does not receive accidental formatting', () {
      final text = 'Just an ordinary sentence without any markdown syntax.';
      final tokens = tokenizer.tokenize(text);

      expect(tokens.any((t) => t.type == MarkdownTokenType.bold), isFalse);
      expect(tokens.any((t) => t.type == MarkdownTokenType.italic), isFalse);
      expect(tokens.any((t) => t.type == MarkdownTokenType.heading1), isFalse);
    });
  });
}
