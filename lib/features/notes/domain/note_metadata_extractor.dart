import 'package:flutter/foundation.dart';
import '../../import/application/markdown_frontmatter_parser.dart';
import 'note_model.dart';

/// Extracted presentation metadata for a note in the notes list.
@immutable
class NoteMetadata {
  const NoteMetadata({
    required this.displayTitle,
    required this.previewSnippet,
    required this.tags,
    this.attachmentSummary,
    this.thumbnailUri,
    this.hasCustomTitle = false,
    this.isPasswordProtected = false,
  });

  final String displayTitle;
  final String previewSnippet;
  final List<String> tags;
  final String? attachmentSummary;
  final String? thumbnailUri;
  final bool hasCustomTitle;
  final bool isPasswordProtected;
}

/// High-performance metadata extractor for clean note previews, frontmatter resolution,
/// and textual attachment summaries.
abstract final class NoteMetadataExtractor {
  static final RegExp _imageRegex = RegExp(
    r'!\[(.*?)\]\((?:qp:\/\/asset\/[^\s\)]+|https?:\/\/[^\s\)]+|[^\s\)]*)\)',
  );

  static final RegExp _documentRegex = RegExp(
    r'\[(.*?)\]\(qp:\/\/document\/[^\s\)]+\)',
  );

  static final RegExp _pdfLinkRegex = RegExp(
    r'\[(.*?)\]\((?:[^\s\)]+\.pdf(?:\?[^\)]*)?)\)',
    caseSensitive: false,
  );

  static final RegExp _genericAssetRegex = RegExp(
    r'(?<!\!)\[(.*?)\]\(qp:\/\/asset\/([^\s\)]+)\)',
  );

  static final RegExp _pageCountRegex = RegExp(
    r'(\d+)\s*(?:pages|page|p\b)',
    caseSensitive: false,
  );

  /// Extracts comprehensive presentation metadata from a [Note].
  static NoteMetadata extract(
    Note note, {
    String? searchQuery,
    String? precomputedSnippet,
  }) {
    final title = note.title.trim().isNotEmpty
        ? note.title.trim()
        : deriveTitle(note.content);

    final effectiveTitle = title.isNotEmpty ? title : 'Untitled';
    final hasCustomTitle = note.title.trim().isNotEmpty;

    final preview = (precomputedSnippet != null && precomputedSnippet.isNotEmpty)
        ? precomputedSnippet
        : derivePreviewSnippet(
            note.content,
            title: note.title,
            isPasswordProtected: note.isPasswordProtected,
          );

    final attachmentSummary = note.isPasswordProtected
        ? null
        : extractAttachmentSummary(note.content);

    final thumbnailUri = note.isPasswordProtected
        ? null
        : extractThumbnailUri(note.content);

    return NoteMetadata(
      displayTitle: effectiveTitle,
      previewSnippet: preview,
      tags: note.tags,
      attachmentSummary: attachmentSummary,
      thumbnailUri: thumbnailUri,
      hasCustomTitle: hasCustomTitle,
      isPasswordProtected: note.isPasswordProtected,
    );
  }

