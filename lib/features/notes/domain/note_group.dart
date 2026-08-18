import 'package:flutter/foundation.dart';
import '../../../core/utils/date_formatter.dart';
import 'note_model.dart';

@immutable
class NoteGroup {
  const NoteGroup({
    required this.header,
    required this.notes,
  });

  final String header;
  final List<Note> notes;

  /// Groups a list of notes by date buckets ("Today", "Yesterday", etc.)
  /// If [separatePinned] is true, pinned notes can either be grouped in their own "Pinned" group or kept at the top.
  static List<NoteGroup> groupByDate(
    List<Note> allNotes, {
    DateTime? now,
    bool separatePinned = true,
  }) {
    if (allNotes.isEmpty) return const [];

    final groups = <String, List<Note>>{};

    final pinnedNotes = <Note>[];
    final unpinnedNotes = <Note>[];

    for (final note in allNotes) {
      if (separatePinned && note.isPinned) {
        pinnedNotes.add(note);
      } else {
        unpinnedNotes.add(note);
      }
    }

    final result = <NoteGroup>[];

    if (pinnedNotes.isNotEmpty) {
      result.add(NoteGroup(header: 'Pinned', notes: pinnedNotes));
    }

    for (final note in unpinnedNotes) {
      final bucket = DateFormatter.getGroupBucket(note.updatedAt, now: now);
      groups.putIfAbsent(bucket, () => []).add(note);
    }

    for (final entry in groups.entries) {
      result.add(NoteGroup(header: entry.key, notes: entry.value));
    }

    return result;
  }
}
