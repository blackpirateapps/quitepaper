import '../../../core/utils/tag_parser.dart';

class ParsedMarkdown {
  const ParsedMarkdown({
    this.title,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
    required this.body,
  });

  final String? title;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String body;
}

abstract final class MarkdownFrontmatterParser {
  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Parses markdown text, extracting YAML frontmatter metadata and body content.
  static ParsedMarkdown parse(String rawContent) {
    if (rawContent.isEmpty) {
      return const ParsedMarkdown(body: '');
    }

    final match = _frontmatterRegex.firstMatch(rawContent);
    if (match == null) {
      return ParsedMarkdown(body: rawContent.trim());
    }

    final frontmatterBlock = match.group(1) ?? '';
    final body = rawContent.substring(match.end).trim();

    String? title;
    final tags = <String>{};
    DateTime? createdAt;
    DateTime? updatedAt;

    final lines = frontmatterBlock.split(RegExp(r'\r?\n'));
    String? currentListKey;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      // Handle multiline YAML lists (e.g. "  - item")
      if (trimmed.startsWith('- ') && currentListKey != null) {
        final itemValue = _stripQuotes(trimmed.substring(2).trim());
        if (currentListKey == 'tags' || currentListKey == 'tag' || currentListKey == 'categories' || currentListKey == 'category') {
          final normalized = _sanitizeTag(itemValue);
          if (TagParser.isValidTag(normalized)) {
            tags.add(normalized);
          }
        }
        continue;
      }

      // Check key: value
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) {
        continue;
      }

      final key = trimmed.substring(0, colonIndex).trim().toLowerCase();
      final val = trimmed.substring(colonIndex + 1).trim();

      if (val.isEmpty) {
        currentListKey = key;
        continue;
      } else {
        currentListKey = null;
      }

      final cleanVal = _stripQuotes(val);

      if (key == 'title') {
        if (cleanVal.isNotEmpty) {
          title = cleanVal;
        }
      } else if (key == 'tags' || key == 'tag' || key == 'categories' || key == 'category') {
        final parsedTags = _parseTagsValue(val);
        tags.addAll(parsedTags);
      } else if (key == 'date' || key == 'created' || key == 'created_at' || key == 'createdat') {
        final dt = _parseDateTime(cleanVal);
        if (dt != null) {
          createdAt = dt;
        }
      } else if (key == 'updated' || key == 'updated_at' || key == 'updatedat' || key == 'modified' || key == 'modified_at') {
        final dt = _parseDateTime(cleanVal);
        if (dt != null) {
          updatedAt = dt;
        }
      }
    }

    return ParsedMarkdown(
      title: title,
      tags: tags.toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      body: body,
    );
  }

  static List<String> _parseTagsValue(String val) {
    final result = <String>[];
    var trimmed = val.trim();

    // Check for inline array: [tag1, tag2, "tag 3"]
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }

    // Split by comma
    final parts = trimmed.split(',');
    for (final part in parts) {
      final clean = _stripQuotes(part.trim());
      if (clean.isNotEmpty) {
        final normalized = _sanitizeTag(clean);
        if (TagParser.isValidTag(normalized)) {
          result.add(normalized);
        }
      }
    }

    return result;
  }

  static String _stripQuotes(String s) {
    var str = s.trim();
    if ((str.startsWith('"') && str.endsWith('"')) ||
        (str.startsWith("'") && str.endsWith("'"))) {
      if (str.length >= 2) {
        str = str.substring(1, str.length - 1);
      }
    }
    return str.trim();
  }

  static String _sanitizeTag(String input) {
    var tag = TagParser.normalizeTag(input);
    // Replace internal spaces with hyphens
    tag = tag.replaceAll(RegExp(r'\s+'), '-');
    return tag;
  }

  static DateTime? _parseDateTime(String dateStr) {
    if (dateStr.isEmpty) return null;
    final tryIso = DateTime.tryParse(dateStr);
    if (tryIso != null) return tryIso;

    // Try slash format: YYYY/MM/DD or YYYY/MM/DD HH:mm:ss
    final slashFormatted = dateStr.replaceAll('/', '-');
    final trySlash = DateTime.tryParse(slashFormatted);
    if (trySlash != null) return trySlash;

    return null;
  }
}
