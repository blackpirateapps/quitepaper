import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/journal/domain/journal_date_helper.dart';
import '../../notes/domain/note_model.dart';

/// A contiguous run of a place's entries, bounded by date gaps (§6.3).
///
/// A "visit" collects entries that are close together in time so that revisits
/// to the same place render as legible sub-headers in the drill-in timeline.
@immutable
class JournalVisit {
  const JournalVisit({
    required this.start,
    required this.end,
    required this.noteIds,
    required this.label,
    required this.entryCount,
  });

  /// Earliest entry date in the visit (local midnight).
  final DateTime start;

  /// Latest entry date in the visit (local midnight).
  final DateTime end;

  /// Member note ids, ordered newest-first to match the drill-in timeline.
  final List<String> noteIds;

  /// Human-facing sub-header, e.g. `October 2024` or `October 2024 – March 2026`.
  final String label;

  /// Number of entries in the visit.
  final int entryCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalVisit &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          label == other.label &&
          entryCount == other.entryCount &&
          listEquals(noteIds, other.noteIds);

  @override
  int get hashCode => Object.hash(
        start,
        end,
        label,
        entryCount,
        Object.hashAll(noteIds),
      );

  @override
  String toString() => 'JournalVisit($label, $entryCount entries)';
}

/// Default date gap (in days) that separates one visit from the next.
const int kVisitGapThresholdDays = 30;

/// Clusters a place's [reverseChronoNotes] into [JournalVisit]s by date gaps.
///
/// A gap strictly larger than [gapThresholdDays] between consecutive entries
/// (ordered chronologically) begins a new visit. Deterministic and pure: input
/// order does not matter — entries are sorted by resolved date then id before
/// clustering. The returned visits are ordered newest-first (by [JournalVisit.end]).
List<JournalVisit> clusterVisits(
  List<Note> reverseChronoNotes, {
  int gapThresholdDays = kVisitGapThresholdDays,
}) {
  if (reverseChronoNotes.isEmpty) return const [];

  final ascending = List<Note>.of(reverseChronoNotes)
    ..sort((a, b) {
      final cmp = _dateOf(a).compareTo(_dateOf(b));
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

  final visits = <JournalVisit>[];
  var clusterNotes = <Note>[ascending.first];
  var clusterStart = _dateOf(ascending.first);
  var previous = clusterStart;

  for (var i = 1; i < ascending.length; i++) {
    final note = ascending[i];
    final date = _dateOf(note);
    if (date.difference(previous).inDays > gapThresholdDays) {
      visits.add(_buildVisit(clusterNotes, clusterStart, previous));
      clusterNotes = <Note>[note];
      clusterStart = date;
    } else {
      clusterNotes.add(note);
    }
    previous = date;
  }
  visits.add(_buildVisit(clusterNotes, clusterStart, previous));

  // Newest visit first, matching the reverse-chronological drill-in timeline.
  visits.sort((a, b) => b.end.compareTo(a.end));
  return visits;
}

JournalVisit _buildVisit(List<Note> ascendingNotes, DateTime start, DateTime end) {
  // Member ids newest-first to mirror the drill-in timeline.
  final noteIds = ascendingNotes.reversed.map((n) => n.id).toList(growable: false);
  return JournalVisit(
    start: start,
    end: end,
    noteIds: noteIds,
    label: _labelFor(start, end),
    entryCount: ascendingNotes.length,
  );
}

String _labelFor(DateTime start, DateTime end) {
  final startLabel = DateFormat('MMMM yyyy').format(start);
  if (start.year == end.year && start.month == end.month) return startLabel;
  final endLabel = DateFormat('MMMM yyyy').format(end);
  return '$startLabel – $endLabel';
}

DateTime _dateOf(Note note) =>
    JournalDateHelper.tryParseDateString(note.journalDate) ??
    JournalDateHelper.toLocalDate(note.createdAt);
