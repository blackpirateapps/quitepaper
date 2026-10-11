import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quitepaper/core/journal/domain/journal_date_helper.dart';

/// Feature C — Journal Bengali dates & numerals (display-only, spec §5).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('bn', null);
  });

  group('Display formatting with the bn locale', () {
    test('formatMonthYear emits Bengali numerals and month names', () {
      final en = JournalDateHelper.formatMonthYear(DateTime(2026, 9));
      final bn = JournalDateHelper.formatMonthYear(DateTime(2026, 9),
          localeTag: 'bn');
      expect(bn, isNot(en));
      expect(bn, contains('২০২৬')); // Bengali numerals for 2026
      expect(bn, isNot(contains('2026'))); // no Western digits
    });

    test('formatDisplayDate localizes a yyyy-MM-dd string', () {
      final bn =
          JournalDateHelper.formatDisplayDate('2026-09-01', localeTag: 'bn');
      expect(bn, contains('২০২৬'));
    });

    test('formatMonthYearHeader localizes', () {
      final bn =
          JournalDateHelper.formatMonthYearHeader(2026, 9, localeTag: 'bn');
      expect(bn, contains('২০২৬'));
    });

    test('null localeTag keeps the English default', () {
      final en = JournalDateHelper.formatMonthYear(DateTime(2026, 9));
      expect(en, 'September 2026');
    });
  });

  group('Canonical keys/storage stay ASCII regardless of setting', () {
    test('toDateString is always ASCII yyyy-MM-dd', () {
      expect(JournalDateHelper.toDateString(DateTime(2026, 9, 1)), '2026-09-01');
    });

    test('monthKey is always ASCII yyyy-MM', () {
      expect(JournalDateHelper.monthKey(2026, 9), '2026-09');
    });

    test('tryParseDateString round-trips an ASCII key', () {
      final dt = JournalDateHelper.tryParseDateString('2026-09-01');
      expect(dt, DateTime(2026, 9, 1));
    });
  });
}
