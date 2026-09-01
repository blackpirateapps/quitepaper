import '../../../features/notes/domain/note_model.dart';

/// Represents a chronological group of journal entries within a single calendar month.
class JournalMonthGroup {
  const JournalMonthGroup({
    required this.year,
    required this.month,
    required this.monthKey,
    required this.monthLabel,
    required this.entries,
  });

  final int year;
  final int month;
  final String monthKey; // e.g. "2026-09"
  final String monthLabel; // e.g. "SEPTEMBER 2026"
  final List<Note> entries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalMonthGroup &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          monthKey == other.monthKey &&
          monthLabel == other.monthLabel;

  @override
  int get hashCode =>
      year.hashCode ^
      month.hashCode ^
      monthKey.hashCode ^
      monthLabel.hashCode;
}
