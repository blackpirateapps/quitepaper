import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'web_clipper_models.dart';

/// Generates self-contained, sanitized offline HTML/CSS snapshot documents
/// adapting to Quiet Paper's warm editorial palette.
class WebSnapshotGenerator {
  const WebSnapshotGenerator();

  /// Generates a standalone HTML document string from [cleanedElement] and [metadata].
  String generateHtmlSnapshot({
    required dom.Element cleanedElement,
    required ExtractedArticleMetadata metadata,
    Map<String, String> localImageSources = const <String, String>{},
  }) {
    // Clone element to avoid mutating original DOM
    final elementClone = cleanedElement.clone(true);

    // Rewrite image sources to local assets if present
    if (localImageSources.isNotEmpty) {
      final imgNodes = elementClone.querySelectorAll('img');
      for (final img in imgNodes) {
        final src = img.attributes['src'];
        if (src != null && localImageSources.containsKey(src)) {
          img.attributes['src'] = localImageSources[src]!;
        }
      }
    }

    final dateFormatted = metadata.publishedDate != null
        ? DateFormat('MMMM d, yyyy').format(metadata.publishedDate!)
        : null;

    final htmlBuffer = StringBuffer();
    htmlBuffer.writeln('<!DOCTYPE html>');
    htmlBuffer.writeln('<html lang="en">');
    htmlBuffer.writeln('<head>');
    htmlBuffer.writeln('  <meta charset="utf-8">');
    htmlBuffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">');
    htmlBuffer.writeln('  <title>${_htmlEscape(metadata.title)}</title>');
    htmlBuffer.writeln('  <style>');
    htmlBuffer.writeln(_baseCssStyles);
    htmlBuffer.writeln('  </style>');
    htmlBuffer.writeln('</head>');
    htmlBuffer.writeln('<body>');
    htmlBuffer.writeln('  <div class="qp-article-container">');

    // Article Header
    htmlBuffer.writeln('    <header class="qp-header">');
    htmlBuffer.writeln('      <div class="qp-domain-badge">${_htmlEscape(metadata.domain)}</div>');
    htmlBuffer.writeln('      <h1 class="qp-title">${_htmlEscape(metadata.title)}</h1>');
    htmlBuffer.writeln('      <div class="qp-byline">');
    if (metadata.author != null && metadata.author!.trim().isNotEmpty) {
      htmlBuffer.writeln('        <span class="qp-author">By ${_htmlEscape(metadata.author!.trim())}</span>');
    }
    if (dateFormatted != null) {
      htmlBuffer.writeln('        <span class="qp-date">• $dateFormatted</span>');
    }
    htmlBuffer.writeln('      </div>');
    htmlBuffer.writeln('    </header>');

    // Lead Hero Image (if found)
    if (metadata.leadImageUrl != null && metadata.leadImageUrl!.isNotEmpty) {
      final leadSrc = localImageSources[metadata.leadImageUrl] ?? metadata.leadImageUrl!;
      htmlBuffer.writeln('    <div class="qp-hero-image">');
      htmlBuffer.writeln('      <img src="${_htmlEscape(leadSrc)}" alt="Featured image" loading="lazy">');
      htmlBuffer.writeln('    </div>');
    }

    // Article Content Body
    htmlBuffer.writeln('    <main class="qp-content">');
    htmlBuffer.writeln(elementClone.innerHtml);
    htmlBuffer.writeln('    </main>');

    // Footer Attribution
    htmlBuffer.writeln('    <footer class="qp-footer">');
    htmlBuffer.writeln('      <p>Clipped with <a href="${_htmlEscape(metadata.sourceUrl)}" target="_blank" rel="noopener">Quiet Paper</a></p>');
    htmlBuffer.writeln('    </footer>');

    htmlBuffer.writeln('  </div>');
    htmlBuffer.writeln('</body>');
    htmlBuffer.writeln('</html>');

    return htmlBuffer.toString();
  }

  /// Generates the UTF-8 encoded bytes of the snapshot.
  Uint8List generateSnapshotBytes({
    required dom.Element cleanedElement,
    required ExtractedArticleMetadata metadata,
    Map<String, String> localImageSources = const <String, String>{},
  }) {
    final html = generateHtmlSnapshot(
      cleanedElement: cleanedElement,
      metadata: metadata,
      localImageSources: localImageSources,
    );
    return Uint8List.fromList(utf8.encode(html));
  }

