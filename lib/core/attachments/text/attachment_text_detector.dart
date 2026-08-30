import 'package:flutter/foundation.dart';
import '../attachment_type_resolver.dart';

/// Formats and categories of text attachments supported by Quiet Paper.
enum TextAttachmentFormat {
  plainText,
  markdown,
  csv,
  tsv,
  json,
  yaml,
  xml,
  toml,
  log,
  config,
  sourceCode,
  unknownText,
  binary,
}

/// Central detector for classifying attachment payloads as text vs binary,
/// and resolving specific text format semantics (monospaced, line numbers, word wrap).
class AttachmentTextDetector {
  const AttachmentTextDetector._();

  static const Set<String> _plainTextExts = {'txt', 'text'};
  static const Set<String> _markdownExts = {'md', 'markdown', 'mdown'};
  static const Set<String> _csvExts = {'csv'};
  static const Set<String> _tsvExts = {'tsv'};
  static const Set<String> _jsonExts = {'json', 'jsonl'};
  static const Set<String> _yamlExts = {'yaml', 'yml'};
  static const Set<String> _xmlExts = {'xml'};
  static const Set<String> _tomlExts = {'toml'};
  static const Set<String> _logExts = {'log'};
  static const Set<String> _configExts = {'conf', 'ini', 'env', 'cfg', 'properties', 'editorconfig', 'gitignore'};
  static const Set<String> _sourceCodeExts = {
    'dart', 'py', 'js', 'ts', 'jsx', 'tsx', 'java', 'kt', 'kts', 'swift',
    'rs', 'go', 'c', 'h', 'cpp', 'hpp', 'cc', 'hh', 'cs', 'php', 'rb',
    'sh', 'bash', 'zsh', 'sql', 'html', 'htm', 'css', 'scss', 'sass', 'less',
    'lua', 'scala', 'r', 'm', 'mm', 'pl', 'pm', 'graphql', 'proto', 'diff', 'patch'
  };

  static const Set<String> _binaryExts = {
    'zip', 'tar', 'gz', 'tgz', '7z', 'rar', 'bz2', 'xz',
    'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'pdf',
    'exe', 'dll', 'so', 'dylib', 'bin', 'dat', 'iso', 'img', 'apk', 'aab', 'dmg',
    'mp3', 'wav', 'm4a', 'ogg', 'flac', 'aac', 'wma',
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv',
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'ico', 'heic',
    'ttf', 'otf', 'woff', 'woff2'
  };

