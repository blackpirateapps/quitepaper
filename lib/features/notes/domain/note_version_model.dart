import 'dart:convert';
import 'package:flutter/foundation.dart';

@immutable
class NoteVersion {
  const NoteVersion({
    required this.id,
    required this.noteId,
    required this.versionNumber,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    this.charCount = 0,
    this.wordCount = 0,
    this.deltaSummary,
    this.serverRevision = 0,
    this.isDirty = true,
    this.syncedAt,
  });

  final String id;
  final String noteId;
  final int versionNumber;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final int charCount;
  final int wordCount;
  final String? deltaSummary;
  final int serverRevision;
  final bool isDirty;
  final DateTime? syncedAt;

  /// Counts the total number of words in a Markdown document.
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  /// Computes a concise human-readable delta summary compared to a baseline.
  static String computeDeltaSummary({
    required String oldContent,
    required String newContent,
    required String oldTitle,
    required String newTitle,
    required List<String> oldTags,
    required List<String> newTags,
  }) {
    final summaries = <String>[];

    final oldWords = countWords(oldContent);
    final newWords = countWords(newContent);
    final wordDiff = newWords - oldWords;

    if (wordDiff > 0) {
      summaries.add('+$wordDiff ${wordDiff == 1 ? 'word' : 'words'}');
    } else if (wordDiff < 0) {
      summaries.add('$wordDiff ${wordDiff.abs() == 1 ? 'word' : 'words'}');
    }

    if (oldTitle.trim() != newTitle.trim()) {
      summaries.add('Title updated');
    }

    final oldTagSet = oldTags.toSet();
    final newTagSet = newTags.toSet();
    if (!setEquals(oldTagSet, newTagSet)) {
      summaries.add('Tags modified');
    }

    if (summaries.isEmpty) {
      final charDiff = newContent.length - oldContent.length;
      if (charDiff != 0) {
        summaries.add('${charDiff > 0 ? '+' : ''}$charDiff chars');
      } else {
        summaries.add('Content edited');
      }
    }

    return summaries.join(' • ');
  }

  NoteVersion copyWith({
    String? id,
    String? noteId,
    int? versionNumber,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    int? charCount,
    int? wordCount,
    String? deltaSummary,
    int? serverRevision,
    bool? isDirty,
    DateTime? syncedAt,
  }) {
    return NoteVersion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      versionNumber: versionNumber ?? this.versionNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      charCount: charCount ?? this.charCount,
      wordCount: wordCount ?? this.wordCount,
      deltaSummary: deltaSummary ?? this.deltaSummary,
      serverRevision: serverRevision ?? this.serverRevision,
      isDirty: isDirty ?? this.isDirty,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'versionNumber': versionNumber,
        'title': title,
        'content': content,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'charCount': charCount,
        'wordCount': wordCount,
        if (deltaSummary != null) 'deltaSummary': deltaSummary,
        'serverRevision': serverRevision,
        'isDirty': isDirty,
        if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
      };

  factory NoteVersion.fromJson(Map<String, dynamic> json) {
    return NoteVersion(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      versionNumber: json['versionNumber'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          (json['tagsJson'] != null
              ? (jsonDecode(json['tagsJson'] as String) as List)
                  .map((e) => e.toString())
                  .toList()
              : const []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      charCount: json['charCount'] as int? ?? 0,
      wordCount: json['wordCount'] as int? ?? 0,
      deltaSummary: json['deltaSummary'] as String?,
      serverRevision: json['serverRevision'] as int? ?? 0,
      isDirty: json['isDirty'] as bool? ?? false,
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteVersion &&
          id == other.id &&
          noteId == other.noteId &&
          versionNumber == other.versionNumber &&
          title == other.title &&
          content == other.content &&
          setEquals(tags.toSet(), other.tags.toSet()) &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      noteId.hashCode ^
      versionNumber.hashCode ^
      title.hashCode ^
      content.hashCode ^
      createdAt.hashCode;
}
