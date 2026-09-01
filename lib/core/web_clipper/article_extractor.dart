import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'clipped_image_filter.dart';
import 'web_clipper_models.dart';

/// Readability and article extraction engine.
///
/// Parses HTML documents, extracts rich article metadata (OpenGraph, Twitter cards, meta tags),
/// scores DOM candidate nodes, removes noisy elements (ads, navbars, sidebars, tracking scripts),
/// and extracts candidate article images.
class ArticleExtractor {
  const ArticleExtractor();

  static final RegExp _unlikelyCandidateRegex = RegExp(
    r'(combx|comment|community|disqus|extra|foot|header|menu|nav|navbar|pagination|sidebar|social|sponsor|widget|ad-break|agegate|pagination|pager|popup|yom-ad|cookie|banner|newsletter)',
    caseSensitive: false,
  );

  static final RegExp _likelyCandidateRegex = RegExp(
    r'(article|body|content|entry|hentry|main|page|pagination|post|text|blog|story)',
    caseSensitive: false,
  );

  /// Extracts article metadata, cleaned content element, and image candidates from raw [htmlContent].
  ({
    ExtractedArticleMetadata metadata,
    dom.Element cleanedElement,
    List<ClippedImageCandidate> images,
    bool isArticleRootFound,
  }) extract({
    required String htmlContent,
    required String sourceUrl,
  }) {
    final document = html_parser.parse(htmlContent);
    final baseUri = Uri.tryParse(sourceUrl) ?? Uri();

    // 1. Extract metadata from <head> and document
    final metadata = _extractMetadata(document, sourceUrl, baseUri);

    // 2. Locate and isolate the best content container
    final rootResult = _findArticleRoot(document);

    // 3. Clone and sanitize the candidate element
    final cleanedElement = _sanitizeElement(rootResult.element.clone(true), baseUri);

    // 4. Discover candidate images in article and lead image
    final images = _discoverImages(cleanedElement, metadata.leadImageUrl, baseUri);

    return (
      metadata: metadata,
      cleanedElement: cleanedElement,
      images: images,
      isArticleRootFound: rootResult.isArticleRootFound,
    );
  }

  /// Convenience method for extracting article content from raw HTML and source URL.
  ({
    ExtractedArticleMetadata metadata,
    dom.Element cleanedElement,
    List<ClippedImageCandidate> images,
    bool isArticleRootFound,
  }) extractFromHtml(
    String htmlContent,
    String sourceUrl,
  ) =>
      extract(htmlContent: htmlContent, sourceUrl: sourceUrl);

  /// Fallback extraction when article root scoring fails or full page content preservation is requested.
  /// Sanitizes the full body element (stripping scripts, styles, forms, and ad noise) while preserving content.
  ({
    ExtractedArticleMetadata metadata,
    dom.Element cleanedElement,
    List<ClippedImageCandidate> images,
    bool isArticleRootFound,
  }) extractFallback({
    required String htmlContent,
    required String sourceUrl,
  }) {
    final document = html_parser.parse(htmlContent);
    final baseUri = Uri.tryParse(sourceUrl) ?? Uri();
    final metadata = _extractMetadata(document, sourceUrl, baseUri);
    final bodyRoot = document.body ?? document.documentElement ?? dom.Element.tag('div');
    final cleanedElement = _sanitizeElement(bodyRoot.clone(true), baseUri);
    final images = _discoverImages(cleanedElement, metadata.leadImageUrl, baseUri);

    return (
      metadata: metadata,
      cleanedElement: cleanedElement,
      images: images,
      isArticleRootFound: false,
    );
  }

