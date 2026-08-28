import 'package:flutter/foundation.dart';
import 'note_model.dart';
import 'notes_sort.dart';

/// Keyset pagination cursor encoding deterministic continuation values
@immutable
class NotesCursor {
  const NotesCursor({
    required this.lastNoteId,
    this.lastUpdatedAt,
    this.lastCreatedAt,
    this.lastTitle,
    this.lastIsPinned,
  });

  final String lastNoteId;
  final DateTime? lastUpdatedAt;
  final DateTime? lastCreatedAt;
  final String? lastTitle;
  final bool? lastIsPinned;

  /// Creates a cursor from the last note in a loaded batch according to the active sort
  factory NotesCursor.fromNote(Note note, NotesSort sort) {
    return NotesCursor(
      lastNoteId: note.id,
      lastUpdatedAt: note.updatedAt,
      lastCreatedAt: note.createdAt,
      lastTitle: note.title.trim().toLowerCase(),
      lastIsPinned: note.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastNoteId': lastNoteId,
      if (lastUpdatedAt != null) 'lastUpdatedAt': lastUpdatedAt!.toIso8601String(),
      if (lastCreatedAt != null) 'lastCreatedAt': lastCreatedAt!.toIso8601String(),
      if (lastTitle != null) 'lastTitle': lastTitle,
      if (lastIsPinned != null) 'lastIsPinned': lastIsPinned,
    };
  }

  factory NotesCursor.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['lastNoteId'] == null) {
      throw const FormatException('Invalid cursor JSON: missing lastNoteId');
    }
    return NotesCursor(
      lastNoteId: json['lastNoteId'] as String,
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? DateTime.tryParse(json['lastUpdatedAt'] as String)
          : null,
      lastCreatedAt: json['lastCreatedAt'] != null
          ? DateTime.tryParse(json['lastCreatedAt'] as String)
          : null,
      lastTitle: json['lastTitle'] as String?,
      lastIsPinned: json['lastIsPinned'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesCursor &&
          runtimeType == other.runtimeType &&
          lastNoteId == other.lastNoteId &&
          lastUpdatedAt == other.lastUpdatedAt &&
          lastCreatedAt == other.lastCreatedAt &&
          lastTitle == other.lastTitle &&
          lastIsPinned == other.lastIsPinned;

  @override
  int get hashCode =>
      lastNoteId.hashCode ^
      lastUpdatedAt.hashCode ^
      lastCreatedAt.hashCode ^
      lastTitle.hashCode ^
      lastIsPinned.hashCode;

  @override
  String toString() =>
      'NotesCursor(id: $lastNoteId, updated: $lastUpdatedAt, created: $lastCreatedAt, title: $lastTitle, pinned: $lastIsPinned)';
}
