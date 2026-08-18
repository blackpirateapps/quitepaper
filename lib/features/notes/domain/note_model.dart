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
    this.tags = const [],
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final List<String> tags;

  /// Returns display title or 'Untitled' if title is empty
  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    // Check if the first line of content can be a preview title
    final trimmedContent = content.trim();
    if (trimmedContent.isNotEmpty) {
      final firstLine = trimmedContent.split('\n').first.trim();
      final cleanFirstLine = firstLine
          .replaceAll(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'[*_~`]'), '')
          .trim();
      if (cleanFirstLine.isNotEmpty) {
        return cleanFirstLine;
      }
    }
    return 'Untitled';
  }

  /// Whether the title is considered empty (for subtle placeholder styling)
  bool get hasCustomTitle => title.trim().isNotEmpty;

  /// Returns a clean one or two line snippet of the note content (omitting headers / markers)
  String get previewSnippet {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';

    final lines = trimmed.split('\n');
    final cleanLines = <String>[];

    for (final line in lines) {
      final clean = line
          .replaceAll(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'^>\s*'), '')
          .replaceAll(RegExp(r'^[-*+]\s+'), '')
          .replaceAll(RegExp(r'^\d+\.\s+'), '')
          .replaceAll(RegExp(r'[*_~`#]'), '')
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
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
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
          listEquals(tags, other.tags);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      isPinned.hashCode ^
      tags.hashCode;
}
