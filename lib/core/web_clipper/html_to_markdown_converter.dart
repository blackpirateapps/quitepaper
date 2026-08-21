import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'web_clipper_models.dart';

/// Converts cleaned HTML DOM nodes into structured, elegant Markdown with YAML frontmatter.
class HtmlToMarkdownConverter {
  const HtmlToMarkdownConverter();

  /// Converts the [cleanedElement] and [metadata] into full markdown with YAML frontmatter,
  /// hero image header, and structured typography.
  String convert({
    required dom.Element cleanedElement,
    required ExtractedArticleMetadata metadata,
    List<String> tags = const <String>[],
    String? snapshotDocumentId,
    int? snapshotSizeBytes,
    String? leadImageMarkdown,
  }) {
    final buffer = StringBuffer();

    // 1. YAML Frontmatter
    buffer.writeln('---');
    buffer.writeln('title: ${_escapeYaml(metadata.title)}');
    buffer.writeln('source: "${metadata.sourceUrl}"');
    if (metadata.author != null && metadata.author!.trim().isNotEmpty) {
      buffer.writeln('author: "${metadata.author!.trim()}"');
    }
    final createdDate = metadata.publishedDate ?? DateTime.now();
    buffer.writeln('created: "${DateFormat('yyyy-MM-dd').format(createdDate)}"');
    if (metadata.description != null && metadata.description!.trim().isNotEmpty) {
      buffer.writeln('description: ${_escapeYaml(metadata.description!.trim())}');
    }

    final allTags = <String>{
      'clipped',
      if (metadata.domain.isNotEmpty) metadata.domain,
      ...tags,
    };
    if (allTags.isNotEmpty) {
      buffer.writeln('tags:');
      for (final tag in allTags) {
        final sanitized = tag.replaceAll('#', '').trim();
        if (sanitized.isNotEmpty) {
          buffer.writeln('  - $sanitized');
        }
      }
    }
    buffer.writeln('---');
    buffer.writeln();

    // 2. Web Snapshot Banner (if attached)
    if (snapshotDocumentId != null && snapshotDocumentId.isNotEmpty) {
      final sizeStr = snapshotSizeBytes != null && snapshotSizeBytes > 0
          ? ' • ${_formatBytes(snapshotSizeBytes)}'
          : '';
      buffer.writeln('> 🌐 **Original Web Snapshot Attached**$sizeStr — [View Web Snapshot →](qp://document/$snapshotDocumentId)');
      buffer.writeln();
    }

    // 3. Lead / Hero Image
    if (leadImageMarkdown != null && leadImageMarkdown.isNotEmpty) {
      buffer.writeln(leadImageMarkdown);
      buffer.writeln();
    }

    // 4. Convert DOM Children to Markdown
    final bodyMarkdown = _convertNode(cleanedElement).trim();
    buffer.write(bodyMarkdown);
    buffer.writeln();

    return buffer.toString();
  }

