import 'package:intl/intl.dart';
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

  /// Parses markdown text, extracting YAML frontmatter metadata.
  /// Note: The original full [rawContent] is preserved in [ParsedMarkdown.body].
  static ParsedMarkdown parse(String rawContent) {
    if (rawContent.isEmpty) {
      return const ParsedMarkdown(body: '');
    }

    final match = _frontmatterRegex.firstMatch(rawContent);
    if (match == null) {
      return ParsedMarkdown(body: rawContent);
    }

    final frontmatterBlock = match.group(1) ?? '';

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
        if (_isTagKey(currentListKey)) {
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

      final key = trimmed.substring(0, colonIndex).trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
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
      } else if (_isTagKey(key)) {
        final parsedTags = _parseTagsValue(val);
        tags.addAll(parsedTags);
      } else if (_isCreatedDateKey(key)) {
        final dt = _parseDateTime(cleanVal);
        if (dt != null) {
          createdAt = dt;
        }
      } else if (_isUpdatedDateKey(key)) {
        final dt = _parseDateTime(cleanVal);
        if (dt != null) {
          updatedAt = dt;
        }
      }
    }

    // If only createdAt was set, default updatedAt to createdAt
    if (createdAt != null && updatedAt == null) {
      updatedAt = createdAt;
    } else if (updatedAt != null && createdAt == null) {
      createdAt = updatedAt;
    }

    return ParsedMarkdown(
      title: title,
      tags: tags.toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      body: rawContent, // Preserve full content as-is (do not strip frontmatter)
    );
  }

  static bool _isTagKey(String key) {
    return key == 'tags' ||
        key == 'tag' ||
        key == 'categories' ||
        key == 'category' ||
        key == 'keywords';
  }

  static bool _isCreatedDateKey(String key) {
    return key == 'date' ||
        key == 'created' ||
        key == 'created_at' ||
        key == 'createdat' ||
        key == 'created_date' ||
        key == 'createddate' ||
        key == 'creation_date' ||
        key == 'creationdate' ||
        key == 'publish_date' ||
        key == 'publishdate' ||
        key == 'pubdate';
  }

  static bool _isUpdatedDateKey(String key) {
    return key == 'updated' ||
        key == 'updated_at' ||
        key == 'updatedat' ||
        key == 'updated_date' ||
        key == 'updateddate' ||
        key == 'modified' ||
        key == 'modified_at' ||
        key == 'modifiedat' ||
        key == 'lastmod' ||
        key == 'last_modified' ||
        key == 'lastmodified';
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
    tag = tag.replaceAll(RegExp(r'\s+'), '-');
    return tag;
  }

  static DateTime? _parseDateTime(String input) {
    var dateStr = _stripQuotes(input.trim());
    if (dateStr.isEmpty) return null;

    // Check if it's a numeric timestamp (epoch seconds or millis)
    final numVal = int.tryParse(dateStr);
    if (numVal != null) {
      if (dateStr.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
      } else if (dateStr.length == 13) {
        return DateTime.fromMillisecondsSinceEpoch(numVal);
      }
    }

    // Try ISO8601 parsing directly
    final tryIso = DateTime.tryParse(dateStr);
    if (tryIso != null) return tryIso;

    // Try replacing '/' or '.' with '-'
    final normalized = dateStr.replaceAll('/', '-').replaceAll('.', '-');
    final tryNorm = DateTime.tryParse(normalized);
    if (tryNorm != null) return tryNorm;

    // Try common date patterns
    final datePatterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'MMMM d, yyyy',
      'MMM d, yyyy',
      'd MMMM yyyy',
      'd MMM yyyy',
    ];

    for (final pattern in datePatterns) {
      try {
        return DateFormat(pattern).parseLoose(dateStr);
      } catch (_) {}
    }

    return null;
  }
}
