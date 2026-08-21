import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:quitepaper/core/web_clipper/html_to_markdown_converter.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';

void main() {
  group('HtmlToMarkdownConverter', () {
    const converter = HtmlToMarkdownConverter();

    test('converts headings, formatting, lists, blockquotes, and tables', () {
      const htmlFragment = '''
<div>
  <h2>Introduction</h2>
  <p>This is <strong>bold</strong>, <em>italic</em>, <mark>highlighted</mark>, and <code>inline code</code>.</p>
  <blockquote>
    <p>A quote from a book.</p>
  </blockquote>
  <ul>
    <li>Item 1</li>
    <li>Item 2</li>
  </ul>
  <ol>
    <li>First</li>
    <li>Second</li>
  </ol>
  <table>
    <thead>
      <tr><th>Header 1</th><th>Header 2</th></tr>
    </thead>
    <tbody>
      <tr><td>Cell A</td><td>Cell B</td></tr>
    </tbody>
  </table>
  <pre><code class="language-dart">void main() { print("hello"); }</code></pre>
</div>
''';

      final element = html_parser.parseFragment(htmlFragment).children.first;
      final metadata = ExtractedArticleMetadata(
        sourceUrl: 'https://example.com/essay',
        title: 'Essay on Coding',
        author: 'Jane Doe',
        publishedDate: DateTime(2026, 8, 22),
        description: 'An inspiring essay.',
        domain: 'example.com',
      );

      final markdown = converter.convert(
        cleanedElement: element,
        metadata: metadata,
        tags: ['technology'],
        snapshotDocumentId: 'snap-123',
        snapshotSizeBytes: 120 * 1024,
      );

      expect(markdown, contains('title: "Essay on Coding"'));
      expect(markdown, contains('source: "https://example.com/essay"'));
      expect(markdown, contains('author: "Jane Doe"'));
      expect(markdown, contains('- clipped'));
      expect(markdown, contains('- example.com'));
      expect(markdown, contains('- technology'));
      expect(markdown, contains('> 🌐 **Original Web Snapshot Attached** • 120.0 KB — [View Web Snapshot →](qp://document/snap-123)'));
      expect(markdown, contains('## Introduction'));
      expect(markdown, contains('**bold**'));
      expect(markdown, contains('*italic*'));
      expect(markdown, contains('==highlighted=='));
      expect(markdown, contains('`inline code`'));
      expect(markdown, contains('> A quote from a book.'));
      expect(markdown, contains('- Item 1'));
      expect(markdown, contains('1. First'));
      expect(markdown, contains('| Header 1 | Header 2 |'));
      expect(markdown, contains('```dart'));
    });
  });
}