  String _convertNode(dom.Node node, {int listDepth = 0, bool isOrdered = false, int itemIndex = 1}) {
    if (node is dom.Text) {
      return _cleanText(node.text);
    }

    if (node is! dom.Element) {
      return '';
    }

    final el = node;
    final tagName = el.localName?.toLowerCase() ?? '';

    switch (tagName) {
      case 'h1':
        return '\n\n# ${_childrenToText(el)}\n\n';
      case 'h2':
        return '\n\n## ${_childrenToText(el)}\n\n';
      case 'h3':
        return '\n\n### ${_childrenToText(el)}\n\n';
      case 'h4':
        return '\n\n#### ${_childrenToText(el)}\n\n';
      case 'h5':
        return '\n\n##### ${_childrenToText(el)}\n\n';
      case 'h6':
        return '\n\n###### ${_childrenToText(el)}\n\n';

      case 'p':
        final content = _childrenToText(el).trim();
        if (content.isEmpty) return '';
        return '\n\n$content\n\n';

      case 'b':
      case 'strong':
        final content = _childrenToText(el).trim();
        if (content.isEmpty) return '';
        return '**$content**';

      case 'i':
      case 'em':
        final content = _childrenToText(el).trim();
        if (content.isEmpty) return '';
        return '*$content*';

      case 'mark':
        final content = _childrenToText(el).trim();
        if (content.isEmpty) return '';
        return '==$content==';

      case 's':
      case 'strike':
      case 'del':
        final content = _childrenToText(el).trim();
        if (content.isEmpty) return '';
        return '~~$content~~';

      case 'code':
        if (el.parent?.localName?.toLowerCase() == 'pre') {
          return el.text;
        }
        final codeText = el.text;
        if (codeText.isEmpty) return '';
        return '`$codeText`';

      case 'pre':
        final codeEl = el.querySelector('code');
        final codeText = (codeEl != null ? codeEl.text : el.text).trim();
        final langClass = codeEl?.className ?? el.className;
        var lang = '';
        final match = RegExp(r'language-([a-zA-Z0-9_\-]+)').firstMatch(langClass);
        if (match != null) {
          lang = match.group(1) ?? '';
        }
        return '\n\n```$lang\n$codeText\n```\n\n';

      case 'blockquote':
        final text = _childrenToText(el).trim();
        if (text.isEmpty) return '';
        final lines = text.split('\n');
        return '\n\n${lines.map((l) => '> $l').join('\n')}\n\n';

      case 'ul':
        final buf = StringBuffer('\n');
        for (final child in el.children) {
          if (child.localName?.toLowerCase() == 'li') {
            final indent = '  ' * listDepth;
            final text = _childrenToText(child, listDepth: listDepth + 1).trim();
            buf.writeln('$indent- $text');
          }
        }
        buf.writeln();
        return buf.toString();

      case 'ol':
        final buf = StringBuffer('\n');
        var idx = 1;
        for (final child in el.children) {
          if (child.localName?.toLowerCase() == 'li') {
            final indent = '  ' * listDepth;
            final text = _childrenToText(child, listDepth: listDepth + 1, isOrdered: true, itemIndex: idx).trim();
            buf.writeln('$indent$idx. $text');
            idx++;
          }
        }
        buf.writeln();
        return buf.toString();

      case 'li':
        return _childrenToText(el, listDepth: listDepth);

      case 'a':
        final href = el.attributes['href']?.trim() ?? '';
        final text = _childrenToText(el).trim();
        if (text.isEmpty && href.isEmpty) return '';
        if (href.isEmpty) return text;
        if (text.isEmpty) return href;
        return '[$text]($href)';

      case 'img':
        final src = el.attributes['src']?.trim() ?? '';
        if (src.isEmpty) return '';
        final alt = el.attributes['alt']?.trim() ?? 'Image';
        return '\n\n![$alt]($src)\n\n';

      case 'figure':
        final img = el.querySelector('img');
        final figcaption = el.querySelector('figcaption')?.text.trim();
        final imgMarkdown = img != null ? _convertNode(img) : '';
        if (figcaption != null && figcaption.isNotEmpty) {
          return '$imgMarkdown\n*$figcaption*\n\n';
        }
        return imgMarkdown;

      case 'table':
        return _convertTable(el);

      case 'hr':
        return '\n\n---\n\n';

      case 'br':
        return '\n';

      default:
        return _childrenToText(el, listDepth: listDepth);
    }
  }

  String _childrenToText(
    dom.Element el, {
    int listDepth = 0,
    bool isOrdered = false,
    int itemIndex = 1,
  }) {
    final buf = StringBuffer();
    for (final node in el.nodes) {
      buf.write(_convertNode(
        node,
        listDepth: listDepth,
        isOrdered: isOrdered,
        itemIndex: itemIndex,
      ));
    }
    return buf.toString();
  }

  String _convertTable(dom.Element tableEl) {
    final rows = tableEl.querySelectorAll('tr');
    if (rows.isEmpty) return '';

    final tableData = <List<String>>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('th, td');
      if (cells.isEmpty) continue;
      tableData.add(cells.map((c) => _childrenToText(c).trim().replaceAll('\n', ' ')).toList());
    }

    if (tableData.isEmpty) return '';

    final maxCols = tableData.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    if (maxCols == 0) return '';

    final buf = StringBuffer('\n\n');

    // Header row
    final header = tableData.first;
    buf.write('| ');
    for (var i = 0; i < maxCols; i++) {
      final text = i < header.length ? header[i] : '';
      buf.write('${text.isNotEmpty ? text : " "} | ');
    }
    buf.writeln();

    // Separator row
    buf.write('| ');
    for (var i = 0; i < maxCols; i++) {
      buf.write('--- | ');
    }
    buf.writeln();

    // Body rows
    for (var r = 1; r < tableData.length; r++) {
      final row = tableData[r];
      buf.write('| ');
      for (var i = 0; i < maxCols; i++) {
        final text = i < row.length ? row[i] : '';
        buf.write('${text.isNotEmpty ? text : " "} | ');
      }
      buf.writeln();
    }
    buf.writeln();

    return buf.toString();
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  String _escapeYaml(String value) {
    if (value.contains('\n') || value.contains('"') || value.contains(':') || value.contains('#')) {
      final escaped = value.replaceAll('"', r'\"').replaceAll('\n', ' ');
      return '"$escaped"';
    }
    return '"$value"';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
