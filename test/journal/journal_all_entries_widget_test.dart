import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/journal/domain/journal_date_helper.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/journal_all_entries_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_calendar_view.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_month_year_picker.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_timeline_tile.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> finishTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Widget buildTestWidget({
    void Function(Note note)? onNoteSelected,
    bool isTablet = false,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: JournalAllEntriesView(
            onNoteSelected: onNoteSelected,
            isTablet: isTablet,
          ),
        ),
      ),
    );
  }

  group('JournalAllEntriesView Widget Tests', () {
    testWidgets('renders empty timeline state when no journal entries exist', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('All Entries'), findsOneWidget);
      expect(find.byType(JournalCalendarView), findsOneWidget);
      expect(find.text('No journal entries yet.'), findsOneWidget);
      expect(find.text('Write your first entry in Today.'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('renders month group headers and chronological timeline tiles', (tester) async {
      // Create entries in different months
      await repository.getOrCreateJournalEntry(DateTime(2026, 9, 1));
      await repository.getOrCreateJournalEntry(DateTime(2026, 9, 15));
      await repository.getOrCreateJournalEntry(DateTime(2026, 8, 20));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.byType(JournalTimelineTile), findsNWidgets(3));
      expect(find.text('September 1, 2026'), findsOneWidget);
      expect(find.text('September 15, 2026'), findsOneWidget);
      expect(find.text('August 20, 2026'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('tapping a calendar date with entry shows preview and Show in All Entries button', (tester) async {
      final sep15 = await repository.getOrCreateJournalEntry(DateTime(2026, 9, 15));
      await repository.saveNote(
        sep15.copyWith(
          title: 'A Beautiful Sunny Day',
          content: '---\njournal: true\ndate: 2026-09-15\n---\nWrote in the garden this morning.',
        ),
      );

      // Force calendar to view September 2026
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            calendarVisibleMonthProvider.overrideWith((ref) => (year: 2026, month: 9)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find day 15 in calendar grid and tap it
      final day15Finder = find.descendant(
        of: find.byType(JournalCalendarView),
        matching: find.text('15'),
      );
      expect(day15Finder, findsOneWidget);
      await tester.tap(day15Finder);
      await tester.pumpAndSettle();

      // Selected date preview should display note title and content snippet
      expect(find.text('A Beautiful Sunny Day'), findsAtLeastNWidgets(1));
      expect(find.text('Wrote in the garden this morning.'), findsAtLeastNWidgets(1));
      expect(find.text('Show in All Entries'), findsOneWidget);

      // Tap Show in All Entries -> collapses calendar
      await tester.tap(find.text('Show in All Entries'));
      await tester.pumpAndSettle();

      // Calendar should be collapsed
      expect(find.byTooltip('Collapse calendar'), findsNothing);

      await finishTest(tester);
    });

    testWidgets('tapping empty date shows No journal entry preview and does not create note', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            calendarVisibleMonthProvider.overrideWith((ref) => (year: 2026, month: 9)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap day 10 (empty)
      final day10Finder = find.descendant(
        of: find.byType(JournalCalendarView),
        matching: find.text('10'),
      );
      await tester.tap(day10Finder);
      await tester.pumpAndSettle();

      expect(find.text('No journal entry'), findsOneWidget);

      // Verify no note was created in database for 2026-09-10
      final entry = await repository.getJournalEntry('2026-09-10');
      expect(entry, isNull);

      await finishTest(tester);
    });

    testWidgets('collapsing and expanding calendar via header buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find collapse button in expanded calendar card
      final collapseBtnFinder = find.descendant(
        of: find.byType(JournalCalendarView),
        matching: find.byTooltip('Collapse calendar'),
      );
      expect(collapseBtnFinder, findsOneWidget);

      await tester.tap(collapseBtnFinder);
      await tester.pumpAndSettle();

      // Now collapsed header should be visible
      final currentMonthTitle = JournalDateHelper.formatMonthYear(DateTime.now());
      expect(find.text(currentMonthTitle), findsOneWidget);

      // Tap collapsed header to expand again
      await tester.tap(find.text(currentMonthTitle));
      await tester.pumpAndSettle();

      expect(collapseBtnFinder, findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('month navigation buttons navigate previous and next months', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            calendarVisibleMonthProvider.overrideWith((ref) => (year: 2026, month: 9)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);

      // Tap previous month
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);

      // Tap next month
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('month/year picker dialog allows jumping across years', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            calendarVisibleMonthProvider.overrideWith((ref) => (year: 2026, month: 9)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap month header to open picker
      await tester.tap(find.text('September 2026'));
      await tester.pumpAndSettle();

      expect(find.byType(JournalMonthYearPicker), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      // Tap previous year in dialog
      await tester.tap(find.byTooltip('Previous year'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);

      // Select 'December'
      await tester.tap(find.text('December'));
      await tester.pumpAndSettle();

      // Calendar should now be viewing December 2025
      expect(find.text('December 2025'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('tablet layout delegates note selection to onNoteSelected callback', (tester) async {
      final note = await repository.getOrCreateJournalEntry(DateTime(2026, 9, 1));
      Note? selectedNote;

      await tester.pumpWidget(
        buildTestWidget(
          isTablet: true,
          onNoteSelected: (n) => selectedNote = n,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the timeline tile
      await tester.tap(find.byType(JournalTimelineTile));
      await tester.pumpAndSettle();

      expect(selectedNote, isNotNull);
      expect(selectedNote!.id, note.id);

      await finishTest(tester);
    });
  });
}
