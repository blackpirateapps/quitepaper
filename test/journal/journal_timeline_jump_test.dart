import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/journal/domain/journal_date_helper.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/journal_all_entries_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_calendar_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_timeline_tile.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  for (final wrappedTitles in [false, true]) {
    testWidgets('archive jump reaches a distant lazy entry (wrapped: $wrappedTitles)', (tester) async {
      tester.view.physicalSize = const Size(700, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repository = DriftNotesRepository(db);
      await db.transaction(() async {
        for (var i = 0; i < 1005; i++) {
          final date = DateTime(2026, 11, 24 - i);
          final key = JournalDateHelper.toDateString(date);
          await repository.saveNote(Note(
            id: key,
            title: wrappedTitles
                ? '$key A long reflection on the changing seasons and the ordinary moments worth remembering from this day'
                : 'Entry $key',
            content: '---\njournal: true\ndate: $key\n---\n${i.isEven ? 'A reflection with enough words to wrap across lines in the timeline, keeping each day distinct.' : 'Brief reflection.'}',
            tags: wrappedTitles && i % 3 == 0 ? ['journal/2026', 'reflection'] : [],
            journalDate: key, createdAt: date, updatedAt: date,
          ));
        }
      });
      await tester.pumpWidget(ProviderScope(overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        calendarVisibleMonthProvider.overrideWith((ref) => (year: 2024, month: 6)),
        calendarSelectedDateProvider.overrideWith((ref) => '2024-06-15'),
      ], child: const MaterialApp(home: Scaffold(body: JournalAllEntriesView()))));
      await tester.pumpAndSettle();
      Finder tileFor(String id) => find.byWidgetPredicate(
        (widget) => widget is JournalTimelineTile && widget.note.id == id);
      expect(tileFor('2024-06-15'), findsNothing,
        reason: 'The target must initially be outside the lazy-built months.');
      final jump = tester.widget<JournalCalendarView>(find.byType(JournalCalendarView)).onShowInTimeline;
      await tester.tap(find.text('Show in All Entries'));

      Future<void> expectVisibleHighlight(String id) async {
        var visibleAndHighlighted = false;
        for (var frame = 0; frame < 500; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final finder = tileFor(id);
          if (finder.evaluate().isEmpty) continue;
          final tile = tester.widget<JournalTimelineTile>(finder);
          final rect = tester.getRect(finder);
          if (tile.isHighlighted && rect.top >= 48 && rect.bottom <= 700) {
            visibleAndHighlighted = true;
            break;
          }
        }
        expect(visibleAndHighlighted, isTrue,
          reason: '$id must be visible and highlighted, including with variable tile heights.');
        await tester.pumpAndSettle();
      }

      await expectVisibleHighlight('2024-06-15');
      // Exercise a subsequent jump in the opposite direction through the same
      // calendar callback, after the newer months have been lazily disposed.
      jump('2026-10-15', '2026-10-15');
      await expectVisibleHighlight('2026-10-15');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
