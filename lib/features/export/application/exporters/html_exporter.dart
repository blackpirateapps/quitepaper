import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import '../../domain/export_models.dart';
import '../export_security_guard.dart';
import '../ocr_export_resolver.dart';

/// Exporter for compiling notes into standalone, self-contained HTML5 documents (.html).
class HtmlExporter {
  const HtmlExporter();

  Future<ExportResult> exportHtml({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final isDark = request.htmlOptions.darkMode;
    final dateFmt = DateFormat('MMMM d, yyyy');

    // 1. Process Markdown body to HTML
    var markdownContent = snapshot.markdown;

    // Strip YAML frontmatter from body if already present
    if (markdownContent.startsWith('---')) {
      final endIndex = markdownContent.indexOf('\n---', 3);
      if (endIndex != -1) {
        markdownContent = markdownContent.substring(endIndex + 4).trimLeft();
      }
    }

    // Embed images as base64 data URIs if enabled
    if (request.htmlOptions.embedImagesAsBase64 && snapshot.attachments.isNotEmpty) {
      for (final att in snapshot.attachments) {
        if (att.hasBytes) {
          final b64 = base64Encode(att.bytes!);
          final dataUri = 'data:${att.mimeType};base64,$b64';
          markdownContent = markdownContent.replaceAll(
            att.relativePath,
            dataUri,
          );
          markdownContent = markdownContent.replaceAll(
            'qp://asset/${att.id}',
            dataUri,
          );
        }
      }
    }

    // Append OCR if configured
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument) {
      final ocrAppendix = OcrExportResolver.formatOcrAppendix(snapshot.ocrData);
      markdownContent += ocrAppendix;
    }

    // Render markdown to HTML using GitHub Flavored Markdown extensions
    final bodyHtml = md.markdownToHtml(
      markdownContent,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        _HtmlHighlightSyntax(),
      ],
    );

    // Escape note title & tags
    final escapedTitle = ExportSecurityGuard.escapeHtml(snapshot.effectiveTitle);

    final htmlBuffer = StringBuffer();
    htmlBuffer.writeln('<!DOCTYPE html>');
    htmlBuffer.writeln('<html lang="en">');
    htmlBuffer.writeln('<head>');
    htmlBuffer.writeln('  <meta charset="UTF-8">');
    htmlBuffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    htmlBuffer.writeln('  <title>$escapedTitle</title>');
    htmlBuffer.writeln('  <style>');
    htmlBuffer.writeln(_buildStylesheet(isDark: isDark));
    htmlBuffer.writeln('  </style>');
    htmlBuffer.writeln('</head>');
    htmlBuffer.writeln('<body>');
    htmlBuffer.writeln('  <main class="note-container">');

    // Document title
    htmlBuffer.writeln('    <header class="note-header">');
    htmlBuffer.writeln('      <h1 class="note-title">$escapedTitle</h1>');

    // Metadata card
    if (request.includeMetadata) {
      htmlBuffer.writeln('      <div class="note-metadata">');
      htmlBuffer.writeln('        <div class="metadata-row">');
      htmlBuffer.writeln('          <span class="meta-label">Created:</span>');
      htmlBuffer.writeln('          <span class="meta-value">${dateFmt.format(snapshot.createdAt.toLocal())}</span>');
      htmlBuffer.writeln('        </div>');
      htmlBuffer.writeln('        <div class="metadata-row">');
      htmlBuffer.writeln('          <span class="meta-label">Updated:</span>');
      htmlBuffer.writeln('          <span class="meta-value">${dateFmt.format(snapshot.updatedAt.toLocal())}</span>');
      htmlBuffer.writeln('        </div>');
      if (snapshot.tags.isNotEmpty) {
        htmlBuffer.writeln('        <div class="metadata-row">');
        htmlBuffer.writeln('          <span class="meta-label">Tags:</span>');
        htmlBuffer.writeln('          <div class="tag-chips">');
        for (final tag in snapshot.tags) {
          final escapedTag = ExportSecurityGuard.escapeHtml(tag);
          htmlBuffer.writeln('            <span class="tag-chip">#$escapedTag</span>');
        }
        htmlBuffer.writeln('          </div>');
        htmlBuffer.writeln('        </div>');
      }
      htmlBuffer.writeln('      </div>');
    }
    htmlBuffer.writeln('    </header>');

    // Note content
    htmlBuffer.writeln('    <article class="note-body">');
    htmlBuffer.writeln(bodyHtml);
    htmlBuffer.writeln('    </article>');

    htmlBuffer.writeln('  </main>');
    htmlBuffer.writeln('</body>');
    htmlBuffer.writeln('</html>');

