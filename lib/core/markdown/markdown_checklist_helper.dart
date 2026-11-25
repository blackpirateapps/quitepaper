import '../../features/editor/domain/task_metadata.dart';

/// Helper utility for parsing, counting, toggling, and formatting Markdown checklist items.
/// Accurately ignores checklist syntax inside fenced code blocks and preserves YAML frontmatter.
class MarkdownTaskOccurrence {
  const MarkdownTaskOccurrence({
    required this.ordinal,
    required this.start,
    required this.end,
    required this.checkOffset,
    required this.text,
    required this.completed,
    this.heading,
    this.continuation = const [],
  });
  final int ordinal, start, end, checkOffset;
  final String text;
  final bool completed;
  final String? heading;
  final List<String> continuation;
}

abstract final class MarkdownChecklistHelper {
  /// Shared structural scan for source offsets. Preserves every source byte.
  /// Recognizes nested/quoted/ordered checkboxes, excludes frontmatter, fenced
  /// and indented literal blocks, and HTML blocks/comments.
  static List<MarkdownTaskOccurrence> occurrences(String markdown) {
    final result = <MarkdownTaskOccurrence>[];
    final frontmatter = _frontmatterRegex.firstMatch(markdown);
    var fenceChar = '';
    var fenceLength = 0;
    var html = false;
    String? htmlEnd;
    var listIndent = -1;
    String? heading;
    for (final physical in RegExp(r'[^\n]*(?:\n|$)').allMatches(markdown)) {
      if (physical.start == physical.end) continue;
      if (physical.start < (frontmatter?.end ?? 0)) continue;
      var line = physical[0]!.replaceFirst(RegExp(r'\r?\n$'), '');
      final quote = RegExp(r'^[ \t]*(?:>[ \t]*)+').firstMatch(line);
      final structural = quote == null ? line : line.substring(quote.end);
      final trimmed = structural.trimLeft();
      final fence = RegExp(r'^(`{3,}|~{3,})(.*)$').firstMatch(trimmed);
      if (fenceLength > 0) {
        if (fence != null &&
            fence[1]![0] == fenceChar &&
            fence[1]!.length >= fenceLength &&
            fence[2]!.trim().isEmpty) {
          fenceLength = 0;
        }
        continue;
      }
      if (fence != null) {
        fenceChar = fence[1]![0];
        fenceLength = fence[1]!.length;
        continue;
      }
      if (html) {
        if (htmlEnd == null ? trimmed.isEmpty : trimmed.toLowerCase().contains(htmlEnd)) { html = false; htmlEnd = null; }
        continue;
      }
      if (trimmed.startsWith('<!--')) {
        html = !trimmed.contains('-->');
        htmlEnd = html ? '-->' : null;
        continue;
      }
      if (RegExp(
        r'^<(pre|script|style|textarea|div|table|section|details|summary|p|article|aside|blockquote|ul|ol|li|dl|dt|dd|figure|header|footer|main|nav|form|h[1-6])(?:[ >])',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        final tag = RegExp(r'^<([a-z0-9]+)',caseSensitive:false).firstMatch(trimmed)![1]!.toLowerCase();
        htmlEnd = ['pre','script','style','textarea'].contains(tag) ? '</$tag>' : null;
        html = htmlEnd == null || !trimmed.toLowerCase().contains(htmlEnd);
        continue;
      }
      final indent = structural.length - trimmed.length;
      final match = _checklistLineRegex.firstMatch(line);
      if (match != null && !(indent >= 4 && listIndent < 0)) {
        listIndent = indent;
        final textStart = match.group(1)!.length + 2;
        result.add(
          MarkdownTaskOccurrence(
            ordinal: result.length,
            start: physical.start,
            end: physical.start + line.length,
            checkOffset: physical.start + match.group(1)!.length,
            text: line.substring(textStart).trimLeft(),
            completed: match[2]!.toLowerCase() == 'x',
            heading: heading,
            continuation: <String>[],
          ),
        );
      } else if (trimmed.isNotEmpty && result.isNotEmpty && listIndent >= 0 && indent > listIndent) {
        result.last.continuation.add(trimmed);
      } else if (trimmed.isNotEmpty && indent == 0) {
        listIndent = RegExp(r'^(?:[-*+]|\d+[.)])\s+').hasMatch(trimmed)
            ? 0
            : -1;
        final h = RegExp(r'^#{1,6}\s+(.+?)(?:\s+#+)?$').firstMatch(trimmed);
        if (h != null) heading = h[1];
      }
    }
    return result;
  }

  static final RegExp _checklistLineRegex = RegExp(
    r'^([ \t]*(?:>[ \t]*)*(?:[-*+]|\d+[.)])[ \t]+\[)([ xX])(\](?:[ \t]+.*)?)$',
  );

  static final RegExp _checkedItemRegex = RegExp(
    r'^([ \t]*(?:>[ \t]*)*(?:[-*+]|\d+[.)])[ \t]+\[[xX]\][ \t]+)(.+)$',
  );

  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Counts the total number of checklist items in [markdown], skipping code fences.
  static int countChecklistItems(String markdown) {
    return occurrences(markdown).length;
  }

  /// Toggles the checklist item at [targetIndex] (0-based) in [markdown].
  ///
  /// Preserves YAML frontmatter without modification, respects code fences,
  /// and flips `' '` -> `'x'` or `'x'`/`'X'` -> `' '`.
  /// Returns original [markdown] if [targetIndex] is out of range.
  static String toggleChecklistItem(String markdown, int targetIndex) {
    final items = occurrences(markdown);
    if (targetIndex < 0 || targetIndex >= items.length) return markdown;
    final item = items[targetIndex];
    return markdown.replaceRange(
      item.checkOffset,
      item.checkOffset + 1,
      item.completed ? ' ' : 'x',
    );
  }

  static String withoutTaskMetadata(String markdown) {
    var result = markdown;
    for (final item in occurrences(markdown).reversed) {
      final line = markdown.substring(item.start, item.end);
      final parsed = TaskMetadata.parseTerminal(line);
      if (parsed.metadata != null) {
        result = result.replaceRange(item.start, item.end, parsed.text);
      }
    }
    return result;
  }

  /// Prepares Markdown for preview rendering by applying strikethrough styling
  /// to completed checklist items (`- [x]`, `* [x]`, `+ [x]`, `1. [x]`).
  ///
  /// This transformation is strictly visual and does not alter canonical note storage.
  static String preparePreviewMarkdown(
    String markdown, {
    bool applyCompletedStrikethrough = true,
  }) {
    markdown = withoutTaskMetadata(markdown);
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
