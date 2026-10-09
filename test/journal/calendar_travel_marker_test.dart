import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/journal_all_entries_view.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

/// Builds a journal note with the given [date] (YYYY-MM-DD) and optional [moment].
Note _journalNote(String id, String date, {String? moment, String title = 'Entry'}) {
  final momentLine = moment != null ? 'moment: $moment\n' : '';
  final dt = DateTime.parse(date);
  return Note(
    id: id,
    title: title,
    content: '---\njournal: true\ndate: $date\n$momentLine---\nBody for $date.',
    createdAt: dt,
    updatedAt: dt,
    journalDate: date,
  );
}

void main() {
  setUp(() {
    NoteMetadataExtractor.clearCache();
  });

  group('travelDatesForMonthProvider (§2.4)', () {
    test('returns only the dates in the month whose entry is moment: travel', () async {
      final notes = [
        _journalNote('n-travel', '2026-09-10', moment: 'travel'),
        _journalNote('n-ordinary', '2026-09-15', moment: 'ordinary'),
        _journalNote('n-none', '2026-09-20'), // no moment
        _journalNote('n-other-month', '2026-08-05', moment: 'travel'),
      ];

      final container = ProviderContainer(
        overrides: [
          allJournalEntriesStreamProvider.overrideWith((ref) => Stream.value(notes)),
        ],
      );
      addTearDown(container.dispose);

      // Resolve the underlying stream first.
      await container.read(allJournalEntriesStreamProvider.future);

      final september = container.read(travelDatesForMonthProvider((year: 2026, month: 9)));
      expect(september, {'2026-09-10'});

      final august = container.read(travelDatesForMonthProvider((year: 2026, month: 8)));
      expect(august, {'2026-08-05'});
    });

    test('is empty when the entries stream is still loading', () {
      final container = ProviderContainer(
        overrides: [
          allJournalEntriesStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(travelDatesForMonthProvider((year: 2026, month: 9)));
      expect(result, isEmpty);
    });
  });

  group('Calendar travel marker (Feature 2)', () {
    late AppDatabase db;
    late DriftNotesRepository repository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> finishTest(WidgetTester tester) async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          calendarVisibleMonthProvider.overrideWith((ref) => (year: 2026, month: 9)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: JournalAllEntriesView(),
          ),
        ),
      );
    }

    // Finders keyed off the marker's shape/weight (single accent color only).
    final ringFinder = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle && d.border != null;
    });
    final filledDotFinder = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration &&
          d.shape == BoxShape.circle &&
          d.border == null &&
          d.color != null &&
          d.color != Colors.transparent;
    });

    Future<void> seedEntries() async {
      final travel = await repository.getOrCreateJournalEntry(DateTime(2026, 9, 10));
      await repository.saveNote(
        travel.copyWith(
          title: 'Trip to Kolkata',
          content: '---\njournal: true\ndate: 2026-09-10\nmoment: travel\n---\nOn the road.',
        ),
      );
      final ordinary = await repository.getOrCreateJournalEntry(DateTime(2026, 9, 15));
      await repository.saveNote(
        ordinary.copyWith(
          title: 'A quiet day',
          content: '---\njournal: true\ndate: 2026-09-15\nmoment: ordinary\n---\nStayed in.',
        ),
      );
    }

    testWidgets('travel day renders a hollow ring and its semantics mention travel', (tester) async {
      await seedEntries();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Exactly one travel ring (day 10) and one plain filled dot (day 15).
      expect(ringFinder, findsOneWidget);
      expect(filledDotFinder, findsOneWidget);

      // Travel semantics label carries the travel suffix.
      final travelSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.contains(', travel') ?? false),
      );
      expect(travelSemantics, findsOneWidget);
      final travelWidget = tester.widget<Semantics>(travelSemantics);
      expect(travelWidget.properties.label, contains('September 10, 2026'));
      expect(travelWidget.properties.label, contains('journal entry exists'));

      await finishTest(tester);
    });

    testWidgets('non-travel entry day is a plain filled dot and its semantics omit travel', (tester) async {
      await seedEntries();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final day15Semantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.contains('September 15, 2026') ?? false) &&
            (w.properties.label?.contains('journal entry') ?? false),
      );
      expect(day15Semantics, findsOneWidget);
      final label = tester.widget<Semantics>(day15Semantics).properties.label!;
      expect(label, contains('journal entry exists'));
      expect(label, isNot(contains('travel')));

      await finishTest(tester);
    });

    testWidgets('a day with no entry shows no marker and reports no journal entry', (tester) async {
      await seedEntries();

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Only the two seeded entries produce markers: one ring + one dot, nothing else.
      expect(ringFinder, findsOneWidget);
      expect(filledDotFinder, findsOneWidget);

      final emptyDaySemantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.contains('September 12, 2026') ?? false),
      );
      expect(emptyDaySemantics, findsOneWidget);
      final label = tester.widget<Semantics>(emptyDaySemantics).properties.label!;
      expect(label, contains('no journal entry'));
      expect(label, isNot(contains('travel')));

      await finishTest(tester);
    });
  });
}
