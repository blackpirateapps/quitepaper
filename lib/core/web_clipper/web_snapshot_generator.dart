import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'web_clipper_models.dart';

/// Generates self-contained, authentic offline HTML/CSS snapshot documents
/// that preserve original webpage styling, layout, typography, and assets.
class WebSnapshotGenerator {
  WebSnapshotGenerator({
    this.httpClient,
  });

  final http.Client? httpClient;

  /// Generates a standalone HTML document string preserving authentic browser styling.
  Future<String> generateHtmlSnapshot({
    required String rawHtml,
    required ExtractedArticleMetadata metadata,
    dom.Element? cleanedElement,
    Map<String, String> localImageSources = const <String, String>{},
  }) async {
    dom.Document document;

    if (rawHtml.trim().isNotEmpty) {
      document = html_parser.parse(rawHtml);
    } else if (cleanedElement != null) {
      document = html_parser.parse(
        '<!DOCTYPE html><html lang="en"><head><title>${_htmlEscape(metadata.title)}</title></head><body></body></html>',
      );
      document.body?.append(cleanedElement.clone(true));
    } else {
      document = html_parser.parse(
        '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>${_htmlEscape(metadata.title)}</title></head><body><h1>${_htmlEscape(metadata.title)}</h1></body></html>',
      );
    }

    // 1. Ensure <head> element exists
    var head = document.head;
    if (head == null) {
      head = dom.Element.tag('head');
      document.documentElement?.nodes.insert(0, head);
    }

    // 2. Ensure <meta charset="utf-8">
    if (head.querySelector('meta[charset]') == null) {
      final charsetMeta = dom.Element.tag('meta')..attributes['charset'] = 'utf-8';
      head.nodes.insert(0, charsetMeta);
    }

    // 3. Ensure responsive viewport meta tag
    if (head.querySelector('meta[name="viewport"]') == null) {
      final viewportMeta = dom.Element.tag('meta')
        ..attributes['name'] = 'viewport'
        ..attributes['content'] = 'width=device-width, initial-scale=1.0';
      head.append(viewportMeta);
    }

    // 4. Ensure <base href="${metadata.sourceUrl}">
    final existingBase = head.querySelector('base');
    if (existingBase != null) {
      final existingHref = existingBase.attributes['href']?.trim();
      if (existingHref == null || existingHref.isEmpty) {
        existingBase.attributes['href'] = metadata.sourceUrl;
      }
    } else {
      final baseElement = dom.Element.tag('base')
        ..attributes['href'] = metadata.sourceUrl;
      head.nodes.insert(0, baseElement);
    }

    // 5. Download and inline external CSS stylesheets
    final linkNodes = document.querySelectorAll(
      'link[rel="stylesheet"], link[rel="Stylesheet"], link[rel="STYLESHEET"]',
    );
    final client = httpClient;

    if (client != null && linkNodes.isNotEmpty) {
      final cssFutures = <Future<void>>[];

      for (final link in linkNodes) {
        final href = link.attributes['href']?.trim();
        if (href == null || href.isEmpty) continue;

        final resolvedCssUrl = _resolveUrl(metadata.sourceUrl, href);

        cssFutures.add(() async {
          try {
            final uri = Uri.tryParse(resolvedCssUrl);
            if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
              final res = await client.get(
                uri,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
                  'Accept': 'text/css,*/*;q=0.1',
                },
              ).timeout(const Duration(seconds: 8));

              if (res.statusCode >= 200 && res.statusCode < 300 && res.body.trim().isNotEmpty) {
                final inlinedCss = _rewriteCssUrls(res.body, resolvedCssUrl);
                final styleElement = dom.Element.tag('style')
                  ..attributes['data-source-href'] = resolvedCssUrl
                  ..text = '\n/* Inlined from $resolvedCssUrl */\n$inlinedCss\n';
                link.replaceWith(styleElement);
                return;
              }
            }
          } catch (_) {
            // Leave link tag pointing to absolute URL on failure
          }
          link.attributes['href'] = resolvedCssUrl;
        }());
      }

      if (cssFutures.isNotEmpty) {
        await Future.wait(cssFutures);
      }
    } else {
      // Resolve relative stylesheet URLs to absolute URLs
      for (final link in linkNodes) {
        final href = link.attributes['href']?.trim();
        if (href != null && href.isNotEmpty) {
          link.attributes['href'] = _resolveUrl(metadata.sourceUrl, href);
        }
      }
    }

    // 6. Neutralize active JavaScript scripts for security & deterministic offline rendering
    final scriptNodes = document.querySelectorAll('script');
    for (final script in scriptNodes) {
      script.remove();
    }

    // Remove inline JavaScript event handlers (onclick, onerror, onload, etc.)
    final allElements = document.querySelectorAll('*');
    for (final el in allElements) {
      final inlineEventAttrs = el.attributes.keys
          .where((k) => k.toString().toLowerCase().startsWith('on'))
          .toList();
      for (final attr in inlineEventAttrs) {
        el.attributes.remove(attr);
      }
    }

    // 7. Rewrite image sources to local assets if mapped, otherwise resolve relative URLs
    final imgNodes = document.querySelectorAll('img');
    for (final img in imgNodes) {
      final src = img.attributes['src']?.trim();
      if (src != null && src.isNotEmpty) {
        final resolved = _resolveUrl(metadata.sourceUrl, src);
        if (localImageSources.containsKey(src)) {
          img.attributes['src'] = localImageSources[src]!;
        } else if (localImageSources.containsKey(resolved)) {
          img.attributes['src'] = localImageSources[resolved]!;
        } else if (!src.startsWith('data:') && !src.startsWith('qp://')) {
          img.attributes['src'] = resolved;
        }
      }
    }

    return document.outerHtml;
  }

  /// Generates the UTF-8 encoded bytes of the snapshot.
  Future<Uint8List> generateSnapshotBytes({
    required String rawHtml,
    required ExtractedArticleMetadata metadata,
    dom.Element? cleanedElement,
    Map<String, String> localImageSources = const <String, String>{},
  }) async {
    final html = await generateHtmlSnapshot(
      rawHtml: rawHtml,
      metadata: metadata,
      cleanedElement: cleanedElement,
      localImageSources: localImageSources,
    );
    return Uint8List.fromList(utf8.encode(html));
  }

  String _resolveUrl(String baseUrl, String relativeUrl) {
    try {
      final baseUri = Uri.parse(baseUrl);
      final resolved = baseUri.resolve(relativeUrl);
      return resolved.toString();
    } catch (_) {
      return relativeUrl;
    }
  }

  String _rewriteCssUrls(String css, String cssUrl) {
    return css.replaceAllMapped(
      RegExp(
        r'''url\(\s*['"]?(?!data:|http:\/\/|https:\/\/|\/\/|#)([^'")]+)['"]?\s*\)''',
        caseSensitive: false,
      ),
      (match) {
        final rawRelative = match.group(1)?.trim();
        if (rawRelative == null || rawRelative.isEmpty) return match.group(0)!;
        final absolute = _resolveUrl(cssUrl, rawRelative);
        return 'url("$absolute")';
      },
    );
  }

  String _htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
