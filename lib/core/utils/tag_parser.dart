abstract final class TagParser {
  /// Regular expression to match hashtags.
  /// Matches `#tag`, `#nested/tag`, `#tag_1`, `#tag-name`.
  /// Ensures it does NOT match Markdown headers (e.g. `# Header` has space) or inside code blocks/URLs.
  /// Must be preceded by start of line, whitespace, or opening punctuation (like `(`, `[`, `{`).
  static final RegExp _tagRegex = RegExp(
    r'(?:^|[\s(\[{])#([a-zA-Z0-9_\-/]+)(?=[)\],.!?\s]|$)',
    multiLine: true,
  );

  /// Extracts unique normalized tag names from markdown text.
  static List<String> extractTags(String text) {
    if (text.isEmpty) return const [];

    // Filter out code blocks before extracting tags
    final textWithoutCodeBlocks = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    final textWithoutInlineCode = textWithoutCodeBlocks.replaceAll(RegExp(r'`[^`]*`'), '');

    final matches = _tagRegex.allMatches(textWithoutInlineCode);
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
