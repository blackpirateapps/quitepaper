import 'package:path/path.dart' as p;

/// Centralized resolver for MIME detection, human-readable type labels,
/// extension derivation, and strict filename sanitization.
class AttachmentTypeResolver {
  const AttachmentTypeResolver._();

  /// Resolves a user-friendly, editorial type label for a given MIME type and filename.
  ///
  /// Examples:
  /// - `report.docx` -> "Microsoft Word"
  /// - `budget.xlsx` -> "Microsoft Excel"
  /// - `archive.zip` -> "ZIP Archive"
  /// - `script.py` -> "Python Source"
  /// - `image.png` -> "PNG Image"
  /// - `data.bin` -> "Binary File"
  static String resolveDisplayName({
    required String mimeType,
    required String fileName,
  }) {
    final ext = inferExtension(fileName, mimeType: mimeType).toLowerCase();
    final normMime = mimeType.toLowerCase().trim();

    // 1. Extension-based mapping (most specific for desktop & office formats)
    switch (ext) {
      case 'docx':
        return 'Microsoft Word';
      case 'doc':
        return 'Microsoft Word (.doc)';
      case 'xlsx':
        return 'Microsoft Excel';
      case 'xls':
        return 'Microsoft Excel (.xls)';
      case 'pptx':
        return 'PowerPoint';
      case 'ppt':
        return 'PowerPoint (.ppt)';
      case 'pdf':
        return 'PDF Document';
      case 'zip':
        return 'ZIP Archive';
      case 'tar':
      case 'gz':
      case 'tgz':
      case '7z':
      case 'rar':
        return 'Archive';
      case 'txt':
        return 'Text File';
      case 'md':
      case 'markdown':
        return 'Markdown Document';
      case 'csv':
        return 'CSV Spreadsheet';
      case 'json':
        return 'JSON Document';
      case 'yaml':
      case 'yml':
        return 'YAML Document';
      case 'xml':
        return 'XML Document';
      case 'dart':
        return 'Dart Source';
      case 'py':
        return 'Python Source';
      case 'js':
        return 'JavaScript Source';
      case 'ts':
        return 'TypeScript Source';
      case 'html':
      case 'htm':
        return 'HTML Document';
      case 'css':
        return 'CSS Stylesheet';
      case 'c':
      case 'cpp':
      case 'h':
      case 'hpp':
        return 'C/C++ Source';
      case 'java':
        return 'Java Source';
      case 'kt':
      case 'kts':
        return 'Kotlin Source';
      case 'swift':
        return 'Swift Source';
      case 'go':
        return 'Go Source';
      case 'rs':
        return 'Rust Source';
      case 'sh':
      case 'bash':
        return 'Shell Script';
      case 'sql':
      case 'sqlite':
      case 'db':
        return 'Database / SQL';
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'aac':
        return 'Audio File';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return 'Video File';
      case 'png':
        return 'PNG Image';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'webp':
        return 'WebP Image';
      case 'gif':
        return 'GIF Animation';
      case 'svg':
        return 'SVG Vector';
      case 'ttf':
      case 'otf':
      case 'woff':
      case 'woff2':
        return 'Font File';
      case 'bin':
      case 'dat':
        return 'Binary File';
    }

    // 2. MIME-based fallback mapping
    if (normMime.startsWith('image/')) {
      return 'Image';
    } else if (normMime == 'application/pdf') {
      return 'PDF Document';
    } else if (normMime.startsWith('audio/')) {
      return 'Audio File';
    } else if (normMime.startsWith('video/')) {
      return 'Video File';
    } else if (normMime.startsWith('text/')) {
      return 'Text Document';
    } else if (normMime.contains('zip') || normMime.contains('compressed') || normMime.contains('tar')) {
      return 'Archive';
    }

    if (ext.isNotEmpty) {
      return '${ext.toUpperCase()} File';
    }

    return 'Unknown File';
  }