  /// Detects the text format of an attachment based on filename, MIME type, and byte contents.
  static TextAttachmentFormat detectFormat({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final ext = AttachmentTypeResolver.inferExtension(fileName, mimeType: mimeType).toLowerCase();
    final normMime = (mimeType ?? '').toLowerCase().trim();

    // 1. If known binary extension or binary MIME type, classify as binary
    if (_binaryExts.contains(ext) || _isNonTextMime(normMime)) {
      return TextAttachmentFormat.binary;
    }

    // 2. Check if the file extension maps to a known text format
    final extFormat = _formatFromExtension(ext);
    if (extFormat != null) {
      if (bytes.isEmpty) {
        return extFormat;
      }
      if (_isLikelyBinary(bytes)) {
        return TextAttachmentFormat.binary;
      }
      return extFormat;
    }

    // 3. For unknown extensions
    if (bytes.isEmpty) {
      if (AttachmentTypeResolver.isTextMime(normMime)) {
        return TextAttachmentFormat.unknownText;
      }
      // If extension is not empty and not recognized as text, default to binary
      if (ext.isNotEmpty) {
        return TextAttachmentFormat.binary;
      }
      return TextAttachmentFormat.unknownText;
    }

    if (_isLikelyBinary(bytes)) {
      return TextAttachmentFormat.binary;
    }

    return TextAttachmentFormat.unknownText;
  }

  static bool _isNonTextMime(String mime) {
    if (mime.isEmpty) return false;
    if (mime.startsWith('image/') ||
        mime.startsWith('video/') ||
        mime.startsWith('audio/') ||
        mime.startsWith('font/')) {
      return true;
    }
    if (mime == 'application/pdf' ||
        mime == 'application/zip' ||
        mime == 'application/x-tar' ||
        mime == 'application/gzip' ||
        mime == 'application/x-7z-compressed' ||
        mime == 'application/octet-stream' ||
        mime.contains('officedocument') ||
        mime.contains('msword') ||
        mime.contains('ms-excel') ||
        mime.contains('ms-powerpoint')) {
      return true;
    }
    return false;
  }

  static TextAttachmentFormat? _formatFromExtension(String ext) {
    if (_markdownExts.contains(ext)) return TextAttachmentFormat.markdown;
    if (_plainTextExts.contains(ext)) return TextAttachmentFormat.plainText;
    if (_csvExts.contains(ext)) return TextAttachmentFormat.csv;
    if (_tsvExts.contains(ext)) return TextAttachmentFormat.tsv;
    if (_jsonExts.contains(ext)) return TextAttachmentFormat.json;
    if (_yamlExts.contains(ext)) return TextAttachmentFormat.yaml;
    if (_xmlExts.contains(ext)) return TextAttachmentFormat.xml;
    if (_tomlExts.contains(ext)) return TextAttachmentFormat.toml;
    if (_logExts.contains(ext)) return TextAttachmentFormat.log;
    if (_configExts.contains(ext)) return TextAttachmentFormat.config;
    if (_sourceCodeExts.contains(ext)) return TextAttachmentFormat.sourceCode;
    return null;
  }

  /// Inspects bytes for indicators of binary content:
  /// - Null bytes (\x00) (unless UTF-16 BOM is present)
  /// - High frequency of non-printable control characters (< 0x09 or 0x0E..0x1F)
  static bool _isLikelyBinary(Uint8List bytes) {
    if (bytes.isEmpty) return false;

    // Check for UTF-16 BOMs
    if (bytes.length >= 2) {
      if ((bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF)) {
        return false;
      }
    }

    // Sample up to first 8 KB
    final sampleLength = bytes.length < 8192 ? bytes.length : 8192;
    int controlCharCount = 0;

    for (int i = 0; i < sampleLength; i++) {
      final b = bytes[i];
      if (b == 0x00) {
        return true;
      }
      if ((b < 0x09) || (b > 0x0D && b < 0x20 && b != 0x1B)) {
        controlCharCount++;
      }
    }

    if (sampleLength > 0 && (controlCharCount / sampleLength) > 0.02) {
      return true;
    }

    return false;
  }

  /// Whether the format is readable text.
  static bool isTextFormat(TextAttachmentFormat format) {
    return format != TextAttachmentFormat.binary;
  }

  /// Whether the format should use a monospaced code font by default.
  static bool isMonospaced(TextAttachmentFormat format) {
    switch (format) {
      case TextAttachmentFormat.sourceCode:
      case TextAttachmentFormat.json:
      case TextAttachmentFormat.yaml:
      case TextAttachmentFormat.xml:
      case TextAttachmentFormat.toml:
      case TextAttachmentFormat.log:
      case TextAttachmentFormat.config:
      case TextAttachmentFormat.csv:
      case TextAttachmentFormat.tsv:
        return true;
      case TextAttachmentFormat.plainText:
      case TextAttachmentFormat.markdown:
      case TextAttachmentFormat.unknownText:
      case TextAttachmentFormat.binary:
        return false;
    }
  }

  /// Whether line numbers should be displayed by default for this format.
  static bool supportsLineNumbers(TextAttachmentFormat format) {
    switch (format) {
      case TextAttachmentFormat.sourceCode:
      case TextAttachmentFormat.json:
      case TextAttachmentFormat.yaml:
      case TextAttachmentFormat.xml:
      case TextAttachmentFormat.toml:
      case TextAttachmentFormat.log:
      case TextAttachmentFormat.config:
        return true;
      case TextAttachmentFormat.csv:
      case TextAttachmentFormat.tsv:
      case TextAttachmentFormat.plainText:
      case TextAttachmentFormat.markdown:
      case TextAttachmentFormat.unknownText:
      case TextAttachmentFormat.binary:
        return false;
    }
  }

  /// Default word wrap setting for this format.
  static bool defaultWordWrap(TextAttachmentFormat format) {
    switch (format) {
      case TextAttachmentFormat.plainText:
      case TextAttachmentFormat.markdown:
      case TextAttachmentFormat.unknownText:
        return true;
      case TextAttachmentFormat.sourceCode:
      case TextAttachmentFormat.json:
      case TextAttachmentFormat.yaml:
      case TextAttachmentFormat.xml:
      case TextAttachmentFormat.toml:
      case TextAttachmentFormat.log:
      case TextAttachmentFormat.config:
      case TextAttachmentFormat.csv:
      case TextAttachmentFormat.tsv:
      case TextAttachmentFormat.binary:
        return false;
    }
  }

  /// Human-readable category label for UI.
  static String getCategoryLabel(TextAttachmentFormat format, {String? fileName}) {
    switch (format) {
      case TextAttachmentFormat.plainText:
        return 'Plain Text';
      case TextAttachmentFormat.markdown:
        return 'Markdown';
      case TextAttachmentFormat.csv:
        return 'CSV Spreadsheet';
      case TextAttachmentFormat.tsv:
        return 'TSV Spreadsheet';
      case TextAttachmentFormat.json:
        return 'JSON Document';
      case TextAttachmentFormat.yaml:
        return 'YAML Document';
      case TextAttachmentFormat.xml:
        return 'XML Document';
      case TextAttachmentFormat.toml:
        return 'TOML Document';
      case TextAttachmentFormat.log:
        return 'Log File';
      case TextAttachmentFormat.config:
        return 'Configuration File';
      case TextAttachmentFormat.sourceCode:
        if (fileName != null) {
          final ext = AttachmentTypeResolver.inferExtension(fileName).toLowerCase();
          final resolved = AttachmentTypeResolver.resolveDisplayName(mimeType: '', fileName: fileName);
          if (resolved != 'Unknown File' && !resolved.endsWith('File')) {
            return resolved;
          }
          if (ext.isNotEmpty) {
            return '${ext.toUpperCase()} Source';
          }
        }
        return 'Source Code';
      case TextAttachmentFormat.unknownText:
        return 'Text File';
      case TextAttachmentFormat.binary:
        return 'Generic File';
    }
  }
}
