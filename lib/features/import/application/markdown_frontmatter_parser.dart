import 'package:intl/intl.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import '../../../core/utils/tag_parser.dart';

class ParsedMarkdown {
  const ParsedMarkdown({
    this.title,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
    this.source,
    this.author,
    this.description,
    this.createdRaw,
    this.isJournal = false,
    this.journalDate,
    required this.body,
    this.contentBody = '',
    this.hasFrontmatter = false,
  });

  final String? title;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? source;
  final String? author;
  final String? description;
  final String? createdRaw;
  final bool isJournal;
  final String? journalDate;
  final String body; // Preserves full original raw content with frontmatter
  final String contentBody; // Content after frontmatter block
  final bool hasFrontmatter;

  /// Returns true if there are displayable metadata fields (author, source, created, description).
  bool get hasDisplayableMetadata {
    final hasStandard = (source != null && source!.trim().isNotEmpty) ||
        (author != null && author!.trim().isNotEmpty) ||
        (description != null && description!.trim().isNotEmpty);
    if (hasStandard) return true;
    if (isJournal) return false;
    return createdAt != null || (createdRaw != null && createdRaw!.trim().isNotEmpty);
  }
}

abstract final class MarkdownFrontmatterParser {
  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Parses markdown text, extracting YAML frontmatter metadata.
  /// Note: The original full [rawContent] is preserved in [ParsedMarkdown.body],
  /// while [ParsedMarkdown.contentBody] contains the body with the frontmatter block removed.
  static ParsedMarkdown parse(String rawContent) {
    if (rawContent.isEmpty) {
      return const ParsedMarkdown(body: '', contentBody: '', hasFrontmatter: false);
    }

    final match = _frontmatterRegex.firstMatch(rawContent);
    if (match == null) {
      return ParsedMarkdown(body: rawContent, contentBody: rawContent, hasFrontmatter: false);
    }

    final frontmatterBlock = match.group(1) ?? '';
    final contentBody = rawContent.substring(match.end);

    String? title;
    String? source;
    String? author;
    final authorList = <String>[];
    String? createdRaw;
    DateTime? createdAt;
    DateTime? updatedAt;
    String? description;
    final descriptionLines = <String>[];
    final tags = <String>{};
    bool isJournal = false;
    String? journalDate;

    final lines = frontmatterBlock.split(RegExp(r'\r?\n'));
    String? currentListKey;
    String? currentMultilineKey;

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
        } else if (_isAuthorKey(currentListKey)) {
          if (itemValue.isNotEmpty) {
            authorList.add(itemValue);
          }
        }
        continue;
      }

      // Handle indented continuation lines for multiline text (e.g. description)
      if ((line.startsWith('  ') || line.startsWith('\t')) && currentMultilineKey != null) {
        if (_isDescriptionKey(currentMultilineKey)) {
          descriptionLines.add(trimmed);
          continue;
        }
      }

      // Check key: value
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        continue;
      }

      final rawKey = line.substring(0, colonIndex).trim();
      final key = rawKey.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      final val = line.substring(colonIndex + 1).trim();

      currentMultilineKey = null;
      currentListKey = null;

      if (val.isEmpty || val == '|' || val == '>') {
        currentListKey = key;
        currentMultilineKey = key;
        continue;
      }

      final cleanVal = _stripQuotes(val);

      if (key == 'journal') {
        final lower = cleanVal.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') {
          isJournal = true;
        }
      } else if (_isTitleKey(key)) {
        if (cleanVal.isNotEmpty) {
          title = cleanVal;
        }
      } else if (_isSourceKey(key)) {
        if (cleanVal.isNotEmpty) {
          source = cleanVal;
        }
      } else if (_isAuthorKey(key)) {
        if (cleanVal.startsWith('[') && cleanVal.endsWith(']')) {
          final parts = _parseTagsValue(val);
          if (parts.isNotEmpty) {
            author = parts.join(', ');
          }
        } else if (cleanVal.isNotEmpty) {
          author = cleanVal;
        }
      } else if (_isDescriptionKey(key)) {
        if (cleanVal.isNotEmpty) {
          descriptionLines.add(cleanVal);
          currentMultilineKey = key;
        }
      } else if (_isTagKey(key)) {
        final parsedTags = _parseTagsValue(val);
        tags.addAll(parsedTags);
      } else if (_isCreatedDateKey(key)) {
        if (key == 'date') {
          if (JournalDateHelper.isValidDateString(cleanVal)) {
            journalDate = cleanVal;
          } else {
            final parsed = JournalDateHelper.tryParseDateString(cleanVal);
            if (parsed != null) {
              journalDate = JournalDateHelper.toDateString(parsed);
            }
          }
        }
        if (cleanVal.isNotEmpty) {
          createdRaw = cleanVal;
          final dt = _parseDateTime(cleanVal);
          if (dt != null) {
            createdAt = dt;
          }
        }
      } else if (_isUpdatedDateKey(key)) {
        final dt = _parseDateTime(cleanVal);
        if (dt != null) {
          updatedAt = dt;
        }
      }
    }

    if (authorList.isNotEmpty && (author == null || author.isEmpty)) {
      author = authorList.join(', ');
    }

    if (descriptionLines.isNotEmpty) {
      description = descriptionLines.join(' ').trim();
    }

    // If only createdAt was set, default updatedAt to createdAt
    if (createdAt != null && updatedAt == null) {
      updatedAt = createdAt;
    } else if (updatedAt != null && createdAt == null) {
      createdAt = updatedAt;
    }

    return ParsedMarkdown(
      title: title,
      source: source,
      author: author,
      createdAt: createdAt,
      createdRaw: createdRaw,
      updatedAt: updatedAt,
      description: description,
      tags: tags.toList(),
      isJournal: isJournal && journalDate != null,
      journalDate: (isJournal && journalDate != null) ? journalDate : null,
      body: rawContent, // Preserve full content as-is (do not strip frontmatter)
      contentBody: contentBody,
      hasFrontmatter: true,
    );
  }

  static bool _isTitleKey(String key) {
    return key == 'title';
  }

  static bool _isSourceKey(String key) {
    return key == 'source' ||
        key == 'url' ||
        key == 'link' ||
        key == 'source_url' ||
        key == 'sourceurl' ||
        key == 'source_link' ||
        key == 'sourcelink' ||
        key == 'origin' ||
        key == 'origin_url' ||
        key == 'canonical_url';
  }

  static bool _isAuthorKey(String key) {
    return key == 'author' ||
        key == 'authors' ||
        key == 'by' ||
        key == 'creator' ||
        key == 'writer';
  }

  static bool _isDescriptionKey(String key) {
    return key == 'description' ||
        key == 'summary' ||
        key == 'desc' ||
        key == 'abstract' ||
        key == 'excerpt';
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
