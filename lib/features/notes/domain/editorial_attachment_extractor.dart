import 'package:flutter/foundation.dart';
import '../../import/application/markdown_frontmatter_parser.dart';
import 'editorial_attachment_item.dart';
import 'note_metadata_extractor.dart';
import 'note_model.dart';

/// High-performance attachment extractor for Editorial notes list.
/// Extracts all inline images, PDFs, and document cards with bounded LRU caching.
abstract final class EditorialAttachmentExtractor {
  static final Map<String, List<EditorialAttachmentItem>> _cache = {};
  static const int maxCacheSize = 500;

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

  static String _computeCacheKey(Note note) {
    return '${note.id}_${note.updatedAt.millisecondsSinceEpoch}_${note.content.hashCode}';
  }

  static void invalidate(String noteId) {
    _cache.removeWhere((key, _) => key.startsWith('${noteId}_'));
  }

  static void clearCache() {
    _cache.clear();
  }

  @visibleForTesting
  static int get cacheSize => _cache.length;

  /// Extracts ordered list of attachment items from a [Note].
  static List<EditorialAttachmentItem> extract(Note note) {
    if (note.isPasswordProtected) return const [];
    if (note.content.isEmpty) return const [];
    if (note.content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
      return const [];
    }

    final cacheKey = _computeCacheKey(note);
    final cached = _cache[cacheKey];
    if (cached != null) {
      _cache.remove(cacheKey);
      _cache[cacheKey] = cached;
      return cached;
    }

    var body = note.content;
    if (body.trim().startsWith('---')) {
      final parsed = MarkdownFrontmatterParser.parse(body);
      body = parsed.contentBody;
    }

    final items = <EditorialAttachmentItem>[];
    final seenUris = <String>{};

    // Fast check: if body has no brackets/parentheses, there are no attachments
    if (!body.contains('(') || (!body.contains('[') && !body.contains('!['))) {
      _cacheResult(cacheKey, items);
      return items;
    }

    // 1. Scan for images: ![alt](url)
    for (final match in _imageRegex.allMatches(body)) {
      final fullMatch = match.group(0) ?? '';
      final alt = match.group(1)?.trim();
      final openParen = fullMatch.indexOf('(');
      final closeParen = fullMatch.lastIndexOf(')');
      if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
        final uri = fullMatch.substring(openParen + 1, closeParen).trim();
        if (uri.isNotEmpty && !seenUris.contains(uri)) {
          seenUris.add(uri);
          items.add(EditorialAttachmentItem.image(
            uri: uri,
            title: (alt != null && alt.isNotEmpty) ? alt : null,
          ));
        }
      }
    }

    // 2. Scan for scanned documents: [title](qp://document/<id>)
    for (final match in _documentRegex.allMatches(body)) {
      final rawTitle = match.group(1)?.trim() ?? '';
      final docId = match.group(2)?.trim() ?? '';
      if (docId.isNotEmpty) {
        final uri = 'qp://document/$docId';
        if (!seenUris.contains(uri)) {
          seenUris.add(uri);
          final cleanTitle = NoteMetadataExtractor.cleanMarkdownLine(rawTitle);
          items.add(EditorialAttachmentItem.pdf(
            uri: uri,
            title: cleanTitle.isNotEmpty ? cleanTitle : 'Document',
            label: 'PDF',
          ));
        }
      }
    }

    // 3. Scan for PDF file links: [title](url.pdf)
    for (final match in _pdfLinkRegex.allMatches(body)) {
      final rawTitle = match.group(1)?.trim() ?? '';
      final fullMatch = match.group(0) ?? '';
      final openParen = fullMatch.indexOf('(');
      final closeParen = fullMatch.lastIndexOf(')');
      if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
        final uri = fullMatch.substring(openParen + 1, closeParen).trim();
        if (uri.isNotEmpty && !seenUris.contains(uri)) {
          seenUris.add(uri);
          final cleanTitle = NoteMetadataExtractor.cleanMarkdownLine(rawTitle);
          items.add(EditorialAttachmentItem.pdf(
            uri: uri,
            title: cleanTitle.isNotEmpty ? cleanTitle : 'PDF Document',
            label: 'PDF',
          ));
        }
      }
    }

    // 4. Scan for generic asset links: [title](qp://asset/<id>)
    for (final match in _genericAssetRegex.allMatches(body)) {
      final rawTitle = match.group(1)?.trim() ?? '';
      final assetId = match.group(2)?.trim() ?? '';
      if (assetId.isNotEmpty) {
        final uri = 'qp://asset/$assetId';
        if (!seenUris.contains(uri)) {
          seenUris.add(uri);
          final cleanTitle = NoteMetadataExtractor.cleanMarkdownLine(rawTitle);
          final lower = cleanTitle.toLowerCase();

          if (lower.endsWith('.pdf') || lower.contains('pdf')) {
            items.add(EditorialAttachmentItem.pdf(
              uri: uri,
              title: cleanTitle.isNotEmpty ? cleanTitle : 'PDF Document',
              label: 'PDF',
            ));
          } else {
            final dotIdx = cleanTitle.lastIndexOf('.');
            if (dotIdx != -1 && dotIdx < cleanTitle.length - 1) {
              final ext = cleanTitle.substring(dotIdx + 1).toLowerCase();
              if (_textExtensions.contains(ext)) {
                final badge = ext == 'markdown'
                    ? 'MD'
                    : (ext.length <= 4 ? ext.toUpperCase() : 'TXT');
                items.add(EditorialAttachmentItem.textFile(
                  uri: uri,
                  title: cleanTitle,
                  label: badge,
                ));
                continue;
              }
              items.add(EditorialAttachmentItem.generic(
                uri: uri,
                title: cleanTitle,
                label: ext.length <= 4 ? ext.toUpperCase() : 'FILE',
              ));
              continue;
            }
            items.add(EditorialAttachmentItem.generic(
              uri: uri,
              title: cleanTitle.isNotEmpty ? cleanTitle : 'Attachment',
              label: 'FILE',
            ));
          }
        }
      }
    }

    _cacheResult(cacheKey, items);
    return items;
  }

  static void _cacheResult(String key, List<EditorialAttachmentItem> items) {
    if (_cache.length >= maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = items;
  }
}
