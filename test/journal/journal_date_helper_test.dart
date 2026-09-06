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

    group('Historical Week Calculations & Formatting', () {
      test('getCurrentWeekRange computes Monday to Sunday range for standard week', () {
        // Wednesday Sep 3, 2025
        final midWeek = DateTime(2025, 9, 3);
        final range = JournalDateHelper.getCurrentWeekRange(midWeek);

        expect(range.start, DateTime(2025, 9, 1)); // Monday
        expect(range.end, DateTime(2025, 9, 7)); // Sunday
        expect(range.dates.length, 7);
        expect(range.dates.first, DateTime(2025, 9, 1));
        expect(range.dates.last, DateTime(2025, 9, 7));
      });

      test('getCurrentWeekRange handles cross-month and Sunday correctly', () {
        // Sunday Sep 6, 2026
        final sunday = DateTime(2026, 9, 6);
        final range = JournalDateHelper.getCurrentWeekRange(sunday);

        expect(range.start, DateTime(2026, 8, 31)); // Monday
        expect(range.end, DateTime(2026, 9, 6)); // Sunday
        expect(range.dates.length, 7);
        expect(range.dates.first, DateTime(2026, 8, 31));
        expect(range.dates.last, DateTime(2026, 9, 6));
      });

      test('getCurrentWeekRange handles week crossing year boundary', () {
        // Friday Jan 2, 2026
        final newYear = DateTime(2026, 1, 2);
        final range = JournalDateHelper.getCurrentWeekRange(newYear);

        expect(range.start, DateTime(2025, 12, 29)); // Monday
        expect(range.end, DateTime(2026, 1, 4)); // Sunday
        expect(range.dates.length, 7);
        expect(range.dates[0], DateTime(2025, 12, 29));
        expect(range.dates[1], DateTime(2025, 12, 30));
        expect(range.dates[2], DateTime(2025, 12, 31));
        expect(range.dates[3], DateTime(2026, 1, 1));
        expect(range.dates[4], DateTime(2026, 1, 2));
        expect(range.dates[5], DateTime(2026, 1, 3));
        expect(range.dates[6], DateTime(2026, 1, 4));
      });

      test('getHistoricalWeekPeriod projects standard week to previous year', () {
        final currentWeek = JournalDateHelper.getCurrentWeekRange(DateTime(2025, 9, 3));
        final period = JournalDateHelper.getHistoricalWeekPeriod(
          currentWeekRange: currentWeek,
          targetYear: 2024,
          referenceYear: 2025,
        );

        expect(period.year, 2024);
        expect(period.startDate, DateTime(2024, 9, 1));
        expect(period.endDate, DateTime(2024, 9, 7));
        expect(period.validDateStrings, [
          '2024-09-01',
          '2024-09-02',
          '2024-09-03',
          '2024-09-04',
          '2024-09-05',
          '2024-09-06',
          '2024-09-07',
        ]);
        expect(period.periodLabel, 'September 1–7, 2024');
      });

      test('getHistoricalWeekPeriod safely skips Feb 29 in non-leap historical year', () {
        // 2028 is a leap year; week covering Feb 26 - Mar 3 contains Feb 29
        final leapDate = DateTime(2028, 2, 29);
        final leapWeek = JournalDateHelper.getCurrentWeekRange(leapDate);
        expect(leapWeek.dates.any((d) => d.month == 2 && d.day == 29), isTrue);

        // Project into 2027 (not a leap year)
        final period = JournalDateHelper.getHistoricalWeekPeriod(
          currentWeekRange: leapWeek,
          targetYear: 2027,
          referenceYear: 2028,
        );

        // Feb 29 must be skipped, leaving 6 valid dates
        expect(period.validDates.any((d) => d.month == 2 && d.day == 29), isFalse);
        expect(period.validDateStrings.contains('2027-02-29'), isFalse);
        expect(period.startDate, DateTime(2027, 2, 28));
        expect(period.endDate, DateTime(2027, 3, 5));
        expect(period.periodLabel, 'February 28 – March 5, 2027');
      });

      test('getHistoricalWeekPeriod includes Feb 29 when projecting into leap year', () {
        // 2025 is non-leap; week covering Feb 26 - Mar 2
        final nonLeapDate = DateTime(2025, 2, 27);
        final week = JournalDateHelper.getCurrentWeekRange(nonLeapDate);

        // Project into 2024 (a leap year)
        final period = JournalDateHelper.getHistoricalWeekPeriod(
          currentWeekRange: week,
          targetYear: 2024,
          referenceYear: 2025,
        );

        expect(period.validDates.any((d) => d.month == 2 && d.day == 29), isTrue);
        expect(period.validDateStrings.contains('2024-02-29'), isTrue);
      });

      test('getHistoricalWeekPeriod projects cross-year week correctly', () {
        // Jan 2, 2026 week: Dec 29, 2025 - Jan 4, 2026
        final week = JournalDateHelper.getCurrentWeekRange(DateTime(2026, 1, 2));

        // Project to 2025
        final period = JournalDateHelper.getHistoricalWeekPeriod(
          currentWeekRange: week,
          targetYear: 2025,
          referenceYear: 2026,
        );

        expect(period.year, 2025);
        expect(period.startDate, DateTime(2024, 12, 29));
        expect(period.endDate, DateTime(2025, 1, 4));
        expect(period.validDateStrings, [
          '2024-12-29',
          '2024-12-30',
          '2024-12-31',
          '2025-01-01',
          '2025-01-02',
          '2025-01-03',
          '2025-01-04',
        ]);
        expect(period.periodLabel, 'December 29, 2024 – January 4, 2025');
      });

      test('formatPeriodRange formats same-month, cross-month, and cross-year properly', () {
        // Same month
        expect(
          JournalDateHelper.formatPeriodRange(
            DateTime(2025, 9, 1),
            DateTime(2025, 9, 7),
          ),
          'September 1–7, 2025',
        );

        // Cross month
        expect(
          JournalDateHelper.formatPeriodRange(
            DateTime(2025, 8, 31),
            DateTime(2025, 9, 6),
          ),
          'August 31 – September 6, 2025',
        );

        // Cross year
        expect(
          JournalDateHelper.formatPeriodRange(
            DateTime(2024, 12, 29),
            DateTime(2025, 1, 4),
          ),
          'December 29, 2024 – January 4, 2025',
        );
      });

      test('formatDayHeader formats day header cleanly', () {
        expect(JournalDateHelper.formatDayHeader(DateTime(2025, 9, 2)), 'September 2');
        expect(JournalDateHelper.formatDayHeader('2025-09-02'), 'September 2');
      });
    });
  });
}

