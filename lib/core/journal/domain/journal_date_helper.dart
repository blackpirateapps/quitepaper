import 'package:intl/intl.dart';

/// Centralized utility for normalizing, parsing, formatting, and comparing
/// calendar journal dates (YYYY-MM-DD) independent of timestamps or timezones.
abstract final class JournalDateHelper {
  static final RegExp _datePattern = RegExp(r'^\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])$');

  /// Normalizes a [DateTime] into a local calendar date string formatted as `YYYY-MM-DD`.
  static String toDateString(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns today's local calendar date string formatted as `YYYY-MM-DD`.
  static String todayString([DateTime? now]) {
    return toDateString(now ?? DateTime.now());
  }

  /// Normalizes a [DateTime] to midnight of its local calendar day (year, month, day, 0, 0, 0).
  static DateTime toLocalDate(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Validates whether [dateStr] is a strictly valid `YYYY-MM-DD` calendar date string.
  static bool isValidDateString(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    final trimmed = dateStr.trim();
    if (!_datePattern.hasMatch(trimmed)) return false;

    try {
      final parts = trimmed.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final parsed = DateTime(year, month, day);
      return parsed.year == year && parsed.month == month && parsed.day == day;
    } catch (_) {
      return false;
    }
  }

  /// Parses a normalized `YYYY-MM-DD` string into a local [DateTime] (midnight).
  /// Returns null if [dateStr] is invalid.
  static DateTime? tryParseDateString(String? dateStr) {
    if (!isValidDateString(dateStr)) return null;
    final parts = dateStr!.trim().split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  /// Formats a journal date string (or [DateTime]) into human-readable display string.
  /// E.g. "2026-09-01" -> "September 1, 2026".
  static String formatDisplayDate(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = toLocalDate(date);
    } else if (date is String) {
      dt = tryParseDateString(date);
    }
    if (dt == null) return date?.toString() ?? '';
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  /// Formats month and day without year (e.g. "September 1").
  static String formatMonthDay(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = toLocalDate(date);
    } else if (date is String) {
      dt = tryParseDateString(date);
    }
    if (dt == null) return date?.toString() ?? '';
    return DateFormat('MMMM d').format(dt);
  }

  /// Returns relative-year label comparing [historicalDate] with [currentDate].
  /// E.g., for reference date in 2026:
  /// - 2025 -> "A year ago"
  /// - 2024 -> "Two years ago"
  /// - 2023 -> "Three years ago"
  /// - 2021 -> "5 years ago"
  static String formatRelativeYear(
    dynamic historicalDate, {
    DateTime? currentDate,
  }) {
    final now = toLocalDate(currentDate ?? DateTime.now());
    DateTime? past;
    if (historicalDate is DateTime) {
      past = toLocalDate(historicalDate);
    } else if (historicalDate is String) {
      past = tryParseDateString(historicalDate);
    }

    if (past == null) return '';

    final yearDiff = now.year - past.year;
    if (yearDiff <= 0) return 'This year';
    if (yearDiff == 1) return 'A year ago';
    if (yearDiff == 2) return 'Two years ago';
    if (yearDiff == 3) return 'Three years ago';
    return '$yearDiff years ago';
  }

  /// Whether a given calendar [year] is a leap year.
  static bool isLeapYear(int year) {
    if (year % 400 == 0) return true;
    if (year % 100 == 0) return false;
    return year % 4 == 0;
  }

  /// Checks if [historicalDate] matches the month and day of [referenceDate],
  /// occurred strictly before [referenceDate]'s year, and satisfies leap-day rules.
  static bool isOnThisDayMatch({
    required dynamic historicalDate,
    required dynamic referenceDate,
  }) {
    DateTime? hist;
    if (historicalDate is DateTime) {
      hist = toLocalDate(historicalDate);
    } else if (historicalDate is String) {
      hist = tryParseDateString(historicalDate);
    }

    DateTime? ref;
    if (referenceDate is DateTime) {
      ref = toLocalDate(referenceDate);
    } else if (referenceDate is String) {
      ref = tryParseDateString(referenceDate);
    }

    if (hist == null || ref == null) return false;

    // Must be strictly prior to reference year
    if (hist.year >= ref.year) return false;

    // Strict month and day match
    return hist.month == ref.month && hist.day == ref.day;
  }

  /// Formats month and year (e.g. "September 2026").
  static String formatMonthYear(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = toLocalDate(date);
    } else if (date is String) {
      dt = tryParseDateString(date);
    }
    if (dt == null) return date?.toString() ?? '';
    return DateFormat('MMMM yyyy').format(dt);
  }

  /// Formats uppercase month and year header for timeline grouping (e.g. "SEPTEMBER 2026").
  static String formatMonthYearHeader(int year, int month) {
    final dt = DateTime(year, month);
    return DateFormat('MMMM yyyy').format(dt).toUpperCase();
  }

  /// Formats full weekday name (e.g. "Tuesday").
  static String formatWeekday(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = toLocalDate(date);
    } else if (date is String) {
      dt = tryParseDateString(date);
    }
    if (dt == null) return '';
    return DateFormat('EEEE').format(dt);
  }

  /// Formats short weekday name (e.g. "Tue").
  static String formatWeekdayShort(dynamic date) {
    DateTime? dt;
    if (date is DateTime) {
      dt = toLocalDate(date);
    } else if (date is String) {
      dt = tryParseDateString(date);
    }
    if (dt == null) return '';
    return DateFormat('E').format(dt);
  }

  /// Formats timeline entry time metadata (e.g. "Tuesday · 9:42 PM" or "Tuesday").
  static String formatTimelineEntryMetadata(dynamic journalDate, DateTime? updatedAt) {
    final weekday = formatWeekday(journalDate);
    if (updatedAt == null) return weekday;
    final timeStr = DateFormat('h:mm a').format(updatedAt.toLocal());
    if (weekday.isEmpty) return timeStr;
    return '$weekday · $timeStr';
  }

  /// Returns the number of days in [month] for [year], accounting for leap years.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      return isLeapYear(year) ? 29 : 28;
    }
    if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    }
    return 31;
  }

  /// Returns the first weekday of [month] in [year] (1 = Monday, 7 = Sunday).
  static int firstWeekdayOfMonth(int year, int month) {
    return DateTime(year, month, 1).weekday;
  }

  /// Returns the previous month as a `({int year, int month})` record.
  static ({int year, int month}) previousMonth(int year, int month) {
    if (month == 1) return (year: year - 1, month: 12);
    return (year: year, month: month - 1);
  }

  /// Returns the next month as a `({int year, int month})` record.
  static ({int year, int month}) nextMonth(int year, int month) {
    if (month == 12) return (year: year + 1, month: 1);
    return (year: year, month: month + 1);
  }

  /// Returns a normalized month key string (e.g. "2026-09").
  static String monthKey(int year, int month) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Parses a month key string (e.g. "2026-09") into `({int year, int month})`.
  static ({int year, int month})? tryParseMonthKey(String? key) {
    if (key == null) return null;
    final parts = key.trim().split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return null;
    return (year: y, month: m);
  }

  /// Returns a 2-digit day number string (e.g. "01", "16", "31").
  static String formatDayTwoDigits(int day) {
    return day.toString().padLeft(2, '0');
  }
}
