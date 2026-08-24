import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/markdown_offset_mapper.dart';
import 'package:quitepaper/core/search/search_models.dart';

void main() {
  group('MarkdownOffsetMapper', () {
    test('Normalizes bold, italic, code, and strikethrough syntax', () {
      const source = 'This is **bold** and *italic* with `code` and ~~strike~~ text.';
      final result = MarkdownOffsetMapper.normalize(source);

      expect(result.normalizedText, 'This is bold and italic with code and strike text.');

      // Verify that 'bold' in normalized text maps back to 'bold' inside '**bold**' in source
      final normBoldStart = result.normalizedText.indexOf('bold');
      final sourceBoldStart = result.normalizedToSourceMap[normBoldStart];
      expect(source.substring(sourceBoldStart, sourceBoldStart + 4), 'bold');
      expect(sourceBoldStart, 10); // '**bold**' starts at 8, 'bold' starts at 10
    });

    test('Extracts link text and skips link URLs while preserving 1:1 source mapping', () {
      const source = 'Please review [Q3 Financial Report](https://example.com/reports/q3.pdf) today.';
      final result = MarkdownOffsetMapper.normalize(source);

      expect(result.normalizedText, 'Please review Q3 Financial Report today.');

      final normReportStart = result.normalizedText.indexOf('Financial Report');
      final sourceReportStart = result.normalizedToSourceMap[normReportStart];
      expect(source.substring(sourceReportStart, sourceReportStart + 16), 'Financial Report');

      // The word 'today' should correctly map past the entire URL
      final normTodayStart = result.normalizedText.indexOf('today');
      final sourceTodayStart = result.normalizedToSourceMap[normTodayStart];
      expect(source.substring(sourceTodayStart, sourceTodayStart + 5), 'today');
    });

    test('Strips markdown image syntax', () {
      const source = 'See chart below:\n![Quarterly Chart](https://example.com/img.png)\nEnd of doc.';
      final result = MarkdownOffsetMapper.normalize(source);

      expect(result.normalizedText, contains('See chart below:'));
      expect(result.normalizedText, contains('End of doc.'));
      expect(result.normalizedText, isNot(contains('https://example.com/img.png')));
    });

    test('Strips markdown headings, blockquotes, list markers, and checkboxes', () {
      const source = '''
# Main Header
## Sub Header
> A notable quote
- [ ] Task item 1
- [x] Task item 2
* Bullet point
1. Ordered point
''';
      final result = MarkdownOffsetMapper.normalize(source);

      expect(result.normalizedText, contains('Main Header'));
      expect(result.normalizedText, contains('Sub Header'));
      expect(result.normalizedText, contains('A notable quote'));
      expect(result.normalizedText, contains('Task item 1'));
      expect(result.normalizedText, contains('Task item 2'));
      expect(result.normalizedText, contains('Bullet point'));
      expect(result.normalizedText, contains('Ordered point'));
      expect(result.normalizedText, isNot(contains('#')));
      expect(result.normalizedText, isNot(contains('- [ ]')));
    });

    test('Strips YAML frontmatter block', () {
      const source = '''---
title: My Document
tags: [alpha, beta]
---
# Document Content
Here is the actual body text.
''';
      final result = MarkdownOffsetMapper.normalize(source);

      expect(result.normalizedText, isNot(contains('tags: [alpha, beta]')));
      expect(result.normalizedText, contains('Document Content'));
      expect(result.normalizedText, contains('Here is the actual body text.'));
    });

    test('mapToSourceSpan converts normalized spans to exact source spans', () {
      const source = 'Start with **important contract** at the end.';
      final result = MarkdownOffsetMapper.normalize(source);

      // 'important contract' in normalized text
      final normStart = result.normalizedText.indexOf('important contract');
      final normEnd = normStart + 'important contract'.length;
      final normSpan = TokenSpanDto(start: normStart, end: normEnd, isExact: true);

      final sourceSpan = result.mapToSourceSpan(normSpan);
      expect(source.substring(sourceSpan.start, sourceSpan.end), 'important contract');
    });

    test('extractSnippet generates clean context radius with word boundary expansion', () {
      const text = 'Alpha beta gamma delta epsilon zeta eta theta invoice payment details iota kappa lambda mu nu';
      final matchStart = text.indexOf('invoice');
      final spans = [TokenSpanDto(start: matchStart, end: matchStart + 7, isExact: true)];

      final snippetResult = MarkdownOffsetMapper.extractSnippet(
        text: text,
        focusOffset: matchStart,
        focusLength: 7,
        normalizedSpans: spans,
        contextRadius: 20,
      );

      expect(snippetResult.snippet, contains('invoice'));
      expect(snippetResult.highlightSpans.isNotEmpty, true);

      // Verify that highlightSpans point exactly to 'invoice' within snippet string
      final span = snippetResult.highlightSpans.first;
      expect(snippetResult.snippet.substring(span.start, span.end), 'invoice');
    });

    test('Handles extreme, empty, and malformed markdown without crashing', () {
      expect(MarkdownOffsetMapper.normalize('').normalizedText, '');
      expect(MarkdownOffsetMapper.normalize('***').normalizedText, '');
      expect(MarkdownOffsetMapper.normalize('[unclosed link(url').normalizedText, isNotEmpty);
      expect(MarkdownOffsetMapper.normalize('`unclosed code').normalizedText, isNotEmpty);
    });
  });
}
