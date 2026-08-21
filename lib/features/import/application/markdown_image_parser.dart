import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/attachments/attachment_service.dart';
import '../domain/import_image_reference.dart';

/// Supported image extensions for wikilink matching and media detection.
const Set<String> _supportedImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.bmp',
  '.svg',
  '.ico',
  '.tiff',
  '.heic',
};

/// Common subfolder names where note attachments are typically stored.
const List<String> _commonAttachmentFolders = [
  'attachments',
  '_resources',
  'assets',
  'images',
  'media',
  'files',
  'img',
  'photos',
];

/// Utility for extracting image references from markdown documents and resolving them on disk.
abstract final class MarkdownImageParser {
  /// Standard markdown image regex: `![alt text](path/to/image.png "optional title")`
  static final RegExp _markdownImageRegex = RegExp(
    r'''!\[([^\]]*?)\]\(([^\s\)]+)(?:\s+["'][^"']*["'])?\)''',
  );

  /// Angle-bracketed markdown image regex: `![alt text](<path with spaces/image.png>)`
  static final RegExp _angleBracketImageRegex = RegExp(
    r'''!\[([^\]]*?)\]\(<([^>]+)>(?:\s+["'][^"']*["'])?\)''',
  );

  /// Obsidian / Logseq wikilink image embed regex: `![[image.png]]` or `![[image.png|alt text]]`
  static final RegExp _wikilinkImageRegex = RegExp(
    r'!\[\[([^\]\|]+)(?:\|([^\]]*))?\]\]',
  );

  /// HTML `<img>` tag regex: `<img ... src="path/to/img.png" ...>`
  static final RegExp _htmlImageRegex = RegExp(
    r'''<img\s+[^>]*?src=["']([^"']+)["'][^>]*?>''',
    caseSensitive: false,
  );

  /// Fenced code block regex to avoid extracting code examples as images.
  static final RegExp _codeBlockRegex = RegExp(
    r'(```|~~~)(?:[\s\S]*?)\1',
    multiLine: true,
  );

  /// Extracts all image references from [markdownContent] and resolves their filesystem paths.
  static List<ImportImageReference> extractAndResolveImages({
    required String markdownContent,
    required String filePath,
    required String rootFolderPath,
    Map<String, String>? vaultImagesMap,
  }) {
    if (markdownContent.trim().isEmpty) {
      return const [];
    }

    // Mask code blocks so sample image syntax inside code blocks is ignored
    final cleanContent = _maskCodeBlocks(markdownContent);
    final references = <ImportImageReference>[];
    final seenSyntaxes = <String>{};

    // 1. Angle-bracketed markdown images: ![alt](<path with spaces>)
    for (final match in _angleBracketImageRegex.allMatches(cleanContent)) {
      final syntax = match.group(0)!;
      if (!seenSyntaxes.add(syntax)) continue;

      final alt = match.group(1)?.trim() ?? '';
      final target = match.group(2)?.trim() ?? '';
      if (_shouldSkipTarget(target)) continue;

      references.add(
        _resolveReference(
          originalSyntax: syntax,
          rawTarget: target,
          altText: alt.isNotEmpty ? alt : _defaultAltFromTarget(target),
          markdownFilePath: filePath,
          rootFolderPath: rootFolderPath,
          vaultImagesMap: vaultImagesMap,
        ),
      );
    }

    // 2. Standard markdown images: ![alt](target)
    for (final match in _markdownImageRegex.allMatches(cleanContent)) {
      final syntax = match.group(0)!;
      if (!seenSyntaxes.add(syntax)) continue;

      final alt = match.group(1)?.trim() ?? '';
      final target = match.group(2)?.trim() ?? '';
      if (_shouldSkipTarget(target)) continue;

      references.add(
        _resolveReference(
          originalSyntax: syntax,
          rawTarget: target,
          altText: alt.isNotEmpty ? alt : _defaultAltFromTarget(target),
          markdownFilePath: filePath,
          rootFolderPath: rootFolderPath,
          vaultImagesMap: vaultImagesMap,
        ),
      );
    }

    // 3. Obsidian wikilink embeds: ![[image.png|alt]]
    for (final match in _wikilinkImageRegex.allMatches(cleanContent)) {
      final syntax = match.group(0)!;
      if (!seenSyntaxes.add(syntax)) continue;

      final target = match.group(1)?.trim() ?? '';
      final alt = match.group(2)?.trim() ?? '';

      // Only match if target has an image file extension
      final ext = p.extension(target).toLowerCase();
      if (!_supportedImageExtensions.contains(ext)) continue;
      if (_shouldSkipTarget(target)) continue;

      references.add(
        _resolveReference(
          originalSyntax: syntax,
          rawTarget: target,
          altText: alt.isNotEmpty ? alt : _defaultAltFromTarget(target),
          markdownFilePath: filePath,
          rootFolderPath: rootFolderPath,
          vaultImagesMap: vaultImagesMap,
        ),
      );
    }

    // 4. HTML <img> tags
    for (final match in _htmlImageRegex.allMatches(cleanContent)) {
      final syntax = match.group(0)!;
      if (!seenSyntaxes.add(syntax)) continue;

      final target = match.group(1)?.trim() ?? '';
      if (_shouldSkipTarget(target)) continue;

      // Extract alt if present in HTML tag
      final altMatch = RegExp(r'''alt=["']([^"']*)["']''', caseSensitive: false).firstMatch(syntax);
      final alt = altMatch?.group(1)?.trim() ?? '';

      references.add(
        _resolveReference(
          originalSyntax: syntax,
          rawTarget: target,
          altText: alt.isNotEmpty ? alt : _defaultAltFromTarget(target),
          markdownFilePath: filePath,
          rootFolderPath: rootFolderPath,
          vaultImagesMap: vaultImagesMap,
        ),
      );
    }

    return references;
  }

