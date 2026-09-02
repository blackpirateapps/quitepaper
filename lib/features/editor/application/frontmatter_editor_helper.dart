import 'package:flutter/material.dart';
import '../../../core/utils/tag_parser.dart';
import '../domain/frontmatter_document.dart';

/// Helper utility for parsing, extracting, and surgically mutating YAML frontmatter
/// directly in canonical Markdown strings without modifying comments, ordering, or unknown keys.
abstract final class FrontmatterEditorHelper {
  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Parses YAML frontmatter from [content], identifying exact source ranges for each property.
  static FrontmatterDocument parse(String content) {
    if (content.isEmpty) {
      return FrontmatterDocument.empty;
    }

    final match = _frontmatterRegex.firstMatch(content);
    if (match == null) {
      return FrontmatterDocument.empty;
    }

    final fullMatchText = match.group(0) ?? '';
    final blockText = match.group(1) ?? '';
    final frontmatterRange = TextRange(start: 0, end: match.end);
    final bodyStartOffset = match.end;

    final properties = <FrontmatterProperty>[];
    final unknownProperties = <String, String>{};

    String? parsedTitle;
    String? parsedAuthor;
    String? parsedCreated;
    String? parsedSource;
    String? parsedDescription;
    final parsedTags = <String>{};

    // Calculate line offsets within the frontmatter block
    final openDelimiterEnd = content.indexOf('\n') + 1;
    var currentOffset = openDelimiterEnd;
    final lines = blockText.split(RegExp(r'\r?\n'));

    String? currentListKey;
    final currentListItems = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStart = currentOffset;
      final lineEnd = lineStart + line.length;
      currentOffset = lineEnd + 1; // +1 for newline character

      final trimmed = line.trim();

      // Comment or empty line -> preserve as-is
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      // Multiline YAML list item (e.g. "  - item")
      if (trimmed.startsWith('- ') && currentListKey != null) {
        final itemVal = _stripQuotes(trimmed.substring(2).trim());
        currentListItems.add(itemVal);
        if (_isTagKey(currentListKey)) {
          final normalized = TagParser.normalizeTag(itemVal);
          if (TagParser.isValidTag(normalized)) {
            parsedTags.add(normalized);
          }
        } else if (_isAuthorKey(currentListKey)) {
          if (itemVal.isNotEmpty) {
            if (parsedAuthor == null || parsedAuthor.isEmpty) {
              parsedAuthor = itemVal;
            } else {
              parsedAuthor = '$parsedAuthor, $itemVal';
            }
          }
        }
        continue;
      }

      // Check key: value
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        continue;
      }

      final rawKey = line.substring(0, colonIndex).trim();
      final key = rawKey.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      final valPart = line.substring(colonIndex + 1);
      final rawVal = valPart.trim();

      final keyStart = lineStart + line.indexOf(rawKey);
      final keyEnd = keyStart + rawKey.length;

      final valStart = lineStart + colonIndex + 1 + (valPart.length - valPart.trimLeft().length);
      final valEnd = valStart + rawVal.length;

      currentListKey = null;
      currentListItems.clear();

      if (rawVal.isEmpty || rawVal == '|' || rawVal == '>') {
        currentListKey = key;
        continue;
      }

      final cleanVal = _stripQuotes(rawVal);
      final isKnown = _isKnownKey(key);

      properties.add(FrontmatterProperty(
        key: key,
        rawValue: rawVal,
        displayValue: cleanVal,
        keyRange: TextRange(start: keyStart, end: keyEnd),
        valueRange: TextRange(start: valStart, end: valEnd),
        lineRange: TextRange(start: lineStart, end: lineEnd),
        isKnown: isKnown,
        isEditable: isKnown,
      ));

