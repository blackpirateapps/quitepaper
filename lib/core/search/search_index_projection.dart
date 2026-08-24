import 'package:flutter/foundation.dart';
import '../../features/notes/domain/note_model.dart';
import 'markdown_offset_mapper.dart';

/// Projected fields ready for insertion into SQLite FTS5 index tables.
@immutable
class NoteSearchProjection {
  final String noteId;
  final String title;
  final String bodyText;
  final String tags;

  const NoteSearchProjection({
    required this.noteId,
    required this.title,
    required this.bodyText,
    required this.tags,
  });

  static const NoteSearchProjection empty = NoteSearchProjection(
    noteId: '',
    title: '',
    bodyText: '',
    tags: '',
  );
}

/// Centralized projection rules determining what content is searchable in FTS.
class SearchIndexProjection {
  const SearchIndexProjection();

  /// Whether the note is eligible for inclusion in the search index.
  static bool shouldIndexNote({
    required bool isTrashed,
    DateTime? deletedAt,
  }) {
    if (isTrashed || deletedAt != null) {
      return false;
    }
    return true;
  }

  /// Whether the note is password protected with a private custom password.
  static bool isPasswordProtected(String content) {
    return content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:');
  }

  /// Projects a note into its indexed title representation.
  static String projectTitle(String title, String content) {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return Note.deriveTitle(content);
  }

  /// Projects a note's content into normalized searchable body text.
  /// Password protected notes return an empty string to preserve local privacy.
  static String projectBody(String content) {
    if (isPasswordProtected(content)) {
      return '';
    }
    return MarkdownOffsetMapper.normalize(content).normalizedText;
  }

  /// Projects tag names into searchable space-separated and prefixed tokens.
  static String projectTags(List<String> tags) {
    if (tags.isEmpty) return '';

    final buffer = StringBuffer();
    for (final tag in tags) {
      final clean = tag.trim().toLowerCase().replaceAll(RegExp(r'^#'), '');
      if (clean.isNotEmpty) {
        buffer.write('$clean #$clean ');
      }
    }
    return buffer.toString().trim();
  }

  /// Compiles a complete search projection for a note.
  static NoteSearchProjection project({
    required String noteId,
    required String title,
    required String content,
    required List<String> tags,
    required bool isTrashed,
    DateTime? deletedAt,
  }) {
    if (!shouldIndexNote(isTrashed: isTrashed, deletedAt: deletedAt)) {
      return NoteSearchProjection(
        noteId: noteId,
        title: '',
        bodyText: '',
        tags: '',
      );
    }

    final pTitle = projectTitle(title, content);
    final pBody = projectBody(content);
    final pTags = projectTags(tags);

    return NoteSearchProjection(
      noteId: noteId,
      title: pTitle,
      bodyText: pBody,
      tags: pTags,
    );
  }
}
