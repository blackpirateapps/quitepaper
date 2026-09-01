import 'package:flutter/foundation.dart';
import 'note_metadata_extractor.dart';

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
    this.journalDate,
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
  final String? journalDate;

  /// Whether the note is classified as a journal entry
  bool get isJournal => journalDate != null && journalDate!.isNotEmpty;

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
  static String deriveTitle(String content) =>
      NoteMetadataExtractor.deriveTitle(content);

  /// Whether the title is considered empty (for subtle placeholder styling)
  bool get hasCustomTitle => title.trim().isNotEmpty;

  /// Returns a clean one or two line snippet of the note content (omitting headers / markers)
  String get previewSnippet => NoteMetadataExtractor.derivePreviewSnippet(
        content,
        title: title,
        isPasswordProtected: isPasswordProtected,
      );

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
    String? journalDate,
    bool clearJournalDate = false,
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
      journalDate: clearJournalDate ? null : (journalDate ?? this.journalDate),
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
          journalDate == other.journalDate &&
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
      journalDate.hashCode ^
      tags.hashCode;
}
