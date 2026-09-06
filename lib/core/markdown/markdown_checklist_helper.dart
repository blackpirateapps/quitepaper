/// Helper utility for parsing, counting, toggling, and formatting Markdown checklist items.
/// Accurately ignores checklist syntax inside fenced code blocks and preserves YAML frontmatter.
abstract final class MarkdownChecklistHelper {
  static final RegExp _checklistLineRegex = RegExp(
    r'^([ \t]*(?:>[ \t]*)*(?:[-*+]|\d+\.)[ \t]+\[)([ xX])(\](?:[ \t]+.*)?)$',
  );

  static final RegExp _checkedItemRegex = RegExp(
    r'^([ \t]*(?:>[ \t]*)*(?:[-*+]|\d+\.)[ \t]+\[[xX]\][ \t]+)(.+)$',
  );

  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Counts the total number of checklist items in [markdown], skipping code fences.
  static int countChecklistItems(String markdown) {
    if (markdown.isEmpty) return 0;

    final lines = markdown.split(RegExp(r'\r?\n'));
    int count = 0;
    bool inCodeFence = false;
    String codeFenceMarker = '';

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final marker = trimmed.substring(0, 3);
        if (!inCodeFence) {
          inCodeFence = true;
          codeFenceMarker = marker;
          continue;
        } else if (trimmed.startsWith(codeFenceMarker)) {
          inCodeFence = false;
          codeFenceMarker = '';
          continue;
        }
      }

      if (inCodeFence) continue;

      if (_checklistLineRegex.hasMatch(line)) {
        count++;
      }
    }

    return count;
  }

  /// Toggles the checklist item at [targetIndex] (0-based) in [markdown].
  ///
  /// Preserves YAML frontmatter without modification, respects code fences,
  /// and flips `' '` -> `'x'` or `'x'`/`'X'` -> `' '`.
  /// Returns original [markdown] if [targetIndex] is out of range.
  static String toggleChecklistItem(String markdown, int targetIndex) {
    if (markdown.isEmpty || targetIndex < 0) {
      return markdown;
    }

    final frontmatterMatch = _frontmatterRegex.firstMatch(markdown);
    final int bodyStartOffset = frontmatterMatch?.end ?? 0;
    final String frontmatterPrefix = markdown.substring(0, bodyStartOffset);
    final String body = markdown.substring(bodyStartOffset);

    final lineSeparator = body.contains('\r\n') ? '\r\n' : '\n';
    final lines = body.split(RegExp(r'\r?\n'));

    int currentIndex = 0;
    bool inCodeFence = false;
    String codeFenceMarker = '';
    bool toggled = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final marker = trimmed.substring(0, 3);
        if (!inCodeFence) {
          inCodeFence = true;
          codeFenceMarker = marker;
          continue;
        } else if (trimmed.startsWith(codeFenceMarker)) {
          inCodeFence = false;
          codeFenceMarker = '';
          continue;
        }
      }

      if (inCodeFence) continue;

      final match = _checklistLineRegex.firstMatch(line);
      if (match != null) {
        if (currentIndex == targetIndex) {
          final prefix = match.group(1)!;
          final state = match.group(2)!;
          final suffix = match.group(3)!;

          final newState = (state == 'x' || state == 'X') ? ' ' : 'x';
          lines[i] = '$prefix$newState$suffix';
          toggled = true;
          break;
        }
        currentIndex++;
      }
    }

    if (!toggled) {
      return markdown;
    }

    return '$frontmatterPrefix${lines.join(lineSeparator)}';
  }

  /// Prepares Markdown for preview rendering by applying strikethrough styling
  /// to completed checklist items (`- [x]`, `* [x]`, `+ [x]`, `1. [x]`).
  ///
  /// This transformation is strictly visual and does not alter canonical note storage.
  static String preparePreviewMarkdown(
    String markdown, {
    bool applyCompletedStrikethrough = true,
  }) {
    if (!applyCompletedStrikethrough || markdown.isEmpty) {
      return markdown;
    }

    final lineSeparator = markdown.contains('\r\n') ? '\r\n' : '\n';
    final lines = markdown.split(RegExp(r'\r?\n'));

    bool inCodeFence = false;
    String codeFenceMarker = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final marker = trimmed.substring(0, 3);
        if (!inCodeFence) {
          inCodeFence = true;
          codeFenceMarker = marker;
          continue;
        } else if (trimmed.startsWith(codeFenceMarker)) {
          inCodeFence = false;
          codeFenceMarker = '';
          continue;
        }
      }

      if (inCodeFence) continue;

      final match = _checkedItemRegex.firstMatch(line);
      if (match != null) {
        final prefix = match.group(1)!;
        final rawContent = match.group(2)!;
        final trimmedContent = rawContent.trim();

        // Avoid double-wrapping or wrapping empty content
        if (trimmedContent.isEmpty ||
            (trimmedContent.startsWith('~~') && trimmedContent.endsWith('~~') && trimmedContent.length >= 4)) {
          continue;
        }

        // Preserve trailing whitespace for markdown line break semantics
        final endWhitespaceIdx = rawContent.length - (rawContent.length - rawContent.trimRight().length);
        final contentText = rawContent.substring(0, endWhitespaceIdx);
        final trailingSpace = rawContent.substring(endWhitespaceIdx);

        lines[i] = '$prefix~~$contentText~~$trailingSpace';
      }
    }

    return lines.join(lineSeparator);
  }
}
