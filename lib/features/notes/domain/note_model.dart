import 'package:flutter/foundation.dart';

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.deletedAt,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final DateTime? deletedAt;
  final List<String> tags;

  /// Whether the note is active (not archived and not trashed)
  bool get isActive => !isArchived && !isTrashed;

  /// Whether the note is encrypted with a custom note password
  bool get isPasswordProtected =>
      content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:');

  /// Returns display title or 'Untitled' if title is empty
  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    final derived = deriveTitle(content);
    return derived.isNotEmpty ? derived : 'Untitled';
  }

  /// Derives a clean concise title from note content
  static String deriveTitle(String content) {
    if (content.isEmpty) return '';
    if (content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
      return '';
    }

    // Take at most first 300 characters to find first line quickly
    final sample = content.length > 300 ? content.substring(0, 300) : content;
    final trimmed = sample.trim();
    if (trimmed.isEmpty) return '';

    final newlineIdx = trimmed.indexOf('\n');
    final firstLine =
        newlineIdx != -1 ? trimmed.substring(0, newlineIdx).trim() : trimmed;
    final cleanFirstLine = firstLine
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'^>\s*'), '')
        .replaceAll(RegExp(r'^[-*+]\s+'), '')
        .replaceAll(RegExp(r'^\d+\.\s+'), '')
        .replaceAllMapped(RegExp(r'!\[(.*?)\]\(.*?\)'), (match) => 'image')
        .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) {
          final text = match.group(1)?.trim() ?? '';
          return text.isNotEmpty ? text : 'Document';
        })
        .replaceAll(RegExp(r'[*_~`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  /// Whether the title is considered empty (for subtle placeholder styling)
  bool get hasCustomTitle => title.trim().isNotEmpty;

  /// Returns a clean one or two line snippet of the note content (omitting headers / markers)
  String get previewSnippet {
    if (isPasswordProtected) {
      return '🔒 Password protected note';
    }
    if (content.isEmpty) return '';

    // Take at most first 600 characters for snippet preview to ensure instant rendering
    final sample = content.length > 600 ? content.substring(0, 600) : content;
    final trimmed = sample.trim();
    if (trimmed.isEmpty) return '';

    final lines = trimmed.split('\n');
    final cleanLines = <String>[];

    // If title was empty and first line was used as display title, start preview from 2nd line
    final startIndex = (title.trim().isEmpty && lines.length > 1) ? 1 : 0;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final clean = line
          .replaceAll(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'^>\s*'), '')
          .replaceAll(RegExp(r'^[-*+]\s+'), '')
          .replaceAll(RegExp(r'^\d+\.\s+'), '')
          .replaceAllMapped(RegExp(r'!\[(.*?)\]\(.*?\)'), (match) => 'image')
          .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) {
            final text = match.group(1)?.trim() ?? '';
            return text.isNotEmpty ? text : 'Document';
          })
          .replaceAll(RegExp(r'[*_~`#]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (clean.isNotEmpty) {
        cleanLines.add(clean);
      }
      if (cleanLines.length >= 2) break;
    }

    return cleanLines.join(' ');
  }

  /// Word count
  int get wordCount {
    final text = '$title $content'.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  /// Character count
  int get charCount => '$title $content'.length;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    bool? isTrashed,
    DateTime? deletedAt,
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      deletedAt: deletedAt ?? this.deletedAt,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isPinned == other.isPinned &&
          isArchived == other.isArchived &&
          isTrashed == other.isTrashed &&
          deletedAt == other.deletedAt &&
          listEquals(tags, other.tags);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      isPinned.hashCode ^
      isArchived.hashCode ^
      isTrashed.hashCode ^
      deletedAt.hashCode ^
      tags.hashCode;
}
