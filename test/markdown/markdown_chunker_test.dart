import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/markdown/markdown_chunker.dart';

void main() {
  group('MarkdownChunker', () {
    test('returns empty list for empty or whitespace string', () {
      expect(MarkdownChunker.split(''), isEmpty);
      expect(MarkdownChunker.split('   \n\n  \t '), isEmpty);
    });

    test('returns single chunk for short markdown text', () {
      const input = '# Heading\nThis is a short note.';
      final chunks = MarkdownChunker.split(input);
      expect(chunks.length, 1);
      expect(chunks.first, input);
    });

    test('splits multiple paragraphs when exceeding target chunk size', () {
      final paragraph = 'A' * 700;
      final input = '$paragraph\n\n$paragraph\n\n$paragraph';
      final chunks = MarkdownChunker.split(input, targetChunkChars: 800);
      expect(chunks.length, greaterThanOrEqualTo(2));
      for (final chunk in chunks) {
        expect(chunk.trim().isNotEmpty, isTrue);
      }
    });

    test('preserves code block with blank lines inside intact', () {
      final codeBlock = '''
```dart
void main() {
  print("first");

  print("second");

  print("third");
}
```''';
      final input = 'Intro text\n\n$codeBlock\n\nOutro text';
      final chunks = MarkdownChunker.split(input, targetChunkChars: 50);
      // Verify code block is not torn in half
      final hasCompleteCodeBlock = chunks.any((c) =>
          c.contains('```dart') &&
          c.contains('print("first");') &&
          c.contains('print("second");') &&
          c.contains('```'));
      expect(hasCompleteCodeBlock, isTrue);
    });

    test('preserves tables intact without breaking rows across chunks', () {
      const table = '''
| Header 1 | Header 2 |
| :--- | :--- |
| Row 1 Col 1 | Row 1 Col 2 |
| Row 2 Col 1 | Row 2 Col 2 |
| Row 3 Col 1 | Row 3 Col 2 |
''';
      final input = '# Note Title\n\n$table\n\nConclusion text';
      final chunks = MarkdownChunker.split(input, targetChunkChars: 50);
      final hasCompleteTable = chunks.any((c) =>
          c.contains('| Header 1 |') &&
          c.contains('| Row 3 Col 1 |'));
      expect(hasCompleteTable, isTrue);
    });

    test('preserves blockquotes intact', () {
      const quote = '''
> This is a quote.
> It continues on line 2.
> It continues on line 3.
''';
      final input = '$quote\n\nParagraph text after quote.';
      final chunks = MarkdownChunker.split(input, targetChunkChars: 50);
      final hasQuote = chunks.any((c) => c.contains('> This is a quote.'));
      expect(hasQuote, isTrue);
    });

    test('preserves lists and sublists intact', () {
      const list = '''
- Item 1
  - Subitem 1.1
- Item 2
- Item 3
''';
      final input = '$list\n\nFollowing paragraph.';
      final chunks = MarkdownChunker.split(input, targetChunkChars: 50);
      final hasList = chunks.any((c) => c.contains('- Item 1') && c.contains('- Item 3'));
      expect(hasList, isTrue);
    });

    test('splits massive continuous line into manageable pieces', () {
      final massiveLine = List.generate(500, (i) => 'Word$i sentence text.').join(' ');
      expect(massiveLine.length, greaterThan(5000));

      final chunks = MarkdownChunker.split(massiveLine, targetChunkChars: 1000);
      expect(chunks.length, greaterThan(3));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(2500));
      }
    });

    test('high performance on huge 10,000-line document', () {
      final stopwatch = Stopwatch()..start();
      final largeDoc = List.generate(
        10000,
        (i) => i % 10 == 0
            ? '## Section $i\n\n'
            : 'Paragraph line $i with some editorial text and words to fill space.',
      ).join('\n');

      final chunks = MarkdownChunker.split(largeDoc, targetChunkChars: 1200);
      stopwatch.stop();

      expect(chunks.length, greaterThan(10));
      // Splitting a 10,000 line document should be very fast (<50ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