  /// Whether a target URL should be skipped from local disk resolution.
  static bool _shouldSkipTarget(String target) {
    if (target.isEmpty) return true;
    final lower = target.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image/') ||
        lower.startsWith('qp://');
  }

  /// Cleans and sanitizes raw path string (strips query fragments, decodes percent-encoding).
  static String cleanTarget(String rawTarget) {
    var cleaned = rawTarget.trim();
    if (cleaned.startsWith('<') && cleaned.endsWith('>')) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    // Remove query/fragment (?v=1 or #anchor)
    final questionIndex = cleaned.indexOf('?');
    if (questionIndex != -1) {
      cleaned = cleaned.substring(0, questionIndex);
    }
    final hashIndex = cleaned.indexOf('#');
    if (hashIndex != -1) {
      cleaned = cleaned.substring(0, hashIndex);
    }
    try {
      cleaned = Uri.decodeComponent(cleaned);
    } catch (_) {
      // Keep as-is if malformed percent encoding
    }
    return cleaned.trim();
  }

  /// Resolves an individual image reference against the local filesystem.
  static ImportImageReference _resolveReference({
    required String originalSyntax,
    required String rawTarget,
    required String altText,
    required String markdownFilePath,
    required String rootFolderPath,
    Map<String, String>? vaultImagesMap,
  }) {
    final cleaned = cleanTarget(rawTarget);
    final mdDir = p.dirname(markdownFilePath);
    final baseName = p.basename(cleaned);
    final baseNameLower = baseName.toLowerCase();

    // 1. Direct path relative to markdown file directory
    final candidatePaths = <String>[
      p.normalize(p.join(mdDir, cleaned)),
      // 2. Direct path relative to root folder
      p.normalize(p.join(rootFolderPath, cleaned)),
    ];

    // 3. Common attachment subdirectories inside note directory
    for (final folder in _commonAttachmentFolders) {
      candidatePaths.add(p.normalize(p.join(mdDir, folder, cleaned)));
      candidatePaths.add(p.normalize(p.join(mdDir, folder, baseName)));
    }

    // 4. Common attachment subdirectories inside root folder
    for (final folder in _commonAttachmentFolders) {
      candidatePaths.add(p.normalize(p.join(rootFolderPath, folder, cleaned)));
      candidatePaths.add(p.normalize(p.join(rootFolderPath, folder, baseName)));
    }

    // 5. Vault image index lookup (for wikilinks or moved files)
    if (vaultImagesMap != null && vaultImagesMap.containsKey(baseNameLower)) {
      candidatePaths.add(vaultImagesMap[baseNameLower]!);
    }

    // 6. Absolute path (if user note has full path)
    if (p.isAbsolute(cleaned)) {
      candidatePaths.insert(0, p.normalize(cleaned));
    }

    // Attempt to locate first existing file on disk
    for (final candidate in candidatePaths) {
      try {
        final file = File(candidate);
        if (file.existsSync()) {
          final stat = file.statSync();
          if (stat.type == FileSystemEntityType.file) {
            if (stat.size > AttachmentService.maxFileSizeBytes) {
              return ImportImageReference(
                originalSyntax: originalSyntax,
                rawTarget: rawTarget,
                altText: altText,
                resolvedFilePath: file.path,
                fileSizeBytes: stat.size,
                status: ImportImageStatus.exceedsLimit,
              );
            }

            return ImportImageReference(
              originalSyntax: originalSyntax,
              rawTarget: rawTarget,
              altText: altText,
              resolvedFilePath: file.path,
              fileSizeBytes: stat.size,
              status: ImportImageStatus.resolved,
            );
          }
        }
      } catch (_) {
        // Skip unreadable path candidates
      }
    }

    // File not found on disk
    return ImportImageReference(
      originalSyntax: originalSyntax,
      rawTarget: rawTarget,
      altText: altText,
      status: ImportImageStatus.missing,
    );
  }

  static String _maskCodeBlocks(String content) {
    return content.replaceAllMapped(_codeBlockRegex, (match) {
      return '\n' * match.group(0)!.split('\n').length;
    });
  }

  static String _defaultAltFromTarget(String target) {
    final base = p.basenameWithoutExtension(cleanTarget(target));
    return base.isNotEmpty ? base : 'Image';
  }
}
