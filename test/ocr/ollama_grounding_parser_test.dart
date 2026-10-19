import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/ocr/ollama_grounding_parser.dart';

void main() {
  group('OllamaGroundingParser Tests', () {
    const userPromptOutput = '''
image[[22, 127, 452, 646]]
 

text[[4, 641, 450, 789]]
In cyclic quadrilateral (चक्रीय चतुर्भुज)
\\(a + c = b + d = 180^\\circ\\)
\\(a = c\\) 

image[[542, 125, 992, 646]]
 

text[[538, 640, 998, 835]]
In a tangential quadrilateral
(स्पर्शीय चतुर्भुज) the sums of opposite
sides are equal.
\\(a + c = b + d\\)
''';

    test('parses grounded response, strips coordinate tags, and extracts clean markdown', () {
      final result = OllamaGroundingParser.parse(userPromptOutput);

      // 1. Verify clean text has zero grounding coordinate tags
      expect(result.cleanPlainText, isNot(contains('image[[')));
      expect(result.cleanPlainText, isNot(contains('text[[')));
      expect(result.cleanPlainText, isNot(contains('[[')));
      expect(result.cleanPlainText, isNot(contains(']]')));

      // 2. Verify Hindi and LaTeX formulas are preserved intact
      expect(result.cleanPlainText, contains('In cyclic quadrilateral (चक्रीय चतुर्भुज)'));
      expect(result.cleanPlainText, contains(r'\(a + c = b + d = 180^\circ\)'));
      expect(result.cleanPlainText, contains(r'\(a = c\)'));
      expect(result.cleanPlainText, contains('In a tangential quadrilateral'));
      expect(result.cleanPlainText, contains('(स्पर्शीय चतुर्भुज)'));
      expect(result.cleanPlainText, contains(r'\(a + c = b + d\)'));

      // 3. Verify detected images (2 geometry diagrams)
      expect(result.detectedImages.length, 2);

      // First diagram: [22, 127, 452, 646]
      final img1 = result.detectedImages[0];
      expect(img1.x, closeTo(0.127, 0.001));
      expect(img1.y, closeTo(0.022, 0.001));
      expect(img1.width, closeTo(0.519, 0.001));
      expect(img1.height, closeTo(0.430, 0.001));

      // Second diagram: [542, 125, 992, 646]
      final img2 = result.detectedImages[1];
      expect(img2.x, closeTo(0.125, 0.001));
      expect(img2.y, closeTo(0.542, 0.001));
      expect(img2.width, closeTo(0.521, 0.001));
      expect(img2.height, closeTo(0.450, 0.001));

      // 4. Verify text blocks
      expect(result.blocks.length, 2);

      // First text block: [4, 641, 450, 789]
      final block1 = result.blocks[0];
      expect(block1.bounds.x, closeTo(0.641, 0.001));
      expect(block1.bounds.y, closeTo(0.004, 0.001));
      expect(block1.bounds.width, closeTo(0.148, 0.001));
      expect(block1.bounds.height, closeTo(0.446, 0.001));
      expect(block1.lines.length, 3);

      // Verify line bounds & words in block 1
      for (final line in block1.lines) {
        expect(line.bounds.x, closeTo(block1.bounds.x, 0.001));
        expect(line.bounds.width, closeTo(block1.bounds.width, 0.001));
        expect(line.words, isNotEmpty);
        for (final word in line.words) {
          expect(word.bounds.x, greaterThanOrEqualTo(0.0));
          expect(word.bounds.right, lessThanOrEqualTo(1.0));
          expect(word.bounds.width, greaterThan(0.0));
        }
      }

      // Second text block: [538, 640, 998, 835]
      final block2 = result.blocks[1];
      expect(block2.bounds.x, closeTo(0.640, 0.001));
      expect(block2.bounds.y, closeTo(0.538, 0.001));
      expect(block2.bounds.width, closeTo(0.195, 0.001));
      expect(block2.bounds.height, closeTo(0.460, 0.001));
      expect(block2.lines.length, 4);
    });

    test('handles prefix text before the first grounding tag', () {
      const input = '''
Document Header Title
image[[100, 100, 300, 300]]
text[[350, 100, 500, 500]]
Body paragraph under diagram.
''';
      final result = OllamaGroundingParser.parse(input);

      expect(result.cleanPlainText, contains('Document Header Title'));
      expect(result.cleanPlainText, contains('Body paragraph under diagram.'));
      expect(result.blocks.length, 2);
      expect(result.blocks.first.text, 'Document Header Title');
      expect(result.detectedImages.length, 1);
    });

    test('handles non-grounded standard Markdown gracefully with generated lines & words', () {
      const standardMarkdown = '''
# Physics Notes

- Gravity: 9.8 m/s^2
- Speed of Light: 3e8 m/s

| Variable | Value |
|---|---|
| c | 299792458 |
''';

      final result = OllamaGroundingParser.parse(standardMarkdown);

      expect(result.cleanPlainText, standardMarkdown.trim());
      expect(result.detectedImages, isEmpty);
      expect(result.blocks, isNotEmpty);

      // Verify that lines and words are generated for Live Text selection
      for (final block in result.blocks) {
        expect(block.lines, isNotEmpty);
        for (final line in block.lines) {
          expect(line.words, isNotEmpty);
        }
      }
    });

    test('handles empty or whitespace responses', () {
      final empty = OllamaGroundingParser.parse('');
      expect(empty.cleanPlainText, '');
      expect(empty.blocks, isEmpty);
      expect(empty.detectedImages, isEmpty);

      final whitespace = OllamaGroundingParser.parse('   \n\n  \t  ');
      expect(whitespace.cleanPlainText, '');
      expect(whitespace.blocks, isEmpty);
      expect(whitespace.detectedImages, isEmpty);
    });
  });
}