  /// Infers standard MIME type from filename extension, with safe fallback.
  static String inferMimeType(String fileName) {
    final lower = fileName.toLowerCase().trim();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.tar')) return 'application/x-tar';
    if (lower.endsWith('.gz')) return 'application/gzip';
    if (lower.endsWith('.7z')) return 'application/x-7z-compressed';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'text/markdown';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'text/yaml';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.dart')) return 'application/vnd.dart';
    if (lower.endsWith('.py')) return 'text/x-python';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.ts')) return 'application/typescript';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.ttf')) return 'font/ttf';
    if (lower.endsWith('.otf')) return 'font/otf';

    return 'application/octet-stream';
  }

  /// Extracts clean extension without leading dot.
  static String inferExtension(String fileName, {String? mimeType}) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < fileName.length - 1) {
      final ext = fileName.substring(dotIndex + 1).trim().toLowerCase();
      // Only keep alphanumeric extensions under 12 chars
      if (RegExp(r'^[a-z0-9]{1,12}$').hasMatch(ext)) {
        return ext;
      }
    }

    if (mimeType != null && mimeType.isNotEmpty) {
      switch (mimeType.toLowerCase().trim()) {
        case 'image/jpeg':
        case 'image/jpg':
          return 'jpg';
        case 'image/png':
          return 'png';
        case 'image/webp':
          return 'webp';
        case 'image/gif':
          return 'gif';
        case 'image/svg+xml':
          return 'svg';
        case 'application/pdf':
          return 'pdf';
        case 'application/zip':
          return 'zip';
        case 'text/plain':
          return 'txt';
        case 'text/markdown':
          return 'md';
        case 'text/csv':
          return 'csv';
        case 'application/json':
          return 'json';
        case 'text/html':
          return 'html';
        case 'audio/mpeg':
          return 'mp3';
        case 'video/mp4':
          return 'mp4';
      }
    }

    return '';
  }

  /// Strictly sanitizes a user-supplied or picker-provided filename:
  /// - Strips path traversals (`../`, `..\`, `/`, `\`)
  /// - Strips null bytes and control characters
  /// - Replaces invalid characters with clean representations
  /// - Falls back to a safe default if blank
  static String sanitizeFileName(String rawFileName, {String fallback = 'attachment'}) {
    var cleaned = rawFileName.trim();

    // 1. Normalize all backslashes to forward slashes first
    cleaned = cleaned.replaceAll(r'\', '/');

    // 2. Strip full or relative paths to basename
    cleaned = p.posix.basename(cleaned);

    // 3. Remove path traversal patterns
    cleaned = cleaned.replaceAll(RegExp(r'(\.\./|\.\.)'), '');

    // 4. Remove path separators & control characters
    cleaned = cleaned.replaceAll(RegExp(r'[/\\:\*\?"<>\|\x00-\x1F]'), '_');

    // 5. Remove leading/trailing periods and spaces
    cleaned = cleaned.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');

    if (cleaned.isEmpty) {
      return fallback;
    }

    // Limit length to 200 chars
    if (cleaned.length > 200) {
      final ext = inferExtension(cleaned);
      if (ext.isNotEmpty) {
        final prefix = cleaned.substring(0, 190);
        cleaned = '$prefix.$ext';
      } else {
        cleaned = cleaned.substring(0, 200);
      }
    }

    return cleaned;
  }

  /// Validates whether a filename contains dangerous path traversal components.
  static bool isPathTraversal(String fileName) {
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        fileName.startsWith('.')) {
      return true;
    }
    return false;
  }

  /// Checks if MIME type is an image format.
  static bool isImageMime(String mimeType) {
    final lower = mimeType.toLowerCase().trim();
    return lower.startsWith('image/') && lower != 'image/svg+xml';
  }

  /// Checks if MIME type is a PDF format.
  static bool isPdfMime(String mimeType) {
    final lower = mimeType.toLowerCase().trim();
    return lower == 'application/pdf';
  }
}