  ExtractedArticleMetadata _extractMetadata(
    dom.Document doc,
    String sourceUrl,
    Uri baseUri,
  ) {
    String? ogTitle = _getMetaContent(doc, 'og:title', isProperty: true);
    String? twitterTitle = _getMetaContent(doc, 'twitter:title');
    String? docTitle = doc.querySelector('title')?.text.trim();
    String? h1Title = doc.querySelector('h1')?.text.trim();

    String title = (ogTitle?.isNotEmpty == true
            ? ogTitle
            : (twitterTitle?.isNotEmpty == true
                ? twitterTitle
                : (docTitle?.isNotEmpty == true
                    ? docTitle
                    : (h1Title?.isNotEmpty == true ? h1Title : 'Web Article')))) ??
        'Web Article';

    // Clean title suffixes (e.g. "Title — SiteName" or "Title | Domain")
    title = _cleanTitle(title);

    String? author = _getMetaContent(doc, 'article:author', isProperty: true) ??
        _getMetaContent(doc, 'author') ??
        _getMetaContent(doc, 'twitter:creator') ??
        doc.querySelector('.author, .byline, [rel="author"], .c-byline')?.text.trim();

    DateTime? publishedDate;
    final dateStr = _getMetaContent(doc, 'article:published_time', isProperty: true) ??
        _getMetaContent(doc, 'date') ??
        _getMetaContent(doc, 'pubdate') ??
        doc.querySelector('time[datetime]')?.attributes['datetime'] ??
        doc.querySelector('time')?.text.trim();

    if (dateStr != null && dateStr.isNotEmpty) {
      publishedDate = DateTime.tryParse(dateStr);
    }

    String? description = _getMetaContent(doc, 'og:description', isProperty: true) ??
        _getMetaContent(doc, 'twitter:description') ??
        _getMetaContent(doc, 'description');

    String? leadImageUrl = _getMetaContent(doc, 'og:image', isProperty: true) ??
        _getMetaContent(doc, 'twitter:image') ??
        _getMetaContent(doc, 'twitter:image:src');

    if (leadImageUrl != null && leadImageUrl.isNotEmpty) {
      leadImageUrl = _resolveUrl(leadImageUrl, baseUri);
    }

    String? siteName = _getMetaContent(doc, 'og:site_name', isProperty: true);
    String domain = baseUri.host.replaceFirst(RegExp(r'^www\.'), '');
    if (domain.isEmpty) {
      domain = 'web';
    }

    return ExtractedArticleMetadata(
      sourceUrl: sourceUrl,
      title: title,
      author: author,
      publishedDate: publishedDate,
      description: description,
      leadImageUrl: leadImageUrl,
      domain: domain,
      siteName: siteName,
    );
  }

  String? _getMetaContent(dom.Document doc, String name, {bool isProperty = false}) {
    final attr = isProperty ? 'property' : 'name';
    final el = doc.querySelector('meta[$attr="$name"], meta[$attr="${name.toLowerCase()}"]');
    final content = el?.attributes['content']?.trim();
    return (content != null && content.isNotEmpty) ? content : null;
  }

  String _cleanTitle(String rawTitle) {
    var cleaned = rawTitle.trim();
    // Common site title separators: " | ", " - ", " — ", " :: "
    final separators = [' — ', ' – ', ' | ', ' :: ', ' - '];
    for (final sep in separators) {
      if (cleaned.contains(sep)) {
        final parts = cleaned.split(sep);
        if (parts.first.trim().length >= 10) {
          cleaned = parts.first.trim();
          break;
        }
      }
    }
    return cleaned;
  }

