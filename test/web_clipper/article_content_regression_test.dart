import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/web_clipper/article_extractor.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';

void main() {
  final fixture = File(
    'test/fixtures/web_clipper/hindu_article.html',
  ).readAsStringSync();
  const url =
      'https://www.thehindu.com/news/cities/Delhi/article71735766.ece'
      '?cx_testId=15&cx_artPos=6#cxrecs_s';

  void expectArticleOnly(String content) {
    expect(content, contains('Police suspended a constable'));
    expect(content, contains('Constable denies the allegation'));
    expect(content, contains('Most Popular is also a phrase'));
    expect(content, contains('FINAL_ARTICLE_PARAGRAPH'));
    expect(content, isNot(contains('_NOISE')));
    expect(content, isNot(contains('HIDDEN_DUPLICATE_ARTICLE')));
    expect(content, isNot(contains('SIDEBAR_FAKE_ARTICLE')));
  }

  test('The Hindu prose wins over main and related article containers', () {
    final result = const ArticleExtractor().extractFromHtml(fixture, url);
    expect(result.isArticleRootFound, isTrue);
    expect(result.cleanedElement.id, 'schemaDiv');
    expectArticleOnly(result.cleanedElement.text);
    expect(
      result.images.single.resolvedUrl,
      'https://www.thehindu.com/article-photo.jpg',
    );
    expect(result.images.single.caption, 'Article photograph caption.');
  });

  test(
    'Android WebView and shared URL scans produce clean matching Markdown',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: {'content-length': '1000'});
        }
        return http.Response(
          fixture,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final scanner = WebClipperScanner(httpClient: client);
      final direct = await scanner.scanUrl(url);
      final browser = await scanner.scanPayload(
        WebCapturePayload(
          requestedUrl: url,
          finalUrl: url,
          html: fixture,
          acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
        ),
      );

      expectArticleOnly(direct.markdownBody);
      expectArticleOnly(browser.markdownBody);
      expect(browser.markdownBody, direct.markdownBody);
      expect(browser.isPageContentFallback, isFalse);
      expect(browser.metadata.author, 'Test Reporter');
      expect(browser.metadata.sourceUrl, url);
      expect(
        browser.images.single.resolvedUrl,
        direct.images.single.resolvedUrl,
      );
      expect(
        browser.markdownBody,
        contains(
          '[background report](https://www.thehindu.com/news/background)',
        ),
      );
    },
  );

  for (final attribute in [
    'itemprop="articleBody"',
    'class="article-body"',
    'class="entry-content"',
  ]) {
    test('prefers $attribute over a larger semantic wrapper', () {
      final html =
          '''
        <main><article><h1>Article title</h1><div $attribute>
          <p>A short but complete article body.</p>
        </div><div class="recommendations article-content">
          <p>${'Unrelated recommendation. ' * 30}</p>
        </div></article><p>Outside main content.</p></main>
      ''';
      final result = const ArticleExtractor().extractFromHtml(html, url);
      expect(
        result.cleanedElement.text.trim(),
        'A short but complete article body.',
      );
    });
  }

  test('cleans embedded modules when the only root is a semantic article', () {
    final html =
        '''
      <article><p>${'Article prose. ' * 30}</p>
        <div class="most-popular article-content"><p>POPULAR_NOISE</p></div>
        <div class="article-ad"><p>AD_NOISE</p></div>
        <p>FINAL_ARTICLE_PARAGRAPH</p>
      </article>
    ''';
    final result = const ArticleExtractor().extractFromHtml(html, url);
    expect(result.cleanedElement.text, contains('FINAL_ARTICLE_PARAGRAPH'));
    expect(result.cleanedElement.text, isNot(contains('_NOISE')));
  });

  test('a short semantic article wins over a much larger main wrapper', () {
    final html = '''
      <main><article><p>Short complete article.</p></article>
        <div><p>${'Outside content. ' * 100}</p></div>
      </main>
    ''';
    final result = const ArticleExtractor().extractFromHtml(html, url);
    expect(result.cleanedElement.text.trim(), 'Short complete article.');
  });
}
