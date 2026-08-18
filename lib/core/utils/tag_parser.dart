abstract final class TagParser {
  /// Regular expression to match hashtags without catastrophic backtracking.
  /// Matches `#tag`, `#nested/tag`, `#tag_1`, `#tag-name`.
  /// Ensures it does NOT match Markdown headers (which have space after `#`).
  static final RegExp _tagRegex = RegExp(
    r'''(?:^|[\s(\[{<"'`])#([a-zA-Z0-9_\-/]+)(?=[)\],.!?\s>"'`:]|$)''',
    multiLine: true,
  );

  /// Extracts unique normalized tag names from markdown text.
  static List<String> extractTags(String text) {
    if (text.isEmpty || !text.contains('#')) return const [];

    final cleanText = _stripCodeBlocks(text);
    final matches = _tagRegex.allMatches(cleanText);
    final tags = <String>{};

    for (final match in matches) {
      final rawTag = match.group(1);
      if (rawTag != null) {
        final normalized = normalizeTag(rawTag);
        if (isValidTag(normalized)) {
          tags.add(normalized);
        }
      }
    }

    final sorted = tags.toList()..sort();
    return sorted;
  }

  /// Fast line-by-line strip of code blocks and inline code without regex backtracking
  static String _stripCodeBlocks(String text) {
    if (!text.contains('`')) return text;

    final buffer = StringBuffer();
    final lines = text.split('\n');
    var inCodeBlock = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      if (line.contains('`')) {
        // Strip inline backticks cleanly
        final strippedLine = line.replaceAll(RegExp(r'`[^`\n]*`'), ' ');
        buffer.writeln(strippedLine);
      } else {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  /// Normalizes a tag string: strips leading `#`, trims whitespace, converts to lowercase.
  static String normalizeTag(String input) {
    var tag = input.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1).trim();
    }
    return tag.toLowerCase();
  }

  /// Validates whether a normalized tag string contains valid characters and is non-empty.
  static bool isValidTag(String normalizedTag) {
    if (normalizedTag.isEmpty) return false;
    // Cannot be purely numeric
    if (int.tryParse(normalizedTag) != null) return false;
    // Cannot start or end with slash/dash/underscore
    if (normalizedTag.startsWith('/') ||
        normalizedTag.endsWith('/') ||
        normalizedTag.startsWith('-') ||
        normalizedTag.endsWith('-') ||
        normalizedTag.startsWith('_') ||
        normalizedTag.endsWith('_')) {
      return false;
    }
    // Tag should only contain alphanumeric, dash, underscore, and slash
    return RegExp(r'^[a-z0-9_\-/]+$').hasMatch(normalizedTag);
  }

  /// Displays tag with leading `#`.
  static String formatDisplay(String tag) {
    final clean = normalizeTag(tag);
    return '#$clean';
  }
}
