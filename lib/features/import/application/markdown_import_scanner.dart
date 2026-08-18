import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../../core/utils/tag_parser.dart';
import '../domain/markdown_import_item.dart';
import 'markdown_frontmatter_parser.dart';

abstract final class MarkdownImportScanner {
  /// Recursively scans [folderPath] for markdown files (.md and .markdown),
  /// extracts titles, subfolder tags, file properties, and prepares import items.
  static Future<List<MarkdownImportItem>> scanFolder(String folderPath) async {
    final rootDir = Directory(folderPath);
    if (!await rootDir.exists()) {
      return [];
    }

    final items = <MarkdownImportItem>[];

    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;

      final lowerPath = entity.path.toLowerCase();
      if (!lowerPath.endsWith('.md') && !lowerPath.endsWith('.markdown')) {
        continue;
      }

      try {
        final item = await processFile(entity, folderPath);
        if (item != null) {
          items.add(item);
        }
      } catch (e) {
        // Skip unreadable files gracefully
        continue;
      }
    }

    items.sort((a, b) => a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase()));
    return items;
  }

  /// Processes a list of files picked directly via [FilePicker.platform.pickFiles].
  static Future<List<MarkdownImportItem>> processPickedFiles(List<PlatformFile> pickedFiles) async {
    final items = <MarkdownImportItem>[];

    for (final pf in pickedFiles) {
      String rawContent = '';
      DateTime createdAt = DateTime.now();
      DateTime updatedAt = DateTime.now();
      int fileSizeBytes = pf.size;
      final relativePath = pf.name;
      final filePath = pf.path ?? pf.name;

      if (pf.path != null && pf.path!.isNotEmpty) {
        try {
          final file = File(pf.path!);
          if (await file.exists()) {
            rawContent = await file.readAsString();
            final stat = await file.stat();
            final modified = stat.modified;
            final changed = (stat.changed.isBefore(modified) && stat.changed.millisecondsSinceEpoch > 0)
                ? stat.changed
                : modified;
            createdAt = changed;
            updatedAt = modified;
            fileSizeBytes = stat.size;
          }
        } catch (_) {
          // Direct file reading fallback
        }
      }

      if (rawContent.isEmpty && pf.bytes != null) {
        try {
          rawContent = utf8.decode(pf.bytes!);
        } catch (_) {}
      }

      if (rawContent.isEmpty) continue;

      final parsed = MarkdownFrontmatterParser.parse(rawContent);
      final fileNameTitle = p.basenameWithoutExtension(pf.name);
      final title = (parsed.title != null && parsed.title!.trim().isNotEmpty)
          ? parsed.title!.trim()
          : fileNameTitle;

      final inBodyTags = TagParser.extractTags(parsed.body);
      final combinedTags = <String>{};
      for (final tag in parsed.tags) {
        combinedTags.add(tag);
      }
      for (final tag in inBodyTags) {
        combinedTags.add(tag);
      }

      items.add(
        MarkdownImportItem(
          filePath: filePath,
          relativePath: relativePath,
          title: title,
          content: parsed.body,
          tags: combinedTags.toList(),
          createdAt: parsed.createdAt ?? createdAt,
          updatedAt: parsed.updatedAt ?? updatedAt,
          fileSizeBytes: fileSizeBytes,
          isSelected: true,
        ),
      );
    }

    items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return items;
  }

  /// Processes a single markdown file into a [MarkdownImportItem].
  static Future<MarkdownImportItem?> processFile(File file, String rootFolderPath) async {
    final rawContent = await file.readAsString();
    final stat = await file.stat();

    // 1. Calculate relative path
    final relativePath = p.relative(file.path, from: rootFolderPath);

    // 2. Extract subfolder names as tags
    final subfolderTags = _extractSubfolderTags(relativePath);

    // 3. Parse frontmatter
    final parsed = MarkdownFrontmatterParser.parse(rawContent);

    // 4. Determine title: frontmatter title takes precedence, fallback to filename without extension
    final fileNameTitle = p.basenameWithoutExtension(file.path);
    final title = (parsed.title != null && parsed.title!.trim().isNotEmpty)
        ? parsed.title!.trim()
        : fileNameTitle;

    // 5. In-body tags
    final inBodyTags = TagParser.extractTags(parsed.body);

    // 6. Merge tags (subfolders + frontmatter + in-body)
    final combinedTags = <String>{};
    for (final tag in subfolderTags) {
      combinedTags.add(tag);
    }
    for (final tag in parsed.tags) {
      combinedTags.add(tag);
    }
    for (final tag in inBodyTags) {
      combinedTags.add(tag);
    }

    // 7. File properties for createdAt and updatedAt
    final modified = stat.modified;
    final changed = (stat.changed.isBefore(modified) && stat.changed.millisecondsSinceEpoch > 0)
        ? stat.changed
        : modified;

    final createdAt = parsed.createdAt ?? changed;
    final updatedAt = parsed.updatedAt ?? modified;

    return MarkdownImportItem(
      filePath: file.path,
      relativePath: relativePath,
      title: title,
      content: parsed.body,
      tags: combinedTags.toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      fileSizeBytes: stat.size,
      isSelected: true,
    );
  }

  /// Extracts subfolder names from relative path and converts them to valid tags.
  /// E.g. 'Articles/Wikipedia/Topic.md' -> ['articles', 'wikipedia']
  static List<String> _extractSubfolderTags(String relativePath) {
    final dirName = p.dirname(relativePath);
    if (dirName == '.' || dirName.isEmpty) {
      return const [];
    }

    final segments = p.split(dirName);
    final tags = <String>{};

    for (final seg in segments) {
      final trimmed = seg.trim();
      if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') continue;

      final normalized = _sanitizeFolderTag(trimmed);
      if (TagParser.isValidTag(normalized)) {
        tags.add(normalized);
      }
    }

    return tags.toList();
  }

  static String _sanitizeFolderTag(String input) {
    var tag = TagParser.normalizeTag(input);
    tag = tag.replaceAll(RegExp(r'\s+'), '-');
    return tag;
  }
}
