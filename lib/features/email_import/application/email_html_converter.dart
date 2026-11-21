import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import '../domain/email_message.dart';

/// This converter has no network or widget dependencies. Only CID placeholders
/// can become images; remote/data/file images never enter Markdown image syntax.
class EmailHtmlConverter {
  static String escape(String value) =>
      value.replaceAllMapped(RegExp(r'[\\`*_{\}\[\]<>!|]'), (m) => '\\${m[0]}');

  static String plainText(String value) => value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) {
        // Keep ordinary reply and list structure while escaping inline markup.
        final match = RegExp(
          r'^(\s*(?:>\s*)*(?:(?:[-+*]|\d+[.)])\s+)?)(.*)$',
        ).firstMatch(line)!;
        var text = escape(match[2]!);
        if (RegExp(r'^#{1,6}(?:\s|$)').hasMatch(text) ||
            RegExp(r'^[-=_]{3,}\s*$').hasMatch(text)) {
          text = '\\$text';
        }
        return '${match[1]}$text';
      })
      .join('\n');

  String convert(String source, {Set<String> contentIds = const {}}) {
    // Check tokens before the DOM parser allocates nodes or builds deep stacks.
    // The MIME body byte budget alone cannot bound a million tiny HTML tags.
    var tokens = 0;
    for (final unit in source.codeUnits) {
      if (unit == 60 && ++tokens > 100000) {
        throw const EmailImportException(
          'html_complexity',
          'Email HTML contains too many elements.',
        );
      }
    }
    final stack = <String>[];
    const voidTags = {
      'area',
      'base',
      'br',
      'col',
      'embed',
      'hr',
      'img',
      'input',
      'link',
      'meta',
      'param',
      'source',
      'track',
      'wbr',
    };
    var cursor = 0;
    final tagPattern = RegExp(
      r'^<\s*(/\s*)?([a-zA-Z][a-zA-Z0-9:-]*)(?=[\s/>])',
    );
    final commentEnd = RegExp(r'--!?>');
    while (cursor < source.length) {
      final start = source.indexOf('<', cursor);
      if (start < 0) break;
      // Outlook conditional comments often contain an entire fallback layout.
      // The DOM parser discards that markup; counting it as live elements can
      // reject ordinary email. Match HTML's normal and abrupt comment endings
      // so malformed comments cannot hide live nesting from this preflight.
      if (source.startsWith('<!--', start)) {
        final contentStart = start + 4;
        if (source.startsWith('>', contentStart)) {
          cursor = contentStart + 1;
        } else if (source.startsWith('->', contentStart)) {
          cursor = contentStart + 2;
        } else {
          final end = commentEnd.allMatches(source, contentStart).firstOrNull;
          if (end == null) break;
          cursor = end.end;
        }
        continue;
      }
      final end = source.indexOf('>', start + 1);
      if (end < 0) break;
      if (end - start > 65536) {
        throw const EmailImportException(
          'html_complexity',
          'An email HTML element is too large.',
        );
      }
      final token = source.substring(start, end + 1);
      cursor = end + 1;
      final match = tagPattern.firstMatch(token);
      if (match == null) continue;
      final tag = match[2]!.toLowerCase();
      if (match[1] != null) {
        final index = stack.lastIndexOf(tag);
        if (index >= 0) stack.removeRange(index, stack.length);
      } else if (!voidTags.contains(tag) && !token.endsWith('/>')) {
        if (stack.isNotEmpty &&
            stack.last == tag &&
            {'p', 'li', 'tr', 'td', 'th', 'option'}.contains(tag)) {
          stack.removeLast();
        }
        stack.add(tag);
        if (stack.length > 80) {
          throw const EmailImportException(
            'html_complexity',
            'Email HTML is nested too deeply.',
          );
        }
      }
    }
    final root = html.parseFragment(source);
    var nodes = 0;
    String visit(Node node, int depth, {bool flow = false}) {
      if (++nodes > 200000 || depth > 80) {
        throw const EmailImportException(
          'html_complexity',
          'Email HTML is too complex to import safely.',
        );
      }
      if (node is Text) {
        return escape(node.text.replaceAll(RegExp(r'\s+'), ' '));
      }
      if (node is! Element && node is! DocumentFragment) return '';
      final el = node is Element ? node : null;
      final tag = el?.localName ?? '';
      if ({
        'script',
        'style',
        'iframe',
        'frame',
        'object',
        'embed',
        'form',
        'input',
        'button',
        'select',
        'textarea',
        'svg',
        'math',
        'head',
        'noscript',
        'template',
      }.contains(tag)) {
        return '';
      }
      final style = (el?.attributes['style'] ?? '').toLowerCase().replaceAll(
        RegExp(r'\s'),
        '',
      );
      if (el?.attributes.containsKey('hidden') == true ||
          el?.attributes['aria-hidden'] == 'true' ||
          style.contains('display:none') ||
          style.contains('visibility:hidden') ||
          style.contains('opacity:0;') ||
          style == 'opacity:0') {
        return '';
      }
      if (tag == 'img') {
        final width = int.tryParse(el!.attributes['width'] ?? '');
        final height = int.tryParse(el.attributes['height'] ?? '');
        if ((width != null && width <= 2) || (height != null && height <= 2)) {
          return '';
        }
        final src = el.attributes['src'] ?? '';
        final alt = escape(el.attributes['alt'] ?? 'Inline image');
        final cid = src.toLowerCase().startsWith('cid:')
            ? normalizeCid(src.substring(4))
            : '';
        if (cid.isNotEmpty && contentIds.contains(cid)) {
          return '![$alt](email-cid:${Uri.encodeComponent(cid)})';
        }
        return alt == 'Inline image' ? '' : alt;
      }
      if (tag == 'table' &&
          (el!.querySelector('table') != null ||
              el.attributes['role'] == 'presentation' ||
              el.querySelector('td p,td pre,td div,td table') != null)) {
        return '\n\n${node.nodes.map((n) => visit(n, depth + 1, flow: true)).join()}\n\n';
      }
      if (tag == 'pre') {
        final text = node.text ?? '';
        var fence = '```';
        while (text.contains(fence)) {
          fence += '`';
        }
        return '\n\n$fence\n$text\n$fence\n\n';
      }
      final parts = node.nodes
          .map((n) => visit(n, depth + 1, flow: flow))
          .toList();
      final children = parts.join();
      if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
        return '\n\n${'#' * int.parse(tag[1])} ${children.trim()}\n\n';
      }
      switch (tag) {
        case 'br':
          return '\n';
        case 'hr':
          return '\n\n---\n\n';
        case 'p':
        case 'div':
        case 'section':
        case 'article':
          return '\n\n${children.trim()}\n\n';
        case 'table':
          if (flow) return '\n\n$children\n\n';
          final rows = children
              .trim()
              .split('\n')
              .where((r) => r.trim().startsWith('|'))
              .toList();
          if (rows.isEmpty) return '\n\n$children\n\n';
          final columns =
              el
                  ?.querySelector('tr')
                  ?.children
                  .where((e) => {'td', 'th'}.contains(e.localName))
                  .length ??
              1;
          rows.insert(1, '| ${List.filled(columns, '---').join(' | ')} |');
          return '\n\n${rows.join('\n')}\n\n';
        case 'strong':
        case 'b':
          return '**${children.trim()}**';
        case 'em':
        case 'i':
          return '*${children.trim()}*';
        case 'code':
          return '`$children`';
        case 'blockquote':
          return '\n\n${children.trim().split('\n').map((l) => '> $l').join('\n')}\n\n';
        case 'ul':
        case 'ol':
          return '\n${children.trim()}\n';
        case 'li':
          final ordered = el?.parent?.localName == 'ol';
          return '\n${ordered ? '1.' : '-'} ${children.trim().replaceAll('\n', '\n  ')}';
        case 'tr':
          if (flow) return '\n\n$children\n\n';
          final cells = <String>[];
          for (var i = 0; i < node.nodes.length; i++) {
            final child = node.nodes[i];
            if (child is Element && {'td', 'th'}.contains(child.localName)) {
              cells.add(parts[i].trim());
            }
          }
          return '\n| ${cells.join(' | ')} |';
        case 'td':
        case 'th':
          return flow ? '\n\n$children\n\n' : children.replaceAll('\n', ' ');
        case 'a':
          final href = el?.attributes['href'] ?? '';
          final uri = Uri.tryParse(href);
          if (uri != null &&
              {'https', 'http', 'mailto'}.contains(uri.scheme.toLowerCase()) &&
              (uri.scheme == 'mailto'
                  ? uri.path.isNotEmpty
                  : uri.host.isNotEmpty) &&
              !href.contains(RegExp(r'[\x00-\x20]'))) {
            final safe = href
                .replaceAll('(', '%28')
                .replaceAll(')', '%29')
                .replaceAll('<', '%3C')
                .replaceAll('>', '%3E');
            return '[$children]($safe)';
          }
          return children;
        default:
          return children;
      }
    }

    return visit(root, 0)
        .replaceAll(RegExp(r'\n[ \t]+\n'), '\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String normalizeCid(String value) {
    try {
      value = Uri.decodeComponent(value);
    } catch (_) {
      return '';
    }
    value = value.trim().replaceAll(RegExp(r'^<|>$'), '').toLowerCase();
    return value.length <= 998 && !value.contains(RegExp(r'[\x00-\x20<>]'))
        ? value
        : '';
  }
}
