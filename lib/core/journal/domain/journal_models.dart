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

/// Represents the 7 calendar dates comprising a week (Monday to Sunday).
class CalendarWeekRange {
  const CalendarWeekRange({
    required this.start,
    required this.end,
    required this.dates,
  });

  final DateTime start;
  final DateTime end;
  final List<DateTime> dates;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarWeekRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

/// Represents a historical week period projected into a specific previous calendar year.
class HistoricalWeekPeriod {
  const HistoricalWeekPeriod({
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.validDates,
    required this.validDateStrings,
    required this.periodLabel,
  });

  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> validDates;
  final List<String> validDateStrings;
  final String periodLabel; // e.g. "September 1–7, 2025"

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalWeekPeriod &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          periodLabel == other.periodLabel;

  @override
  int get hashCode => year.hashCode ^ periodLabel.hashCode;
}

/// Represents notes written on a single calendar day inside a historical week period.
class HistoricalDayGroup {
  const HistoricalDayGroup({
    required this.date,
    required this.dateString,
    required this.dayLabel,
    required this.entries,
  });

  final DateTime date;
  final String dateString; // e.g. "2025-09-02"
  final String dayLabel; // e.g. "September 2"
  final List<Note> entries;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalDayGroup &&
          runtimeType == other.runtimeType &&
          dateString == other.dateString &&
          entries.length == other.entries.length;

  @override
  int get hashCode => dateString.hashCode ^ entries.length.hashCode;
}

/// Represents a historical year group containing all day groups with entries for that year's period.
class HistoricalYearGroup {
  const HistoricalYearGroup({
    required this.period,
    required this.dayGroups,
  });

  final HistoricalWeekPeriod period;
  final List<HistoricalDayGroup> dayGroups;

  int get totalCount => dayGroups.fold(0, (sum, g) => sum + g.entries.length);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalYearGroup &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          dayGroups.length == other.dayGroups.length;

  @override
  int get hashCode => period.hashCode ^ dayGroups.length.hashCode;
}

/// Represents the UI state for the "This Time in Previous Years" historical section.
class HistoricalWeekState {
  const HistoricalWeekState({
    required this.yearGroups,
    required this.hasMoreOlderYears,
    required this.isLoading,
    required this.isLoadingOlder,
    this.errorMessage,
    this.loadedYearsCount = 5,
  });

  final List<HistoricalYearGroup> yearGroups;
  final bool hasMoreOlderYears;
  final bool isLoading;
  final bool isLoadingOlder;
  final String? errorMessage;
  final int loadedYearsCount;

  bool get isEmpty => yearGroups.isEmpty;
  bool get hasError => errorMessage != null;

  HistoricalWeekState copyWith({
    List<HistoricalYearGroup>? yearGroups,
    bool? hasMoreOlderYears,
    bool? isLoading,
    bool? isLoadingOlder,
    String? errorMessage,
    bool clearError = false,
    int? loadedYearsCount,
  }) {
    return HistoricalWeekState(
      yearGroups: yearGroups ?? this.yearGroups,
      hasMoreOlderYears: hasMoreOlderYears ?? this.hasMoreOlderYears,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadedYearsCount: loadedYearsCount ?? this.loadedYearsCount,
    );
  }

  static const initial = HistoricalWeekState(
    yearGroups: [],
    hasMoreOlderYears: false,
    isLoading: true,
    isLoadingOlder: false,
    errorMessage: null,
    loadedYearsCount: 5,
  );
}

