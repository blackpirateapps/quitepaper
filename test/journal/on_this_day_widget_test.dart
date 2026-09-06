import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/on_this_day_view.dart';
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

  Widget createTestWidget({
    List<Override> overrides = const [],
    void Function(Note note)? onNoteSelected,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value([])),
        earliestJournalYearFutureProvider.overrideWith((ref) => Future.value(null)),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OnThisDayView(onNoteSelected: onNoteSelected),
        ),
      ),
    );
  }

  group('OnThisDayView Widget Tests', () {
    testWidgets('displays quiet empty state when no historical entries exist', (tester) async {
      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ON THIS DAY'), findsOneWidget);
      expect(find.text('Nothing from this date yet.'), findsOneWidget);
      expect(find.text('Your first entry here will appear next year.'), findsOneWidget);
    });

    testWidgets('renders historical entry cards with relative year labels and triggers selection', (tester) async {
      Note? selectedNote;

      final testEntries = [
        Note(
          id: 'j-2025',
          title: 'A year ago today',
          content: '---\njournal: true\ndate: 2025-09-01\n---\nA surprisingly productive day.',
          createdAt: DateTime(2025, 9, 1),
          updatedAt: DateTime(2025, 9, 1),
          journalDate: '2025-09-01',
        ),
        Note(
          id: 'j-2024',
          title: 'Two years ago today',
          content: '---\njournal: true\ndate: 2024-09-01\n---\nStarted working on a new project.',
          createdAt: DateTime(2024, 9, 1),
          updatedAt: DateTime(2024, 9, 1),
          journalDate: '2024-09-01',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value(testEntries)),
        ],
        onNoteSelected: (note) {
          selectedNote = note;
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('ON THIS DAY'), findsOneWidget);
      expect(find.text('September 1, 2025'), findsOneWidget);
      expect(find.text('A year ago today'), findsOneWidget);
      expect(find.text('September 1, 2024'), findsOneWidget);
      expect(find.text('Two years ago today'), findsOneWidget);

      // Tap on first entry
      await tester.tap(find.text('A year ago today'));
      await tester.pumpAndSettle();

      expect(selectedNote, isNotNull);
      expect(selectedNote!.id, 'j-2025');
    });

    testWidgets('displays historical memories section with correct period header, day grouping, and updated exact-date subtitle', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final refDate = DateTime(2026, 9, 3); // Current week is Aug 31 - Sep 6, 2026

      final testHistoricalNotes = [
        Note(
          id: 'hist-1',
          title: 'Historical Note 1',
          content: 'Working on memories.',
          createdAt: DateTime(2025, 9, 2),
          updatedAt: DateTime(2025, 9, 2),
          journalDate: '2025-09-02',
        ),
        Note(
          id: 'hist-2',
          title: 'Historical Note 2',
          content: 'Another day in September.',
          createdAt: DateTime(2025, 9, 5),
          updatedAt: DateTime(2025, 9, 5),
          journalDate: '2025-09-05',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          historicalReferenceDateProvider.overrideWithValue(refDate),
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value(testHistoricalNotes)),
        ],
      ));
      await tester.pumpAndSettle();

      // Exact-date section empty state has updated subtitle because historical memories exist
      expect(find.text('ON THIS DAY'), findsOneWidget);
      expect(find.text('Nothing from this date yet.'), findsOneWidget);
      expect(find.text('Your memories from this time in previous years appear below.'), findsOneWidget);

      // Historical section
      expect(find.text('THIS TIME IN PREVIOUS YEARS'), findsOneWidget);
      expect(find.text('August 31 – September 6, 2025'), findsOneWidget);
      expect(find.text('September 2'), findsOneWidget);
      expect(find.text('Historical Note 1'), findsOneWidget);
      expect(find.text('September 5'), findsOneWidget);
      expect(find.text('Historical Note 2'), findsOneWidget);
    });

    testWidgets('orders historical year groups newest to oldest and notes chronologically within year', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final refDate = DateTime(2026, 9, 3);

      final testHistoricalNotes = [
        Note(
          id: 'hist-2024',
          title: 'Note from 2024',
          content: 'Content 2024',
          createdAt: DateTime(2024, 9, 4),
          updatedAt: DateTime(2024, 9, 4),
          journalDate: '2024-09-04',
        ),
        Note(
          id: 'hist-2025-b',
          title: 'Late 2025 Note',
          content: 'Friday note',
          createdAt: DateTime(2025, 9, 5),
          updatedAt: DateTime(2025, 9, 5),
          journalDate: '2025-09-05',
        ),
        Note(
          id: 'hist-2025-a',
          title: 'Early 2025 Note',
          content: 'Tuesday note',
          createdAt: DateTime(2025, 9, 2),
          updatedAt: DateTime(2025, 9, 2),
          journalDate: '2025-09-02',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          historicalReferenceDateProvider.overrideWithValue(refDate),
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value(testHistoricalNotes)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('August 31 – September 6, 2025'), findsOneWidget);
      expect(find.text('August 31 – September 6, 2024'), findsOneWidget);

      // Verify 2025 appears before 2024 visually
      final pos2025 = tester.getTopLeft(find.text('August 31 – September 6, 2025')).dy;
      final pos2024 = tester.getTopLeft(find.text('August 31 – September 6, 2024')).dy;
      expect(pos2025, lessThan(pos2024));

      // Verify chronological ordering within 2025 (Early before Late)
      final posEarly = tester.getTopLeft(find.text('Early 2025 Note')).dy;
      final posLate = tester.getTopLeft(find.text('Late 2025 Note')).dy;
      expect(posEarly, lessThan(posLate));

      // Verify 2023 (empty year) is never rendered
      expect(find.text('August 31 – September 6, 2023'), findsNothing);
    });

    testWidgets('taps historical note and invokes onNoteSelected callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final refDate = DateTime(2026, 9, 3);
      Note? selectedNote;

      final testHistoricalNotes = [
        Note(
          id: 'target-note',
          title: 'Target Historical Note',
          content: 'Tappable content',
          createdAt: DateTime(2025, 9, 2),
          updatedAt: DateTime(2025, 9, 2),
          journalDate: '2025-09-02',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          historicalReferenceDateProvider.overrideWithValue(refDate),
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value(testHistoricalNotes)),
        ],
        onNoteSelected: (note) {
          selectedNote = note;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Target Historical Note'));
      await tester.pumpAndSettle();

      expect(selectedNote, isNotNull);
      expect(selectedNote!.id, 'target-note');
    });

    testWidgets('shows older memories button when earlier notes exist and triggers loadOlderMemories', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final refDate = DateTime(2026, 9, 3);

      final testHistoricalNotes = [
        Note(
          id: 'hist-2025',
          title: 'Note 2025',
          content: 'Content',
          createdAt: DateTime(2025, 9, 2),
          updatedAt: DateTime(2025, 9, 2),
          journalDate: '2025-09-02',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          historicalReferenceDateProvider.overrideWithValue(refDate),
          earliestJournalYearFutureProvider.overrideWith((ref) => Future.value(2018)), // 2018 < 2021 (older years exist)
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value(testHistoricalNotes)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Show older memories'), findsOneWidget);

      await tester.tap(find.text('Show older memories'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders error state gracefully preserving exact-date section', (tester) async {
      final testExactEntries = [
        Note(
          id: 'exact-1',
          title: 'Exact Note',
          content: 'Exact Content',
          createdAt: DateTime(2025, 9, 1),
          updatedAt: DateTime(2025, 9, 1),
          journalDate: '2025-09-01',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value(testExactEntries)),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.error('DB failure')),
        ],
      ));
      await tester.pumpAndSettle();

      // Exact-date note is preserved
      expect(find.text('Exact Note'), findsOneWidget);

      // Historical section shows error affordance
      expect(find.text('THIS TIME IN PREVIOUS YEARS'), findsOneWidget);
      expect(find.text("Couldn't load older memories."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Case 4: displays quiet empty states for both sections when neither has entries', (tester) async {
      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ON THIS DAY'), findsOneWidget);
      expect(find.text('Nothing from this date yet.'), findsOneWidget);
      expect(find.text('Your first entry here will appear next year.'), findsOneWidget);

      expect(find.text('THIS TIME IN PREVIOUS YEARS'), findsOneWidget);
      expect(find.text('Nothing from this time yet.'), findsOneWidget);
      expect(find.text('Your memories will appear here in future years.'), findsOneWidget);
    });

    testWidgets('excludes current year notes from historical week section', (tester) async {
      final refDate = DateTime(2026, 9, 3);

      final testNotes = [
        // Current year 2026 note - must be excluded!
        Note(
          id: 'current-year-note',
          title: 'Current Year Note',
          content: 'Written today in 2026',
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
          journalDate: '2026-09-02',
        ),
        // Previous year 2025 note - must be included!
        Note(
          id: 'previous-year-note',
          title: 'Previous Year Note',
          content: 'Written in 2025',
          createdAt: DateTime(2025, 9, 2),
          updatedAt: DateTime(2025, 9, 2),
          journalDate: '2025-09-02',
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        overrides: [
          historicalReferenceDateProvider.overrideWithValue(refDate),
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([])),
          historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value(testNotes)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Previous Year Note'), findsOneWidget);
      expect(find.text('Current Year Note'), findsNothing);
    });
  });
}