      if (_isTitleKey(key)) {
        if (cleanVal.isNotEmpty) parsedTitle = cleanVal;
      } else if (_isAuthorKey(key)) {
        if (cleanVal.isNotEmpty) {
          if (cleanVal.startsWith('[') && cleanVal.endsWith(']')) {
            final list = _parseListValue(rawVal);
            parsedAuthor = list.join(', ');
          } else {
            parsedAuthor = cleanVal;
          }
        }
      } else if (_isCreatedDateKey(key)) {
        if (cleanVal.isNotEmpty) parsedCreated = cleanVal;
      } else if (_isSourceKey(key)) {
        if (cleanVal.isNotEmpty) parsedSource = cleanVal;
      } else if (_isDescriptionKey(key)) {
        if (cleanVal.isNotEmpty) parsedDescription = cleanVal;
      } else if (_isTagKey(key)) {
        final tagsList = _parseListValue(rawVal);
        for (final t in tagsList) {
          final normalized = TagParser.normalizeTag(t);
          if (TagParser.isValidTag(normalized)) {
            parsedTags.add(normalized);
          }
        }
      } else {
        unknownProperties[rawKey] = rawVal;
      }
    }

    return FrontmatterDocument(
      hasFrontmatter: true,
      rawFrontmatter: fullMatchText,
      frontmatterRange: frontmatterRange,
      properties: properties,
      title: parsedTitle,
      author: parsedAuthor,
      created: parsedCreated,
      source: parsedSource,
      description: parsedDescription,
      tags: parsedTags.toList(),
      unknownProperties: unknownProperties,
      bodyStartOffset: bodyStartOffset,
    );
  }

  /// Surgically mutates or inserts a specific frontmatter property in [documentText]
  /// without re-serializing or modifying unknown fields, comments, or whitespace.
  static String updateProperty({
    required String documentText,
    required String key,
    required String newValue,
  }) {
    final doc = parse(documentText);
    final normKey = key.toLowerCase().trim();

    if (!doc.hasFrontmatter) {
      // Create new frontmatter block at the beginning
      final newBlock = '---\n$normKey: $newValue\n---\n\n';
      return '$newBlock$documentText';
    }

    final prop = doc.getProperty(normKey);
    if (prop != null) {
      // Replace existing property value in place
      final cleanNewVal = newValue.contains('\n') || newValue.contains(':')
          ? '"${newValue.replaceAll('"', r'\"')}"'
          : newValue;
      final start = prop.valueRange.start;
      final end = prop.valueRange.end;
      return documentText.replaceRange(start, end, cleanNewVal);
    }

    // Property not in frontmatter -> insert before closing delimiter
    final match = _frontmatterRegex.firstMatch(documentText)!;
    final closingIndex = documentText.lastIndexOf('---', match.end - 1);
    final insertOffset = closingIndex > 0 ? closingIndex : match.end;

    final cleanNewVal = newValue.contains('\n') || newValue.contains(':')
        ? '"${newValue.replaceAll('"', r'\"')}"'
        : newValue;
    final insertText = '$normKey: $cleanNewVal\n';
    return documentText.replaceRange(insertOffset, insertOffset, insertText);
  }

  /// Updates or inserts the frontmatter `title:` property if frontmatter is present.
  /// If frontmatter is NOT present, leaves [documentText] unchanged.
  static String updateTitle({
    required String documentText,
    required String newTitle,
  }) {
    final doc = parse(documentText);
    if (!doc.hasFrontmatter) {
      return documentText;
    }

    final titleProp = doc.getProperty('title');
    if (titleProp != null) {
      final safeTitle = newTitle.contains(':') || newTitle.contains('#')
          ? '"${newTitle.replaceAll('"', r'\"')}"'
          : newTitle;
      return documentText.replaceRange(
        titleProp.valueRange.start,
        titleProp.valueRange.end,
        safeTitle,
      );
    } else {
      // Insert title at the beginning of the frontmatter block
      final openDelimiterEnd = documentText.indexOf('\n') + 1;
      final safeTitle = newTitle.contains(':') || newTitle.contains('#')
          ? '"${newTitle.replaceAll('"', r'\"')}"'
          : newTitle;
      return documentText.replaceRange(
        openDelimiterEnd,
        openDelimiterEnd,
        'title: $safeTitle\n',
      );
    }
  }

  /// Updates the `tags:` list inside frontmatter.
  static String updateTags({
    required String documentText,
    required List<String> tags,
  }) {
    final doc = parse(documentText);
    final formattedTags = '[${tags.map((t) => t.trim()).where((t) => t.isNotEmpty).join(', ')}]';

    if (!doc.hasFrontmatter) {
      if (tags.isEmpty) return documentText;
      return '---\ntags: $formattedTags\n---\n\n$documentText';
    }

    final tagsProp = doc.getProperty('tags') ??
        doc.getProperty('tag') ??
        doc.getProperty('categories') ??
        doc.getProperty('category');

    if (tagsProp != null) {
      return documentText.replaceRange(
        tagsProp.valueRange.start,
        tagsProp.valueRange.end,
        formattedTags,
      );
    } else {
      final match = _frontmatterRegex.firstMatch(documentText)!;
      final closingIndex = documentText.lastIndexOf('---', match.end - 1);
      final insertOffset = closingIndex > 0 ? closingIndex : match.end;
      return documentText.replaceRange(
        insertOffset,
        insertOffset,
        'tags: $formattedTags\n',
      );
    }
  }

  /// Extracts the main Markdown body content by stripping the YAML frontmatter block.
  static String extractBody(String fullDocument) {
    if (fullDocument.isEmpty) return '';
    final match = _frontmatterRegex.firstMatch(fullDocument);
    if (match == null) return fullDocument;
    return fullDocument.substring(match.end);
  }

  /// Reassembles frontmatter and body into canonical Markdown.
  static String assemble(String? frontmatterBlock, String body) {
    if (frontmatterBlock == null || frontmatterBlock.trim().isEmpty) {
      return body;
    }
    var cleanHeader = frontmatterBlock;
    if (!cleanHeader.endsWith('\n')) {
      cleanHeader = '$cleanHeader\n';
    }
    return '$cleanHeader$body';
  }

  static bool _isKnownKey(String key) {
    return _isTitleKey(key) ||
        _isAuthorKey(key) ||
        _isCreatedDateKey(key) ||
        _isSourceKey(key) ||
        _isDescriptionKey(key) ||
        _isTagKey(key);
  }

  static bool _isTitleKey(String key) => key == 'title';

  static bool _isAuthorKey(String key) =>
      key == 'author' || key == 'authors' || key == 'by' || key == 'creator' || key == 'writer';

  static bool _isCreatedDateKey(String key) =>
      key == 'date' ||
      key == 'created' ||
      key == 'created_at' ||
      key == 'createdat' ||
      key == 'creation_date';

  static bool _isSourceKey(String key) =>
      key == 'source' ||
      key == 'url' ||
      key == 'link' ||
      key == 'source_url' ||
      key == 'sourceurl' ||
      key == 'origin';

  static bool _isDescriptionKey(String key) =>
      key == 'description' || key == 'summary' || key == 'desc' || key == 'abstract';

  static bool _isTagKey(String key) =>
      key == 'tags' || key == 'tag' || key == 'categories' || key == 'category' || key == 'keywords';

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

  static List<String> _parseListValue(String raw) {
    var str = raw.trim();
    if (str.startsWith('[') && str.endsWith(']')) {
      str = str.substring(1, str.length - 1);
    }
    return str
        .split(',')
        .map((s) => _stripQuotes(s))
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
