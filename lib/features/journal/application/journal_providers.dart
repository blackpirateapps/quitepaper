import 'dart:async';
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

/// Reference date used for historical queries and calculations (defaults to DateTime.now()).
/// Can be overridden in widget and unit tests for deterministic testing.
final historicalReferenceDateProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

/// Number of historical years to load (default: 5). Progressively increased in batches of 5.
final historicalLoadedYearsCountProvider = StateProvider<int>((ref) => 5);

/// Query descriptor for the active historical week request.
final historicalWeekQueryDescriptorProvider = Provider<({
  List<HistoricalWeekPeriod> periods,
  List<String> dateStrings,
  int referenceYear,
})>((ref) {
  final refDate = ref.watch(historicalReferenceDateProvider);
  final count = ref.watch(historicalLoadedYearsCountProvider);
  final localRef = JournalDateHelper.toLocalDate(refDate);
  final currentWeek = JournalDateHelper.getCurrentWeekRange(localRef);

  final periods = <HistoricalWeekPeriod>[];
  final dateStrings = <String>{};

  for (int i = 1; i <= count; i++) {
    final targetYear = localRef.year - i;
    final period = JournalDateHelper.getHistoricalWeekPeriod(
      currentWeekRange: currentWeek,
      targetYear: targetYear,
      referenceYear: localRef.year,
    );
    periods.add(period);
    dateStrings.addAll(period.validDateStrings);
  }

  return (
    periods: periods,
    dateStrings: dateStrings.toList(),
    referenceYear: localRef.year,
  );
});

/// Future provider for the earliest journal year in the database.
final earliestJournalYearFutureProvider = FutureProvider<int?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.getEarliestJournalYear();
});

/// Stream of notes matching the historical week date range.
final historicalWeekNotesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final descriptor = ref.watch(historicalWeekQueryDescriptorProvider);
  return repository.watchNotesForDates(descriptor.dateStrings);
});

/// Helper that transforms raw notes into reverse-chronological historical year groups.
List<HistoricalYearGroup> groupHistoricalNotes(
  List<Note> notes,
  List<HistoricalWeekPeriod> periods,
  int referenceYear,
) {
  final activeNotes = notes.where((n) {
    if (n.isTrashed) return false;
    final dStr = n.journalDate;
    if (dStr != null) {
      final parsed = JournalDateHelper.tryParseDateString(dStr);
      if (parsed != null && parsed.year >= referenceYear) return false;
    } else {
      if (n.createdAt.year >= referenceYear) return false;
    }
    return true;
  }).toList();

  final result = <HistoricalYearGroup>[];

  for (final period in periods) {
    final periodDateSet = period.validDateStrings.toSet();
    final seenNoteIds = <String>{};
    final periodNotes = <Note>[];

    for (final note in activeNotes) {
      final noteDateStr = note.journalDate ?? JournalDateHelper.toDateString(note.createdAt);
      if (periodDateSet.contains(noteDateStr)) {
        if (seenNoteIds.add(note.id)) {
          periodNotes.add(note);
        }
      }
    }

    if (periodNotes.isEmpty) continue;

    periodNotes.sort((a, b) {
      final aDateStr = a.journalDate ?? JournalDateHelper.toDateString(a.createdAt);
      final bDateStr = b.journalDate ?? JournalDateHelper.toDateString(b.createdAt);
      final cmp = aDateStr.compareTo(bDateStr);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });

    final dayMap = <String, List<Note>>{};
    for (final note in periodNotes) {
      final dateStr = note.journalDate ?? JournalDateHelper.toDateString(note.createdAt);
      dayMap.putIfAbsent(dateStr, () => []).add(note);
    }

    final dayGroups = <HistoricalDayGroup>[];
    for (final entry in dayMap.entries) {
      final parsed = JournalDateHelper.tryParseDateString(entry.key) ??
          JournalDateHelper.toLocalDate(entry.value.first.createdAt);
      final dayLabel = JournalDateHelper.formatDayHeader(parsed);
      dayGroups.add(
        HistoricalDayGroup(
          date: parsed,
          dateString: entry.key,
          dayLabel: dayLabel,
          entries: entry.value,
        ),
      );
    }

    result.add(
      HistoricalYearGroup(
        period: period,
        dayGroups: dayGroups,
      ),
    );
  }

  return result;
}

/// Provider for HistoricalWeekState consumed by OnThisDayView.
final historicalWeekProvider = Provider<HistoricalWeekState>((ref) {
  final descriptor = ref.watch(historicalWeekQueryDescriptorProvider);
  final notesAsync = ref.watch(historicalWeekNotesStreamProvider);
  final earliestYearAsync = ref.watch(earliestJournalYearFutureProvider);
  final count = ref.watch(historicalLoadedYearsCountProvider);

  final oldestQueriedYear = descriptor.referenceYear - count;
  final earliestYear = earliestYearAsync.valueOrNull;
  final hasMore = earliestYear != null && oldestQueriedYear > earliestYear;

  return notesAsync.when(
    data: (notes) {
      final yearGroups = groupHistoricalNotes(notes, descriptor.periods, descriptor.referenceYear);
      return HistoricalWeekState(
        yearGroups: yearGroups,
        hasMoreOlderYears: hasMore,
        isLoading: false,
        isLoadingOlder: false,
        loadedYearsCount: count,
      );
    },
    loading: () => HistoricalWeekState(
      yearGroups: const [],
      hasMoreOlderYears: hasMore,
      isLoading: true,
      isLoadingOlder: false,
      loadedYearsCount: count,
    ),
    error: (err, _) => HistoricalWeekState(
      yearGroups: const [],
      hasMoreOlderYears: hasMore,
      isLoading: false,
      isLoadingOlder: false,
      errorMessage: "Couldn't load older memories.",
      loadedYearsCount: count,
    ),
  );
});

/// Actions for interacting with the historical week memories state.
abstract final class HistoricalWeekActions {
  static void loadOlderMemories(WidgetRef ref) {
    ref.read(historicalLoadedYearsCountProvider.notifier).state += 5;
  }

  static void retry(WidgetRef ref) {
    ref.invalidate(historicalWeekNotesStreamProvider);
    ref.invalidate(earliestJournalYearFutureProvider);
  }
}

