import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import '../../../core/journal/domain/journal_models.dart';
import 'journal_service.dart';

/// Provider for JournalService
final journalServiceProvider = Provider<JournalService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return JournalService(repository);
});

/// Current local calendar date for journal operations (YYYY-MM-DD)
final todayJournalDateProvider = Provider<String>((ref) {
  return JournalDateHelper.todayString();
});

/// Watches today's journal entry. Emits null if today's entry does not exist yet.
/// Note: Watching this provider does NOT create today's entry!
final todayJournalEntryStreamProvider = StreamProvider<Note?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final todayDate = ref.watch(todayJournalDateProvider);
  return repository.watchJournalEntry(todayDate);
});

/// Whether today's journal entry currently exists and is active.
final hasTodayJournalEntryProvider = Provider<bool>((ref) {
  final entry = ref.watch(todayJournalEntryStreamProvider).valueOrNull;
  return entry != null && !entry.isTrashed;
});

/// Watches On This Day entries (matching today's month and day from previous years).
final onThisDayEntriesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final now = DateTime.now();
  final localNow = JournalDateHelper.toLocalDate(now);

  return repository.watchOnThisDayEntries(
    month: localNow.month,
    day: localNow.day,
    beforeYear: localNow.year,
  );
});

/// Watches all active journal entries ordered chronologically (newest first).
final allJournalEntriesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchAllJournalEntries();
});

/// Groups active journal entries chronologically by Month/Year.
final journalMonthGroupsProvider = Provider<AsyncValue<List<JournalMonthGroup>>>((ref) {
  final entriesAsync = ref.watch(allJournalEntriesStreamProvider);

  return entriesAsync.whenData((entries) {
    if (entries.isEmpty) return const [];

    final groupsMap = <String, List<Note>>{};
    for (final note in entries) {
      final dateStr = note.journalDate;
      if (dateStr == null) continue;
      final parsed = JournalDateHelper.tryParseDateString(dateStr);
      if (parsed == null) continue;
      final mKey = JournalDateHelper.monthKey(parsed.year, parsed.month);
      groupsMap.putIfAbsent(mKey, () => []).add(note);
    }

    final groups = <JournalMonthGroup>[];
    for (final entry in groupsMap.entries) {
      final parsedKey = JournalDateHelper.tryParseMonthKey(entry.key);
      if (parsedKey == null) continue;
      final label = JournalDateHelper.formatMonthYearHeader(parsedKey.year, parsedKey.month);
      groups.add(
        JournalMonthGroup(
          year: parsedKey.year,
          month: parsedKey.month,
          monthKey: entry.key,
          monthLabel: label,
          entries: entry.value,
        ),
      );
    }

    return groups;
  });
});

/// Stream of active journal date strings for a specific month.
final journalDatesForMonthStreamProvider =
    StreamProvider.family<Set<String>, ({int year, int month})>((ref, arg) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchJournalDatesForMonth(arg.year, arg.month);
});

/// Currently visible month in the calendar (year, month).
final calendarVisibleMonthProvider =
    StateProvider<({int year, int month})>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

/// Currently selected date in the calendar (YYYY-MM-DD), or null if none.
final calendarSelectedDateProvider = StateProvider<String?>((ref) => null);

/// Whether the calendar card is collapsed in the All Entries view.
final calendarIsCollapsedProvider = StateProvider<bool>((ref) => false);

/// Watches the journal entry for the currently selected calendar date (if any).
final selectedDateJournalEntryProvider = StreamProvider<Note?>((ref) {
  final selectedDate = ref.watch(calendarSelectedDateProvider);
  if (selectedDate == null) return Stream.value(null);
  final repository = ref.watch(notesRepositoryProvider);
  return repository.watchJournalEntry(selectedDate);
});

/// Note ID of the journal entry temporarily highlighted in the timeline.
final highlightedJournalEntryIdProvider = StateProvider<String?>((ref) => null);
