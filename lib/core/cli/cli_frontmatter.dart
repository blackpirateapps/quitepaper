/// Pure Dart YAML frontmatter parser and updater for Quiet Paper CLI.
///
/// Intentionally contains ZERO imports of `package:flutter` or `dart:ui` so the
/// native CLI binary runs anywhere without UI subsystem overhead.
class CliFrontmatter {
  const CliFrontmatter({
    required this.hasFrontmatter,
    this.title,
    this.isJournal = false,
    this.journalDate,
    this.tags = const [],
    required this.contentBody,
  });

  final bool hasFrontmatter;
  final String? title;
  final bool isJournal;
  final String? journalDate;
  final List<String> tags;
  final String contentBody;

  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Parses YAML frontmatter from raw Markdown text.
  static CliFrontmatter parse(String rawContent) {
    if (rawContent.isEmpty) {
      return const CliFrontmatter(
        hasFrontmatter: false,
        contentBody: '',
      );
    }

    final match = _frontmatterRegex.firstMatch(rawContent);
    if (match == null) {
      return CliFrontmatter(
        hasFrontmatter: false,
        contentBody: rawContent,
      );
    }

    final blockText = match.group(1) ?? '';
    final body = rawContent.substring(match.end);

    String? parsedTitle;
    bool isJournal = false;
    String? journalDate;
    final parsedTags = <String>{};

    final lines = blockText.split(RegExp(r'\r?\n'));
    String? currentListKey;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Multiline YAML list items (e.g. "  - journal/2026")
      if (trimmed.startsWith('- ') && currentListKey != null) {
        final itemVal = _stripQuotes(trimmed.substring(2).trim());
        if (currentListKey == 'tags' || currentListKey == 'tag') {
          if (itemVal.isNotEmpty) parsedTags.add(itemVal);
        }
        continue;
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;

      final rawKey = line.substring(0, colonIndex).trim();
      final key = rawKey.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      final rawVal = line.substring(colonIndex + 1).trim();

      currentListKey = null;

      if (rawVal.isEmpty || rawVal == '|' || rawVal == '>') {
        currentListKey = key;
        continue;
      }

      final cleanVal = _stripQuotes(rawVal);

      if (key == 'title') {
        if (cleanVal.isNotEmpty) parsedTitle = cleanVal;
      } else if (key == 'journal') {
        final lower = cleanVal.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') {
          isJournal = true;
        }
      } else if (key == 'date') {
        if (cleanVal.isNotEmpty) journalDate = cleanVal;
      } else if (key == 'tags' || key == 'tag') {
        if (cleanVal.startsWith('[') && cleanVal.endsWith(']')) {
          final items = cleanVal
              .substring(1, cleanVal.length - 1)
              .split(',')
              .map((s) => _stripQuotes(s.trim()))
              .where((s) => s.isNotEmpty);
          parsedTags.addAll(items);
        } else if (cleanVal.isNotEmpty) {
          parsedTags.add(cleanVal);
        }
      }
    }

    return CliFrontmatter(
      hasFrontmatter: true,
      title: parsedTitle,
      isJournal: isJournal,
      journalDate: journalDate,
      tags: parsedTags.toList()..sort(),
      contentBody: body,
    );
  }

  /// Injects or updates the `title:` field in YAML frontmatter.
  /// If [documentText] has no frontmatter, it is returned unmodified.
  static String updateTitle({
    required String documentText,
    required String newTitle,
  }) {
    final match = _frontmatterRegex.firstMatch(documentText);
    if (match == null) return documentText;

    final blockText = match.group(1) ?? '';
    final remainder = documentText.substring(match.end);
    final safeTitle = newTitle.contains(':') || newTitle.contains('#')
        ? '"${newTitle.replaceAll('"', r'\"')}"'
        : newTitle;

    // Check if title: is already in blockText
    final titleRegex = RegExp(r'^(\s*title\s*:\s*)(.*)$', multiLine: true, caseSensitive: false);
    final titleMatch = titleRegex.firstMatch(blockText);

    if (titleMatch != null) {
      final updatedBlock = blockText.replaceRange(
        titleMatch.start,
        titleMatch.end,
        'title: $safeTitle',
      );
      return '---\n$updatedBlock\n---\n$remainder';
    } else {
      // Prepend title: to frontmatter block
      return '---\ntitle: $safeTitle\n$blockText\n---\n$remainder';
    }
  }

  static String _stripQuotes(String value) {
    var v = value.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      if (v.length >= 2) {
        v = v.substring(1, v.length - 1).trim();
      }
    }
    return v;
  }
}
