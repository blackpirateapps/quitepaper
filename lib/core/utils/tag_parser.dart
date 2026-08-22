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

  /// Removes all occurrences of a tag from text, including YAML frontmatter
  /// and markdown hashtags (#tag), while preserving code blocks.
  static String removeTagFromText(String text, String tag) {
    final cleanTag = normalizeTag(tag);
    if (cleanTag.isEmpty || text.isEmpty) return text;

    // 1. Handle YAML frontmatter if present
    if (text.startsWith('---')) {
      final endMatch =
          RegExp(r'\r?\n(---|\.\.\.)(\r?\n|$)').firstMatch(text.substring(3));
      if (endMatch != null) {
        final frontmatterEnd = 3 + endMatch.start + endMatch.group(0)!.length;
        final frontmatterBlock = text.substring(0, frontmatterEnd);
        final restOfText = text.substring(frontmatterEnd);

        final cleanedFrontmatter =
            _removeTagFromFrontmatter(frontmatterBlock, cleanTag);
        final cleanedRest = removeTagFromText(restOfText, cleanTag);
        return '$cleanedFrontmatter$cleanedRest';
      }
    }

    // 2. Process text line-by-line, preserving code blocks
    final lines = text.split('\n');
    final processedLines = <String>[];
    var inFencedCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFencedCodeBlock = !inFencedCodeBlock;
        processedLines.add(line);
        continue;
      }

      if (inFencedCodeBlock) {
        processedLines.add(line);
        continue;
      }

      // If line contains inline backticks, process only non-code parts
      if (line.contains('`')) {
        processedLines.add(_removeTagFromLineWithInlineCode(line, cleanTag));
      } else {
        processedLines.add(_removeTagFromLine(line, cleanTag));
      }
    }

    // Collapse orphan blank lines caused by removing standalone tags
    return _collapseEmptyLines(processedLines, text);
  }

  static String _removeTagFromFrontmatter(
      String frontmatter, String cleanTag) {
    final lines = frontmatter.split(RegExp(r'\r?\n'));
    final resultLines = <String>[];
    String? currentListKey;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // List item under a tag key (e.g., "  - work", "  - 'work'", '  - "work"')
      if (trimmed.startsWith('- ') &&
          currentListKey != null &&
          _isTagKey(currentListKey)) {
        final itemVal = _stripQuotes(trimmed.substring(2).trim()).toLowerCase();
        final normalizedItem = normalizeTag(itemVal);
        if (normalizedItem == cleanTag) {
          // Omit this tag line from the list
          continue;
        }
        resultLines.add(line);
        continue;
      }

      // Check key: value
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final rawKey = line.substring(0, colonIndex).trim();
        final key =
            rawKey.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
        final val = line.substring(colonIndex + 1).trim();

        if (_isTagKey(key)) {
          currentListKey = key;
          if (val.isEmpty || val == '|' || val == '>') {
            resultLines.add(line);
            continue;
          }

          // Inline array: tags: [work, urgent]
          if (val.startsWith('[') && val.endsWith(']')) {
            final inner = val.substring(1, val.length - 1).trim();
            if (inner.isEmpty) {
              resultLines.add(line);
              continue;
            }
            final items = inner.split(',').map((e) => e.trim()).toList();
            final remaining = items.where((item) {
              final raw = _stripQuotes(item).toLowerCase();
              return normalizeTag(raw) != cleanTag;
            }).toList();

            final prefix = line.substring(0, colonIndex + 1);
            resultLines.add('$prefix [${remaining.join(', ')}]');
            continue;
          }

          // Comma-separated: tags: work, urgent
          if (val.contains(',')) {
            final items = val.split(',').map((e) => e.trim()).toList();
            final remaining = items.where((item) {
              final raw = _stripQuotes(item).toLowerCase();
              return normalizeTag(raw) != cleanTag;
            }).toList();

            final prefix = line.substring(0, colonIndex + 1);
            resultLines.add('$prefix [${remaining.join(', ')}]');
            continue;
          }

          // Single scalar: tags: work or tag: work
          final scalar = normalizeTag(_stripQuotes(val));
          if (scalar == cleanTag) {
            final prefix = line.substring(0, colonIndex + 1);
            resultLines.add('$prefix []');
            continue;
          }
        } else {
          currentListKey = null;
        }
      } else if (!trimmed.startsWith('- ')) {
        currentListKey = null;
      }

      resultLines.add(line);
    }

    return resultLines.join('\n');
  }

  static bool _isTagKey(String key) {
    final k = key.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    return k == 'tags' || k == 'tag' || k == 'categories' || k == 'category';
  }

  static String _stripQuotes(String input) {
    var str = input.trim();
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      if (str.length >= 2) {
        str = str.substring(1, str.length - 1).trim();
      }
    }
    return str;
  }

  static String _removeTagFromLine(String line, String cleanTag) {
    if (!line.contains('#') || cleanTag.isEmpty) return line;

    final escaped = RegExp.escape(cleanTag);

    // 1. If entire line is just the tag (with optional leading/trailing whitespace)
    if (RegExp('^\\s*#$escaped\\s*\$', caseSensitive: false).hasMatch(line)) {
      return '';
    }

    var result = line;

    // 2. Tag preceded by space and followed by space (middle of sentence)
    result = result.replaceAll(
      RegExp('\\s+#$escaped(?=\\s)', caseSensitive: false),
      '',
    );

    // 3. Tag preceded by space and followed by punctuation or end of line
    result = result.replaceAll(
      RegExp('\\s+#$escaped(?=[.,!?:;)\\]}>"\']|\$)', caseSensitive: false),
      '',
    );

    // 4. Tag at start of line followed by space
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)#' '$escaped' r'\s+', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );

    // 5. Any remaining isolated #tag (e.g., inside brackets `(#tag)` or quotes `"#tag"`)
    result = result.replaceAll(
      RegExp('(?<=^|[\\s(\\[{<"\'`])#$escaped(?=[)\\]},.!?\\s>"\'`:]|\$)',
          caseSensitive: false),
      '',
    );

    return result;
  }

  static String _removeTagFromLineWithInlineCode(
      String line, String cleanTag) {
    final buffer = StringBuffer();
    var currentIndex = 0;
    final codeSpanRegex = RegExp(r'`[^`\n]*`');

    for (final match in codeSpanRegex.allMatches(line)) {
      if (match.start > currentIndex) {
        final plainSegment = line.substring(currentIndex, match.start);
        buffer.write(_removeTagFromLine(plainSegment, cleanTag));
      }
      buffer.write(match.group(0));
      currentIndex = match.end;
    }

    if (currentIndex < line.length) {
      final plainSegment = line.substring(currentIndex);
      buffer.write(_removeTagFromLine(plainSegment, cleanTag));
    }

    return buffer.toString();
  }

  static String _collapseEmptyLines(
      List<String> lines, String originalText) {
    if (lines.every((l) => l.trim().isEmpty) &&
        originalText.trim().isNotEmpty) {
      return '';
    }

    final origLines = originalText.split('\n');
    final result = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty &&
          i < origLines.length &&
          origLines[i].trim().isNotEmpty) {
        continue;
      }
      result.add(line);
    }
    return result.join('\n');
  }
}
