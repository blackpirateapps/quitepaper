import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import '../domain/email_message.dart';

/// This converter has no network or widget dependencies. Only CID placeholders
/// can become images; remote/data/file images never enter Markdown image syntax.
class EmailHtmlConverter {
  static String escape(String value) =>
      value.replaceAllMapped(RegExp(r'[\\`*_{\}\[\]<>!|]'), (m) => '\\${m[0]}');

  static String plainText(String value) => value
      .split('\n')
      .map((line) {
        // Keep ordinary reply and list structure while escaping inline markup.
        final match = RegExp(
          r'^(\s*(?:>\s*)*(?:(?:[-+*]|\d+[.)])\s+)?)(.*)$',
        ).firstMatch(line)!;
        return '${match[1]}${escape(match[2]!)}';
      })
      .join('\n');

  String convert(String source, {Set<String> contentIds = const {}}) {
    final root = html.parseFragment(source);
    var nodes = 0;
    String visit(Node node, int depth) {
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
      if (tag == 'pre') {
        final text = node.text ?? '';
        var fence = '```';
        while (text.contains(fence)) {
          fence += '`';
        }
        return '\n\n$fence\n$text\n$fence\n\n';
      }
      final children = node.nodes.map((n) => visit(n, depth + 1)).join();
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
          return '\n| ${node.nodes.whereType<Element>().where((e) => {'td', 'th'}.contains(e.localName)).map((e) => visit(e, depth + 1).trim()).join(' | ')} |';
        case 'td':
        case 'th':
          return children.replaceAll('\n', ' ');
        case 'a':
          final href = el?.attributes['href'] ?? '';
          final uri = Uri.tryParse(href);
          if (uri != null &&
              {'https', 'http', 'mailto'}.contains(uri.scheme.toLowerCase()) &&
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