    final fullHtml = htmlBuffer.toString();
    final bytes = utf8.encode(fullHtml);
    await outputFile.writeAsBytes(bytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.html,
      filename: filename,
      byteSize: bytes.length,
      mimeType: ExportFormat.html.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static String _buildStylesheet({required bool isDark}) {
    final bg = isDark ? '#1D1C1A' : '#F7F6F2';
    final surface = isDark ? '#262523' : '#FFFFFF';
    final textPrimary = isDark ? '#F5F5F3' : '#2D2B28';
    final textSecondary = isDark ? '#9E9C98' : '#73706A';
    final textTertiary = isDark ? '#6B6965' : '#A8A6A1';
    final accent = isDark ? '#E5A93C' : '#D97706';
    final divider = isDark ? '#383633' : '#E6E4DD';
    final codeBg = isDark ? '#2E2D2A' : '#ECEAE4';
    final highlightBg = isDark ? 'rgba(229, 169, 60, 0.28)' : 'rgba(217, 119, 6, 0.20)';

    return '''
      :root {
        --bg: $bg;
        --surface: $surface;
        --text-primary: $textPrimary;
        --text-secondary: $textSecondary;
        --text-tertiary: $textTertiary;
        --accent: $accent;
        --divider: $divider;
        --code-bg: $codeBg;
        --highlight-bg: $highlightBg;
      }
      * {
        box-sizing: border-box;
      }
      body {
        margin: 0;
        padding: 0;
        background-color: var(--bg);
        color: var(--text-primary);
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 17px;
        line-height: 1.65;
        letter-spacing: -0.011em;
        -webkit-font-smoothing: antialiased;
      }
      .note-container {
        max-width: 740px;
        margin: 0 auto;
        padding: 48px 24px 80px 24px;
      }
      .note-header {
        margin-bottom: 32px;
        padding-bottom: 24px;
        border-bottom: 1px solid var(--divider);
      }
      .note-title {
        font-size: 32px;
        font-weight: 700;
        line-height: 1.25;
        color: var(--text-primary);
        margin: 0 0 16px 0;
        letter-spacing: -0.02em;
      }
      .note-metadata {
        display: flex;
        flex-direction: column;
        gap: 6px;
        font-size: 13.5px;
        color: var(--text-secondary);
      }
      .metadata-row {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .meta-label {
        font-weight: 600;
        color: var(--text-tertiary);
        width: 68px;
      }
      .meta-value {
        color: var(--text-secondary);
      }
      .tag-chips {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
      }
      .tag-chip {
        display: inline-block;
        background-color: var(--surface);
        border: 1px solid var(--divider);
        color: var(--accent);
        font-weight: 500;
        font-size: 12px;
        padding: 2px 8px;
        border-radius: 6px;
      }
      .note-body {
        color: var(--text-primary);
      }
      .note-body h1, .note-body h2, .note-body h3, .note-body h4, .note-body h5, .note-body h6 {
        color: var(--text-primary);
        font-weight: 700;
        margin-top: 28px;
        margin-bottom: 12px;
        line-height: 1.3;
      }
      .note-body h1 { font-size: 26px; }
      .note-body h2 { font-size: 22px; }
      .note-body h3 { font-size: 19px; }
      .note-body h4 { font-size: 17px; }
      .note-body p {
        margin: 0 0 16px 0;
      }
      .note-body a {
        color: var(--accent);
        text-decoration: underline;
        text-underline-offset: 3px;
      }
      .note-body blockquote {
        margin: 16px 0;
        padding: 8px 16px;
        border-left: 3.5px solid var(--accent);
        background-color: var(--surface);
        border-radius: 0 8px 8px 0;
        color: var(--text-secondary);
      }
      .note-body pre {
        background-color: var(--code-bg);
        border-radius: 8px;
        padding: 16px;
        overflow-x: auto;
        font-family: "JetBrains Mono", "SF Mono", Consolas, Monaco, monospace;
        font-size: 14px;
        line-height: 1.5;
        border: 1px solid var(--divider);
      }
      .note-body code {
        font-family: "JetBrains Mono", "SF Mono", Consolas, Monaco, monospace;
        font-size: 14px;
        background-color: var(--code-bg);
        padding: 2px 6px;
        border-radius: 4px;
      }
      .note-body pre code {
        background: transparent;
        padding: 0;
        border-radius: 0;
      }
      .note-body ul, .note-body ol {
        margin: 0 0 16px 0;
        padding-left: 24px;
      }
      .note-body li {
        margin-bottom: 6px;
      }
      .note-body table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
      }
      .note-body th, .note-body td {
        border: 1px solid var(--divider);
        padding: 10px 14px;
        text-align: left;
      }
      .note-body th {
        background-color: var(--surface);
        font-weight: 600;
      }
      .note-body img {
        max-width: 100%;
        height: auto;
        border-radius: 8px;
        margin: 16px 0;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
      }
      .note-body hr {
        border: none;
        border-top: 1px solid var(--divider);
        margin: 32px 0;
      }
      mark, .highlight {
        background-color: var(--highlight-bg);
        color: inherit;
        padding: 2px 4px;
        border-radius: 4px;
      }
      input[type="checkbox"] {
        margin-right: 8px;
        accent-color: var(--accent);
      }
    ''';
  }
}

/// Inline syntax parser for `==highlighted text==` in Markdown.
class _HtmlHighlightSyntax extends md.InlineSyntax {
  _HtmlHighlightSyntax() : super(r'==([^=\n\r]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1) ?? '';
    final element = md.Element.text('mark', text);
    element.attributes['class'] = 'highlight';
    parser.addNode(element);
    return true;
  }
}
