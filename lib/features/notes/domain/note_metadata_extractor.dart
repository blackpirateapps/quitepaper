import 'package:flutter/foundation.dart';
import '../../import/application/markdown_frontmatter_parser.dart';
import 'note_model.dart';

/// Representation of a compact parsed Markdown table for note list previews.
@immutable
class NoteTablePreview {
  const NoteTablePreview({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  bool get isValid => headers.length >= 2 && rows.isNotEmpty;
}

/// Kind of attachment thumbnail to present.
enum ThumbnailKind {
  image,
  pdf,
  textFile,
  none,
}

/// Data payload for thumbnail rendering in the note list tile.
@immutable
class ThumbnailData {
  const ThumbnailData({
    required this.kind,
    required this.uri,
    this.label,
  });

  const ThumbnailData.image(this.uri)
      : kind = ThumbnailKind.image,
        label = null;

  const ThumbnailData.pdf(this.uri, [this.label = 'PDF'])
      : kind = ThumbnailKind.pdf;

  const ThumbnailData.textFile(this.uri, [this.label = 'TXT'])
      : kind = ThumbnailKind.textFile;

  final ThumbnailKind kind;
  final String uri;
  final String? label;
}

/// Extracted presentation metadata for a note in the notes list.
@immutable
class NoteMetadata {
  const NoteMetadata({
    required this.displayTitle,
    required this.previewSnippet,
    required this.tags,
    this.attachmentSummary,
    this.thumbnailUri,
    this.thumbnailData,
    this.tablePreview,
    this.hasCustomTitle = false,
    this.isPasswordProtected = false,
  });

  final String displayTitle;
  final String previewSnippet;
  final List<String> tags;
  final String? attachmentSummary;
  final String? thumbnailUri;
  final ThumbnailData? thumbnailData;
  final NoteTablePreview? tablePreview;
  final bool hasCustomTitle;
  final bool isPasswordProtected;
}

/// High-performance metadata extractor for clean note previews, frontmatter resolution,
/// textual attachment summaries, dynamic table rendering, and PDF/text thumbnails.
abstract final class NoteMetadataExtractor {
  static final RegExp _imageRegex = RegExp(
    r'!\[(.*?)\]\((?:qp:\/\/asset\/[^\s\)]+|https?:\/\/[^\s\)]+|[^\s\)]*)\)',
  );

  static final RegExp _documentRegex = RegExp(
    r'\[(.*?)\]\(qp:\/\/document\/([^\s\)]+)\)',
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

  static final RegExp _tableSeparatorRegex = RegExp(
    r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$',
  );

  static const _textExtensions = {
    'txt',
    'md',
    'markdown',
    'csv',
    'json',
    'log',
    'yaml',
    'yml',
    'xml',
    'html',
    'htm',
    'dart',
    'py',
    'js',
    'ts',
    'sql',
    'sh',
  };

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

    final tablePreview = note.isPasswordProtected
        ? null
        : extractTablePreview(note.content);

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

    final thumbnailData = note.isPasswordProtected
        ? null
        : extractThumbnailData(note.content);

    return NoteMetadata(
      displayTitle: effectiveTitle,
      previewSnippet: preview,
      tags: note.tags,
      attachmentSummary: attachmentSummary,
      thumbnailUri: thumbnailData?.uri,
      thumbnailData: thumbnailData,
      tablePreview: tablePreview,
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
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip table separator lines in preview snippet
      if (_tableSeparatorRegex.hasMatch(line)) continue;

      final clean = cleanMarkdownLine(line);
      if (clean.isNotEmpty) {
        cleanLines.add(clean);
      }
      if (cleanLines.length >= 2) break;
    }

    return cleanLines.join(' ').trim();
  }

  /// Extracts a structured Markdown table preview if a valid table exists near the top of the note.
  static NoteTablePreview? extractTablePreview(String content) {
    if (content.isEmpty) return null;

    var bodyText = content;
    if (content.trim().startsWith('---')) {
      final parsed = MarkdownFrontmatterParser.parse(content);
      bodyText = parsed.contentBody;
    }

    final lines = bodyText.split('\n');
    for (var i = 0; i < lines.length - 1 && i < 15; i++) {
      final headerLine = lines[i].trim();
      final separatorLine = lines[i + 1].trim();

      if (headerLine.contains('|') && _tableSeparatorRegex.hasMatch(separatorLine)) {
        final headers = _splitTableRow(headerLine);
        if (headers.length < 2) continue;

        final rows = <List<String>>[];
        var rowIndex = i + 2;
        while (rowIndex < lines.length && rows.length < 2) {
          final rowLine = lines[rowIndex].trim();
          if (rowLine.isEmpty || !rowLine.contains('|')) break;

          final cells = _splitTableRow(rowLine);
          if (cells.isNotEmpty) {
            // Pad or truncate to match header length
            final normalizedCells = List<String>.generate(
              headers.length,
              (cIdx) => cIdx < cells.length ? cells[cIdx] : '',
            );
            rows.add(normalizedCells);
          }
          rowIndex++;
        }

        if (rows.isNotEmpty) {
          // Take at most 3 columns for compact display
          final maxCols = headers.length > 3 ? 3 : headers.length;
          final cleanHeaders = headers
              .take(maxCols)
              .map((h) => cleanMarkdownLine(h))
              .toList();

          final cleanRows = rows.map((r) {
            return r
                .take(maxCols)
                .map((c) => cleanMarkdownLine(c))
                .toList();
          }).toList();

          return NoteTablePreview(
            headers: cleanHeaders,
            rows: cleanRows,
          );
        }
      }
    }

    return null;
  }

  static List<String> _splitTableRow(String rawLine) {
    var line = rawLine.trim();
    if (line.startsWith('|')) {
      line = line.substring(1);
    }
    if (line.endsWith('|')) {
      line = line.substring(0, line.length - 1);
    }
    return line.split('|').map((c) => c.trim()).toList();
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

  /// Extracts textual attachment summary (e.g. 'PDF · 12 pages', '2 PDFs · 31 pages', '2 images', 'TXT', 'DOCX').
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

  /// Extracts the richest thumbnail payload (Image, PDF first-page, or Text file sheet).
  static ThumbnailData? extractThumbnailData(String content) {
    if (content.isEmpty) return null;

    // 1. Image Thumbnail
    final imgMatch = _imageRegex.firstMatch(content);
    if (imgMatch != null) {
      final fullMatch = imgMatch.group(0) ?? '';
      final openParen = fullMatch.indexOf('(');
      final closeParen = fullMatch.lastIndexOf(')');
      if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
        final uri = fullMatch.substring(openParen + 1, closeParen).trim();
        if (uri.isNotEmpty) {
          return ThumbnailData.image(uri);
        }
      }
    }

    // 2. PDF Document Thumbnail (qp://document/<UUID>)
    final docMatch = _documentRegex.firstMatch(content);
    if (docMatch != null) {
      final docId = docMatch.group(2) ?? '';
      if (docId.isNotEmpty) {
        return ThumbnailData.pdf('qp://document/$docId');
      }
    }

    // 3. PDF File Link
    final pdfMatch = _pdfLinkRegex.firstMatch(content);
    if (pdfMatch != null) {
      final fullMatch = pdfMatch.group(0) ?? '';
      final openParen = fullMatch.indexOf('(');
      final closeParen = fullMatch.lastIndexOf(')');
      if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
        final uri = fullMatch.substring(openParen + 1, closeParen).trim();
        if (uri.isNotEmpty) {
          return ThumbnailData.pdf(uri);
        }
      }
    }

    // 4. Text / Code / Data Asset File Thumbnail
    final assetMatch = _genericAssetRegex.firstMatch(content);
    if (assetMatch != null) {
      final fileName = assetMatch.group(1) ?? '';
      final assetId = assetMatch.group(2) ?? '';
      final dotIdx = fileName.lastIndexOf('.');
      if (dotIdx != -1 && dotIdx < fileName.length - 1) {
        final ext = fileName.substring(dotIdx + 1).toLowerCase();
        if (_textExtensions.contains(ext)) {
          final label = ext == 'markdown'
              ? 'MD'
              : (ext.length <= 4 ? ext.toUpperCase() : 'TXT');
          return ThumbnailData.textFile('qp://asset/$assetId', label);
        }
      }
    }

    return null;
  }

  /// Extracts the first image URI or asset ID from content for thumbnail preview (backward compatibility).
  static String? extractThumbnailUri(String content) =>
      extractThumbnailData(content)?.uri;
}
