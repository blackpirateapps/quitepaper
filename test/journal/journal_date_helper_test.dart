import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/journal/domain/journal_date_helper.dart';

void main() {
  group('JournalDateHelper Unit Tests', () {
    test('toDateString formats local DateTime to YYYY-MM-DD', () {
      final dt = DateTime(2026, 9, 1, 14, 30, 0);
      expect(JournalDateHelper.toDateString(dt), '2026-09-01');

      final dtLeap = DateTime(2024, 2, 29);
      expect(JournalDateHelper.toDateString(dtLeap), '2024-02-29');
    });

    test('todayString returns formatted today string', () {
      final now = DateTime(2026, 12, 25);
      expect(JournalDateHelper.todayString(now), '2026-12-25');
    });

    test('toLocalDate strips time components', () {
      final dt = DateTime(2026, 5, 10, 23, 59, 59);
      final local = JournalDateHelper.toLocalDate(dt);
      expect(local.year, 2026);
      expect(local.month, 5);
      expect(local.day, 10);
      expect(local.hour, 0);
      expect(local.minute, 0);
      expect(local.second, 0);
    });

    test('isValidDateString validates correct and malformed dates', () {
      expect(JournalDateHelper.isValidDateString('2026-09-01'), isTrue);
      expect(JournalDateHelper.isValidDateString('2024-02-29'), isTrue);
      expect(JournalDateHelper.isValidDateString('2023-02-29'), isFalse); // Not a leap year
      expect(JournalDateHelper.isValidDateString('2026-04-31'), isFalse); // April has 30 days
      expect(JournalDateHelper.isValidDateString('2026-13-01'), isFalse); // Month 13
      expect(JournalDateHelper.isValidDateString('2026-00-01'), isFalse); // Month 0
      expect(JournalDateHelper.isValidDateString('invalid-date'), isFalse);
      expect(JournalDateHelper.isValidDateString(''), isFalse);
      expect(JournalDateHelper.isValidDateString(null), isFalse);
    });

    test('tryParseDateString parses valid strings and returns null for invalid', () {
      final parsed = JournalDateHelper.tryParseDateString('2026-09-01');
      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 9);
      expect(parsed.day, 1);

      expect(JournalDateHelper.tryParseDateString('2026-02-30'), isNull);
      expect(JournalDateHelper.tryParseDateString('bad'), isNull);
    });

    test('formatDisplayDate formats date to full human readable string', () {
      expect(
        JournalDateHelper.formatDisplayDate('2026-09-01'),
        'September 1, 2026',
      );
      expect(
        JournalDateHelper.formatDisplayDate(DateTime(2025, 1, 15)),
        'January 15, 2025',
      );
    });

    test('formatMonthDay formats month and day without year', () {
      expect(JournalDateHelper.formatMonthDay('2026-09-01'), 'September 1');
      expect(JournalDateHelper.formatMonthDay(DateTime(2026, 12, 31)), 'December 31');
    });

    test('formatRelativeYear returns correct relative human labels', () {
      final now = DateTime(2026, 9, 1);

      expect(JournalDateHelper.formatRelativeYear('2025-09-01', currentDate: now), 'A year ago');
      expect(JournalDateHelper.formatRelativeYear('2024-09-01', currentDate: now), 'Two years ago');
      expect(JournalDateHelper.formatRelativeYear('2023-09-01', currentDate: now), 'Three years ago');
      expect(JournalDateHelper.formatRelativeYear('2021-09-01', currentDate: now), '5 years ago');
      expect(JournalDateHelper.formatRelativeYear('2026-09-01', currentDate: now), 'This year');
    });

    test('isLeapYear checks calendar leap years accurately', () {
      expect(JournalDateHelper.isLeapYear(2024), isTrue);
      expect(JournalDateHelper.isLeapYear(2000), isTrue);
      expect(JournalDateHelper.isLeapYear(1900), isFalse);
      expect(JournalDateHelper.isLeapYear(2026), isFalse);
    });

    test('isOnThisDayMatch checks historical match rules', () {
      final today = DateTime(2026, 9, 1);

      // Matches previous years
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2025-09-01',
          referenceDate: today,
        ),
        isTrue,
      );
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2024-09-01',
          referenceDate: today,
        ),
        isTrue,
      );

      // Does not match today itself
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2026-09-01',
          referenceDate: today,
        ),
        isFalse,
      );

      // Does not match future dates
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2027-09-01',
          referenceDate: today,
        ),
        isFalse,
      );

      // Does not match different day
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2025-09-02',
          referenceDate: today,
        ),
        isFalse,
      );

      // Leap day test
      final leapDay = DateTime(2024, 2, 29);
      expect(
        JournalDateHelper.isOnThisDayMatch(
          historicalDate: '2020-02-29',
          referenceDate: leapDay,
        ),
        isTrue,
      );
    });

    test('formatMonthYear formats month and year correctly', () {
      expect(JournalDateHelper.formatMonthYear(DateTime(2026, 9, 15)), 'September 2026');
      expect(JournalDateHelper.formatMonthYear('2026-09-15'), 'September 2026');
      expect(JournalDateHelper.formatMonthYear(DateTime(2025, 1, 1)), 'January 2025');
    });

    test('formatMonthYearHeader formats uppercase month and year header', () {
      expect(JournalDateHelper.formatMonthYearHeader(2026, 9), 'SEPTEMBER 2026');
      expect(JournalDateHelper.formatMonthYearHeader(2025, 12), 'DECEMBER 2025');
    });

    test('formatWeekday and formatWeekdayShort return correct names', () {
      final dt = DateTime(2026, 9, 1); // Tuesday
      expect(JournalDateHelper.formatWeekday(dt), 'Tuesday');
      expect(JournalDateHelper.formatWeekday('2026-09-01'), 'Tuesday');
      expect(JournalDateHelper.formatWeekdayShort(dt), 'Tue');
      expect(JournalDateHelper.formatWeekdayShort('2026-09-01'), 'Tue');
    });

    test('daysInMonth computes correct days including leap years', () {
      expect(JournalDateHelper.daysInMonth(2026, 1), 31);
      expect(JournalDateHelper.daysInMonth(2026, 2), 28); // Not a leap year
      expect(JournalDateHelper.daysInMonth(2024, 2), 29); // Leap year
      expect(JournalDateHelper.daysInMonth(2000, 2), 29); // Leap year
      expect(JournalDateHelper.daysInMonth(1900, 2), 28); // Not leap year
      expect(JournalDateHelper.daysInMonth(2026, 4), 30);
      expect(JournalDateHelper.daysInMonth(2026, 5), 31);
      expect(JournalDateHelper.daysInMonth(2026, 6), 30);
      expect(JournalDateHelper.daysInMonth(2026, 7), 31);
      expect(JournalDateHelper.daysInMonth(2026, 8), 31);
      expect(JournalDateHelper.daysInMonth(2026, 9), 30);
      expect(JournalDateHelper.daysInMonth(2026, 10), 31);
      expect(JournalDateHelper.daysInMonth(2026, 11), 30);
      expect(JournalDateHelper.daysInMonth(2026, 12), 31);
    });

    test('firstWeekdayOfMonth returns correct ISO weekday', () {
      // 2026-09-01 is a Tuesday (2)
      expect(JournalDateHelper.firstWeekdayOfMonth(2026, 9), 2);
      // 2026-08-01 is a Saturday (6)
      expect(JournalDateHelper.firstWeekdayOfMonth(2026, 8), 6);
      // 2026-03-01 is a Sunday (7)
      expect(JournalDateHelper.firstWeekdayOfMonth(2026, 3), 7);
    });

    test('previousMonth and nextMonth handle year wrap-around', () {
      expect(JournalDateHelper.previousMonth(2026, 9), (year: 2026, month: 8));
      expect(JournalDateHelper.previousMonth(2026, 1), (year: 2025, month: 12));

      expect(JournalDateHelper.nextMonth(2026, 9), (year: 2026, month: 10));
      expect(JournalDateHelper.nextMonth(2026, 12), (year: 2027, month: 1));
    });

    test('monthKey and tryParseMonthKey format and parse keys reliably', () {
      expect(JournalDateHelper.monthKey(2026, 9), '2026-09');
      expect(JournalDateHelper.monthKey(2026, 12), '2026-12');

      final parsed = JournalDateHelper.tryParseMonthKey('2026-09');
      expect(parsed, (year: 2026, month: 9));

      expect(JournalDateHelper.tryParseMonthKey(null), isNull);
      expect(JournalDateHelper.tryParseMonthKey('invalid'), isNull);
      expect(JournalDateHelper.tryParseMonthKey('2026-13'), isNull);
    });

    test('formatDayTwoDigits formats day string with leading zero', () {
      expect(JournalDateHelper.formatDayTwoDigits(1), '01');
      expect(JournalDateHelper.formatDayTwoDigits(9), '09');
      expect(JournalDateHelper.formatDayTwoDigits(16), '16');
      expect(JournalDateHelper.formatDayTwoDigits(31), '31');
    });

    test('formatTimelineEntryMetadata formats combined weekday and time', () {
      final updated = DateTime(2026, 9, 1, 21, 42);
      final meta = JournalDateHelper.formatTimelineEntryMetadata('2026-09-01', updated);
      expect(meta, contains('Tuesday'));
      expect(meta, contains('9:42 PM'));
    });
  });
}