  /// Derives a clean concise title from note content, stripping frontmatter or Markdown markers.
  static String deriveTitle(String content) {
    if (content.isEmpty) return '';
    if (content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
      return '';
    }

    final trimmed = content.trim();

    // 1. Check for YAML frontmatter
    if (trimmed.startsWith('---')) {
      final parsed = MarkdownFrontmatterParser.parse(content);
      if (parsed.title != null && parsed.title!.trim().isNotEmpty) {
        return parsed.title!.trim();
      }
      if (parsed.contentBody.trim().isNotEmpty) {
        return deriveTitle(parsed.contentBody);
      }
    }

    // 2. Scan first line of body
    final sample = content.length > 300 ? content.substring(0, 300) : content;
    final sampleTrimmed = sample.trim();
    if (sampleTrimmed.isEmpty) return '';

    final newlineIdx = sampleTrimmed.indexOf('\n');
    final firstLine = newlineIdx != -1
        ? sampleTrimmed.substring(0, newlineIdx).trim()
        : sampleTrimmed;

    final cleanFirstLine = cleanMarkdownLine(firstLine);
    if (cleanFirstLine.isNotEmpty) {
      final words = cleanFirstLine
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.length > 6) {
        return '${words.take(6).join(' ')}...';
      }
      if (cleanFirstLine.length > 40) {
        return '${cleanFirstLine.substring(0, 37).trim()}...';
      }
      return cleanFirstLine;
    }
    return '';
  }

  /// Derives a clean one or two line preview snippet from note content.
  static String derivePreviewSnippet(
    String content, {
    String? title,
    bool isPasswordProtected = false,
  }) {
    if (isPasswordProtected ||
        content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
      return '🔒 Password protected note';
    }
    if (content.isEmpty) return '';

    var bodyText = content;

    // 1. Check for YAML frontmatter
    if (content.trim().startsWith('---')) {
      final parsed = MarkdownFrontmatterParser.parse(content);
      if (parsed.description != null && parsed.description!.trim().isNotEmpty) {
        return cleanMarkdownLine(parsed.description!);
      }
      bodyText = parsed.contentBody;
    }

    final trimmed = bodyText.trim();
    if (trimmed.isEmpty) return '';

    final sample = trimmed.length > 800 ? trimmed.substring(0, 800) : trimmed;
    final lines = sample.split('\n');
    final cleanLines = <String>[];

    // If title was empty and first line was used as title, start preview from 2nd line
    final hasCustomTitle = title != null && title.trim().isNotEmpty;
    final startIndex = (!hasCustomTitle && lines.length > 1) ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final clean = cleanMarkdownLine(line);
      if (clean.isNotEmpty) {
        cleanLines.add(clean);
      }
      if (cleanLines.length >= 2) break;
    }

    return cleanLines.join(' ').trim();
  }

  /// Cleans raw Markdown line into plain editorial text.
  static String cleanMarkdownLine(String rawLine) {
    var line = rawLine.trim();
    if (line.isEmpty) return '';

    // Remove markdown headers #, ##, etc.
    line = line.replaceAll(RegExp(r'^#+\s*'), '');
    // Remove blockquotes >
    line = line.replaceAll(RegExp(r'^>\s*'), '');
    // Remove checklist markers - [ ] , - [x] , - [X]
    line = line.replaceAll(RegExp(r'^[-*+]\s+\[[\sxX]\]\s*'), '');
    // Remove list markers - , * , + , 1. , 2.
    line = line.replaceAll(RegExp(r'^[-*+]\s+'), '');
    line = line.replaceAll(RegExp(r'^\d+\.\s+'), '');
    // Replace images ![alt](url) -> 'image'
    line = line.replaceAllMapped(_imageRegex, (m) => 'image');
    // Replace links [text](url) -> text (or 'Document' if empty)
    line = line.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) {
      final text = m.group(1)?.trim() ?? '';
      return text.isNotEmpty ? text : 'Document';
    });
    // Remove code fences and backticks
    line = line.replaceAll(RegExp(r'```[a-zA-Z0-9_-]*'), '');
    line = line.replaceAll('`', '');
    // Remove formatting markers (*, _, ~, ==)
    line = line.replaceAll(RegExp(r'[*_~]'), '');
    line = line.replaceAll('==', '');
    // Remove HTML tags and comments
    line = line.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    line = line.replaceAll(RegExp(r'<[^>]*>'), '');
    // Collapse multiple whitespace
    line = line.replaceAll(RegExp(r'\s+'), ' ');

    return line.trim();
  }

  /// Extracts textual attachment summary (e.g. 'PDF · 12 pages', '2 PDFs · 31 pages', '2 images', 'DOCX').
  static String? extractAttachmentSummary(String content) {
    if (content.isEmpty) return null;

    final docMatches = _documentRegex.allMatches(content).toList();
    final pdfMatches = _pdfLinkRegex.allMatches(content).toList();
    final imgMatches = _imageRegex.allMatches(content).toList();
    final genericMatches = _genericAssetRegex.allMatches(content).toList();

    // Check if any generic matches are actually PDF files
    final allPdfs = <RegExpMatch>[...docMatches, ...pdfMatches];
    final nonPdfFiles = <RegExpMatch>[];

    for (final match in genericMatches) {
      final title = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      if (title.toLowerCase().endsWith('.pdf') ||
          url.toLowerCase().contains('.pdf') ||
          title.toLowerCase().contains('pdf')) {
        allPdfs.add(match);
      } else {
        nonPdfFiles.add(match);
      }
    }

    // 1. PDF Attachments
    if (allPdfs.isNotEmpty) {
      int totalPages = 0;
      bool hasPageInfo = false;

      for (final m in allPdfs) {
        final title = m.group(1) ?? '';
        final pageMatch = _pageCountRegex.firstMatch(title);
        if (pageMatch != null) {
          final count = int.tryParse(pageMatch.group(1) ?? '');
          if (count != null && count > 0) {
            totalPages += count;
            hasPageInfo = true;
          }
        }
      }

      final totalPdfs = allPdfs.length;
      if (totalPdfs == 1) {
        if (hasPageInfo && totalPages > 0) {
          return 'PDF · $totalPages ${totalPages == 1 ? 'page' : 'pages'}';
        }
        return 'PDF';
      } else {
        if (hasPageInfo && totalPages > 0) {
          return '$totalPdfs PDFs · $totalPages pages';
        }
        return '$totalPdfs PDFs';
      }
    }

    // 2. Image Attachments (if no PDFs)
    if (imgMatches.isNotEmpty) {
      final imgCount = imgMatches.length;
      return imgCount == 1 ? '1 image' : '$imgCount images';
    }

    // 3. Generic File Attachments
    if (nonPdfFiles.isNotEmpty) {
      final fileCount = nonPdfFiles.length;
      if (fileCount == 1) {
        final fileName = nonPdfFiles.first.group(1) ?? '';
        final dotIdx = fileName.lastIndexOf('.');
        if (dotIdx != -1 && dotIdx < fileName.length - 1) {
          final ext = fileName.substring(dotIdx + 1).toUpperCase();
          if (ext.length <= 5) {
            return ext;
          }
        }
        return '1 attachment';
      }
      return '$fileCount attachments';
    }

    return null;
  }

  /// Extracts the first image URI or asset ID from content for thumbnail preview.
  static String? extractThumbnailUri(String content) {
    if (content.isEmpty) return null;

    final match = _imageRegex.firstMatch(content);
    if (match != null) {
      final fullMatch = match.group(0) ?? '';
      // Extract url inside (...)
      final openParen = fullMatch.indexOf('(');
      final closeParen = fullMatch.lastIndexOf(')');
      if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
        final uri = fullMatch.substring(openParen + 1, closeParen).trim();
        if (uri.isNotEmpty) {
          return uri;
        }
      }
    }
    return null;
  }
}
