import '../domain/export_models.dart';

/// Centralized utility for generating clean, deterministic, filesystem-safe filenames.
class FilenameGenerator {
  const FilenameGenerator();

  /// Reserved Windows filenames that must not be used directly.
  static const Set<String> _reservedNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// Characters invalid on Windows, macOS, and Linux filesystems.
  static final RegExp _invalidCharsRegex = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// Safe maximum character length for the filename base (excluding extension).
  static const int maxBaseLength = 100;

  /// Sanitizes a raw string [title] into a clean filesystem-safe base name.
  static String sanitizeBaseName(String? title, {String fallback = 'Untitled'}) {
    if (title == null) return fallback;

    var cleaned = title.trim();
    if (cleaned.isEmpty) return fallback;

    // Replace invalid filesystem characters and path separators with dash or space
    cleaned = cleaned.replaceAll(RegExp(r'[/\\:]+'), ' - ');
    cleaned = cleaned.replaceAll(_invalidCharsRegex, ' ');

    // Normalize multiple spaces / dashes
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'(\s*-\s*)+'), ' - ');
    cleaned = cleaned.replaceAll(RegExp(r'^[-\s._]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[-\s._]+$'), '');

    if (cleaned.isEmpty) return fallback;

    // Check Windows reserved names
    final upper = cleaned.toUpperCase();
    if (_reservedNames.contains(upper)) {
      cleaned = '${cleaned}_Note';
    }

    // Apply safe max length
    if (cleaned.length > maxBaseLength) {
      cleaned = cleaned.substring(0, maxBaseLength).trimRight();
      cleaned = cleaned.replaceAll(RegExp(r'[-\s._]+$'), '');
    }

    return cleaned.isNotEmpty ? cleaned : fallback;
  }

  /// Generates a complete sanitized filename with appropriate extension for [format].
  static String generateFilename({
    required String? title,
    required ExportFormat format,
    String fallback = 'Untitled',
  }) {
    final base = sanitizeBaseName(title, fallback: fallback);
    return '$base.${format.extension}';
  }

  /// Generates a unique filename in a set of [existingFilenames], appending ` (2)`, ` (3)`, etc.
  static String generateUniqueFilename({
    required String? title,
    required ExportFormat format,
    required Set<String> existingFilenames,
    String fallback = 'Untitled',
  }) {
    return generateUniqueFilenameWithExtension(
      title: title,
      extension: format.extension,
      existingFilenames: existingFilenames,
      fallback: fallback,
    );
  }

  /// Generates a unique filename with arbitrary custom extension in [existingFilenames].
  static String generateUniqueFilenameWithExtension({
    required String? title,
    required String extension,
    required Set<String> existingFilenames,
    String fallback = 'attachment',
  }) {
    final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
    final base = sanitizeBaseName(title, fallback: fallback);
    final extPart = cleanExt.isNotEmpty ? '.$cleanExt' : '';
    var candidate = '$base$extPart';

    var counter = 2;
    while (existingFilenames.contains(candidate.toLowerCase())) {
      candidate = '$base ($counter)$extPart';
      counter++;
    }

    return candidate;
  }

  /// Generates a sanitized attachment filename with extension.
  static String sanitizeAttachmentFilename(
    String? rawName, {
    String fallback = 'attachment',
    String? fallbackExtension,
  }) {
    if (rawName == null || rawName.trim().isEmpty) {
      final ext = fallbackExtension != null && fallbackExtension.isNotEmpty
          ? (fallbackExtension.startsWith('.') ? fallbackExtension : '.$fallbackExtension')
          : '';
      return '$fallback$ext';
    }

    var clean = rawName.trim();
    final dotIndex = clean.lastIndexOf('.');
    String base;
    String ext;

    if (dotIndex != -1 && dotIndex > 0) {
      base = clean.substring(0, dotIndex);
      ext = clean.substring(dotIndex);
    } else {
      base = clean;
      ext = fallbackExtension != null
          ? (fallbackExtension.startsWith('.') ? fallbackExtension : '.$fallbackExtension')
          : '';
    }

    final sanitizedBase = sanitizeBaseName(base, fallback: fallback);
    final sanitizedExt = ext.replaceAll(_invalidCharsRegex, '').toLowerCase();

    return '$sanitizedBase$sanitizedExt';
  }
}