  String _htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static const String _baseCssStyles = '''
:root {
  --qp-bg: #F7F6F2;
  --qp-text: #1D1C1A;
  --qp-text-secondary: #6B6860;
  --qp-text-tertiary: #9C988F;
  --qp-surface: #FFFFFF;
  --qp-divider: #E6E4DD;
  --qp-accent: #E06C53;
  --qp-code-bg: #EFECE6;
  --qp-max-width: 720px;
}

@media (prefers-color-scheme: dark) {
  :root {
    --qp-bg: #1D1C1A;
    --qp-text: #E8E6DF;
    --qp-text-secondary: #A8A59D;
    --qp-text-tertiary: #6E6B64;
    --qp-surface: #242320;
    --qp-divider: #2C2A27;
    --qp-accent: #E87A63;
    --qp-code-bg: #282623;
  }
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background-color: var(--qp-bg);
  color: var(--qp-text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Inter", Helvetica, Arial, sans-serif;
  font-size: 17px;
  line-height: 1.68;
  letter-spacing: -0.011em;
  padding: 24px 16px 48px;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.qp-article-container {
  max-width: var(--qp-max-width);
  margin: 0 auto;
}

.qp-header {
  margin-bottom: 28px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--qp-divider);
}

.qp-domain-badge {
  display: inline-block;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--qp-accent);
  margin-bottom: 12px;
}

.qp-title {
  font-size: 30px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: -0.022em;
  margin-bottom: 12px;
  color: var(--qp-text);
}

.qp-byline {
  font-size: 14px;
  color: var(--qp-text-secondary);
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.qp-hero-image {
  margin: 20px 0 28px;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid var(--qp-divider);
}

.qp-hero-image img {
  width: 100%;
  height: auto;
  display: block;
  object-fit: cover;
  max-height: 420px;
}

.qp-content {
  color: var(--qp-text);
}

.qp-content h1,
.qp-content h2,
.qp-content h3,
.qp-content h4,
.qp-content h5,
.qp-content h6 {
  color: var(--qp-text);
  font-weight: 700;
  line-height: 1.35;
  margin: 32px 0 14px;
}

.qp-content h1 { font-size: 24px; }
.qp-content h2 { font-size: 21px; }
.qp-content h3 { font-size: 19px; }
.qp-content h4 { font-size: 17px; }

.qp-content p {
  margin-bottom: 18px;
}

.qp-content a {
  color: var(--qp-accent);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.qp-content blockquote {
  border-left: 3px solid var(--qp-accent);
  margin: 20px 0;
  padding: 8px 0 8px 18px;
  color: var(--qp-text-secondary);
  font-style: italic;
}

.qp-content ul,
.qp-content ol {
  margin: 16px 0 20px 24px;
}

.qp-content li {
  margin-bottom: 8px;
}

.qp-content img {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 16px 0;
  display: block;
  border: 1px solid var(--qp-divider);
}

.qp-content figure {
  margin: 20px 0;
}

.qp-content figcaption {
  font-size: 13px;
  color: var(--qp-text-tertiary);
  text-align: center;
  margin-top: 6px;
  font-style: italic;
}

.qp-content code {
  background-color: var(--qp-code-bg);
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 0.9em;
  font-family: "JetBrains Mono", "Fira Code", monospace;
}

.qp-content pre {
  background-color: var(--qp-code-bg);
  padding: 14px 16px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 20px 0;
  border: 1px solid var(--qp-divider);
}

.qp-content pre code {
  padding: 0;
  background: transparent;
}

.qp-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 24px 0;
  font-size: 15px;
}

.qp-content th,
.qp-content td {
  border: 1px solid var(--qp-divider);
  padding: 10px 12px;
  text-align: left;
}

.qp-content th {
  background-color: var(--qp-surface);
  font-weight: 600;
}

.qp-footer {
  margin-top: 48px;
  padding-top: 20px;
  border-top: 1px solid var(--qp-divider);
  font-size: 13px;
  color: var(--qp-text-tertiary);
  text-align: center;
}

.qp-footer a {
  color: var(--qp-accent);
  text-decoration: none;
}
''';
}
