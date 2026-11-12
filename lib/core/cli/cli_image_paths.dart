import 'package:markdown/markdown.dart' as md;

/// Locates inline image destinations without changing surrounding Markdown.
/// The Markdown parser validates syntax; code, frontmatter and escaped examples
/// are masked before scanning. Reference-style images are handled via definitions.
class CliImagePath {
  const CliImagePath(this.start, this.end, this.target);
  final int start;
  final int end;
  final String target;

  static List<CliImagePath> find(String source) {
    var masked = source;
    String blank(Match m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' ');
    masked = masked.replaceAllMapped(
      RegExp(r'^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)'),
      blank,
    );
    // Fence lengths and inline backtick runs must match their closing delimiter.
    final lines = masked.split('\n');
    String? fence;
    var fenceLength = 0;
    for (var i = 0; i < lines.length; i++) {
      final match = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(lines[i]);
      if (fence != null) {
        final closes = RegExp(
          '^ {0,3}${RegExp.escape(fence)}{$fenceLength,}\\s*\$',
        ).hasMatch(lines[i]);
        lines[i] = ' ' * lines[i].length;
        if (closes) fence = null;
      } else if (match != null) {
        fence = match[1]![0];
        fenceLength = match[1]!.length;
        lines[i] = ' ' * lines[i].length;
      } else if (lines[i].startsWith('    ') || lines[i].startsWith('\t')) {
        lines[i] = ' ' * lines[i].length;
      }
    }
    masked = lines
        .join('\n')
        .replaceAllMapped(RegExp(r'(`+)([\s\S]*?)\1(?!`)'), blank)
        .replaceAllMapped(RegExp(r'<!--[\s\S]*?-->'), blank);
    final result = <CliImagePath>[];
    final image = RegExp(r'!\[(?:\\.|[^\]\\])*\]\(');
    for (final match in image.allMatches(masked)) {
      var slashCount = 0;
      for (var j = match.start - 1; j >= 0 && source[j] == '\\'; j--) {
        slashCount++;
      }
      if (slashCount.isOdd) continue;
      var start = match.end;
      while (start < masked.length && RegExp(r'\s').hasMatch(masked[start])) {
        start++;
      }
      if (start >= masked.length) continue;
      var end = start;
      if (masked[start] == '<') {
        start++;
        end = masked.indexOf('>', start);
        if (end < 0) continue;
      } else {
        var depth = 0;
        while (end < masked.length) {
          final c = masked[end];
          if (c == '\\' && end + 1 < masked.length) {
            end += 2;
            continue;
          }
          if (c == '(') depth++;
          if (c == ')' && depth == 0) break;
          if (c == ')') depth--;
          if (RegExp(r'\s').hasMatch(c)) break;
          end++;
        }
      }
      final tail = masked.indexOf(')', end);
      if (tail < 0) continue;
      final snippet = source.substring(match.start, tail + 1);
      if (!md.markdownToHtml(snippet).contains('<img ')) continue;
      final target = source
          .substring(start, end)
          .replaceAllMapped(
            RegExp(r'\\([!"#$%&\x27()*+,\-./:;<=>?@\[\]\\^_`{|}~])'),
            (m) => m[1]!,
          );
      if (isLocal(target)) result.add(CliImagePath(start, end, target));
    }
    // Reference definitions are only imported when an image actually uses them.
    final document = md.Document();
    final nodes = document.parseLines(source.split('\n'));
    final targets = <String>{};
    void visit(md.Node node) {
      if (node is md.Element) {
        if (node.tag == 'img' && node.attributes['src'] != null) {
          targets.add(node.attributes['src']!);
        }
        for (final child in node.children ?? <md.Node>[]) {
          visit(child);
        }
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    final definition = RegExp(
      r'^ {0,3}\[[^\]]+\]:\s*(?:<([^>]+)>|(\S+))',
      multiLine: true,
    );
    for (final m in definition.allMatches(masked)) {
      final target = m[1] ?? m[2]!;
      if (!isLocal(target) || !targets.contains(target)) continue;
      final start = m.start + m[0]!.indexOf(target, m[0]!.indexOf(']:') + 2);
      result.add(CliImagePath(start, start + target.length, target));
    }
    return result..sort((a, b) => a.start.compareTo(b.start));
  }

  static bool isLocal(String target) {
    if (target.isEmpty || target.startsWith('//') || target.startsWith('#')) {
      return false;
    }
    final uri = Uri.tryParse(target);
    return uri != null && (!uri.hasScheme || uri.scheme == 'file');
  }
}