  ({dom.Element element, bool isArticleRootFound}) _findArticleRoot(dom.Document doc) {
    // 1. Check explicit semantic containers
    final explicitArticle = doc.querySelector('article');
    if (explicitArticle != null && _calculateTextLength(explicitArticle) > 200) {
      return (element: explicitArticle, isArticleRootFound: true);
    }

    final explicitMain = doc.querySelector('main, [role="main"]');
    if (explicitMain != null && _calculateTextLength(explicitMain) > 200) {
      return (element: explicitMain, isArticleRootFound: true);
    }

    // 2. Score candidate DIV / SECTION elements
    dom.Element? bestCandidate;
    double highestScore = 0;

    final candidates = doc.querySelectorAll('div, section, article, main');
    for (final candidate in candidates) {
      final score = _scoreElement(candidate);
      if (score > highestScore) {
        highestScore = score;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate != null && highestScore > 20) {
      return (element: bestCandidate, isArticleRootFound: true);
    }

    if (explicitArticle != null) {
      return (element: explicitArticle, isArticleRootFound: true);
    }

    // Fallback to body or document element
    final fallbackEl = doc.body ?? doc.documentElement ?? dom.Element.tag('div');
    return (element: fallbackEl, isArticleRootFound: false);
  }

  double _scoreElement(dom.Element el) {
    final text = el.text.trim();
    final textLength = text.length;
    if (textLength < 100) return 0;

    double score = 0;
    final className = el.className;
    final id = el.id;

    if (_likelyCandidateRegex.hasMatch(className)) score += 25;
    if (_likelyCandidateRegex.hasMatch(id)) score += 25;
    if (_unlikelyCandidateRegex.hasMatch(className)) score -= 25;
    if (_unlikelyCandidateRegex.hasMatch(id)) score -= 25;

    // Paragraph count bonus
    final pTags = el.querySelectorAll('p');
    score += pTags.length * 10;

    // Word count / comma count bonus
    final commaCount = ','.allMatches(text).length;
    score += commaCount * 2;
    score += (textLength / 100);

    // Link density penalty
    final linkTextLength = el.querySelectorAll('a').fold<int>(
          0,
          (prev, a) => prev + a.text.trim().length,
        );
    final linkDensity = textLength > 0 ? (linkTextLength / textLength) : 1.0;
    if (linkDensity > 0.5) {
      score *= 0.3; // Heavy link density (e.g. navigation menu, blogroll)
    }

    return score;
  }

  int _calculateTextLength(dom.Element el) => el.text.trim().length;

  dom.Element _sanitizeElement(dom.Element el, Uri baseUri) {
    // 1. Remove blacklisted noisy tags
    const blockedTags = {
      'script',
      'style',
      'noscript',
      'iframe',
      'canvas',
      'svg',
      'form',
      'input',
      'button',
      'select',
      'textarea',
      'nav',
      'footer',
      'header',
      'aside',
      'dialog',
    };

    el.querySelectorAll(blockedTags.join(',')).forEach((node) => node.remove());

    // 2. Remove elements with obvious ad/noise class/id
    final allChildren = el.querySelectorAll('*');
    for (final child in allChildren) {
      final className = child.className;
      final id = child.id;

      if (_unlikelyCandidateRegex.hasMatch(className) ||
          _unlikelyCandidateRegex.hasMatch(id)) {
        if (!_likelyCandidateRegex.hasMatch(className) &&
            !_likelyCandidateRegex.hasMatch(id) &&
            child.localName != 'body') {
          child.remove();
          continue;
        }
      }

      // 3. Process <picture> and <img> elements
      if (child.localName == 'picture') {
        final bestSrc = ClippedImageFilter.extractBestImageSource(child, baseUri);
        final img = child.querySelector('img') ?? dom.Element.tag('img');
        if (bestSrc != null && bestSrc.isNotEmpty) {
          img.attributes['src'] = bestSrc;
        }
        // Remove <source> children to keep DOM clean for markdown conversion
        child.querySelectorAll('source').forEach((s) => s.remove());
        if (child.children.isEmpty && bestSrc != null) {
          child.append(img);
        }
      } else if (child.localName == 'img') {
        if (child.parent?.localName == 'picture') {
          // Already handled by picture processor above
          continue;
        }

        if (!ClippedImageFilter.isUsefulContentImage(child, baseUri: baseUri)) {
          child.remove();
          continue;
        }

        final bestSrc = ClippedImageFilter.extractBestImageSource(child, baseUri);
        if (bestSrc != null && bestSrc.isNotEmpty) {
          child.attributes['src'] = bestSrc;
        }
      }

      // 4. Resolve links
      if (child.localName == 'a') {
        final href = child.attributes['href'];
        if (href != null && href.isNotEmpty) {
          child.attributes['href'] = _resolveUrl(href, baseUri);
        }
      }
    }

    return el;
  }

  List<ClippedImageCandidate> _discoverImages(
    dom.Element articleEl,
    String? leadImageUrl,
    Uri baseUri,
  ) {
    final images = <ClippedImageCandidate>[];
    final seenUrls = <String>{};

    // 1. Add lead image if present
    if (leadImageUrl != null && leadImageUrl.isNotEmpty) {
      final resolved = ClippedImageFilter.resolveUrl(leadImageUrl, baseUri);
      if (ClippedImageFilter.isUsefulImageUrl(resolved)) {
        images.add(ClippedImageCandidate(
          rawUrl: leadImageUrl,
          resolvedUrl: resolved,
          altText: 'Lead Image',
          isLeadImage: true,
          isSelected: true,
          estimatedSizeBytes: 350 * 1024, // Initial estimate 350KB
        ));
        seenUrls.add(resolved);
      }
    }

    // 2. Discover inline article images from <picture> and <img>
    final imgNodes = articleEl.querySelectorAll('img, picture');
    for (final node in imgNodes) {
      dom.Element imgEl;
      if (node.localName == 'picture') {
        imgEl = node.querySelector('img') ?? node;
      } else {
        if (node.parent?.localName == 'picture') {
          continue; // Avoid duplicate processing of picture children
        }
        imgEl = node;
      }

      final bestSrc = ClippedImageFilter.extractBestImageSource(node, baseUri);
      if (bestSrc == null || bestSrc.isEmpty) continue;

      final resolved = ClippedImageFilter.resolveUrl(bestSrc, baseUri);
      if (seenUrls.contains(resolved)) continue;

      if (!ClippedImageFilter.isUsefulImageUrl(resolved, altText: imgEl.attributes['alt'])) {
        continue;
      }

      // Extract alt & caption
      final alt = imgEl.attributes['alt']?.trim() ?? '';
      var caption = '';

      // Check parent figure caption
      final parentFigure = node.parent?.localName == 'figure'
          ? node.parent
          : (node.parent?.parent?.localName == 'figure' ? node.parent?.parent : null);
      if (parentFigure != null) {
        caption = parentFigure.querySelector('figcaption')?.text.trim() ?? '';
      }

      images.add(ClippedImageCandidate(
        rawUrl: bestSrc,
        resolvedUrl: resolved,
        altText: alt.isNotEmpty ? alt : (caption.isNotEmpty ? caption : 'Article image'),
        caption: caption,
        isLeadImage: false,
        isSelected: true,
        estimatedSizeBytes: 250 * 1024, // Initial estimate 250KB
      ));
      seenUrls.add(resolved);

      if (images.length >= 35) {
        break;
      }
    }

    return images;
  }

  String _resolveUrl(String url, Uri baseUri) =>
      ClippedImageFilter.resolveUrl(url, baseUri);
}
