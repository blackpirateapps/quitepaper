import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;
  late JournalService journalService;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
    journalService = JournalService(repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('JournalService Unit Tests', () {
    test('getOrCreateToday returns created note on first call and same note on second', () async {
      final now = DateTime(2026, 9, 1);
      final note1 = await journalService.getOrCreateToday(now);
      expect(note1.isJournal, isTrue);
      expect(note1.journalDate, '2026-09-01');

      final note2 = await journalService.getOrCreateToday(now);
      expect(note2.id, note1.id);
    });

    test('getJournalEntryForDate returns null when note not created and note when created', () async {
      final date = DateTime(2026, 9, 1);
      final before = await journalService.getJournalEntryForDate(date);
      expect(before, isNull);

      await journalService.getOrCreateToday(date);

      final after = await journalService.getJournalEntryForDate(date);
      expect(after, isNotNull);
      expect(after!.journalDate, '2026-09-01');
    });

    test('getOrCreateForDate backfills a historical entry and is idempotent per day', () async {
      final pastDate = DateTime(2019, 3, 14);

      final created = await journalService.getOrCreateForDate(pastDate);
      expect(created.isJournal, isTrue);
      expect(created.journalDate, '2019-03-14');

      // Same calendar date returns the same note (one-per-day invariant).
      final again = await journalService.getOrCreateForDate(DateTime(2019, 3, 14, 23, 59));
      expect(again.id, created.id);
    });

    test('getOnThisDayEntries returns only previous year matching entries', () async {
      // Historical entries
      final n2025 = await repository.getOrCreateJournalEntry(DateTime(2025, 9, 1));
      final n2024 = await repository.getOrCreateJournalEntry(DateTime(2024, 9, 1));

      final entries = await journalService.getOnThisDayEntries(DateTime(2026, 9, 1));
      expect(entries.length, 2);
      expect(entries[0].id, n2025.id);
      expect(entries[1].id, n2024.id);
    });

    test('ensureYearTagApplied applies journal/<year> to note tags and updates frontmatter', () async {
      final now = DateTime(2026, 11, 1);
      final note = await journalService.getOrCreateToday(now);
      expect(note.tags, isEmpty);

      final tagged = await journalService.ensureYearTagApplied(note, 2026);
      expect(tagged.tags, contains('journal/2026'));
      expect(tagged.content, contains('tags: [journal/2026]'));

      final fromDb = await repository.getJournalEntry('2026-11-01');
      expect(fromDb!.tags, contains('journal/2026'));
      expect(fromDb.content, contains('tags: [journal/2026]'));
    });

    test('ensureYearTagApplied is idempotent and does not duplicate tag', () async {
      final now = DateTime(2026, 11, 1);
      final note = await journalService.getOrCreateToday(now);
      final tagged1 = await journalService.ensureYearTagApplied(note, 2026);
      expect(tagged1.tags, equals(['journal/2026']));

      final tagged2 = await journalService.ensureYearTagApplied(tagged1, 2026);
      expect(tagged2.tags, equals(['journal/2026']));
    });

    testWidgets('openOrCreateTodayFlow applies journal/<year> when autoTagYear is true', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          testContext = ctx;
          return const SizedBox();
        }),
      ));

      final now = DateTime(2026, 11, 1);
      final note = await journalService.openOrCreateTodayFlow(
        testContext,
        now: now,
        autoTagYear: true,
      );

      expect(note.tags, contains('journal/2026'));
      final inDb = await repository.getJournalEntry('2026-11-01');
      expect(inDb!.tags, contains('journal/2026'));
      expect(inDb.content, contains('tags: [journal/2026]'));
    });

    testWidgets('openOrCreateTodayFlow does not apply tag when autoTagYear is false', (tester) async {
      late BuildContext testContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          testContext = ctx;
          return const SizedBox();
        }),
      ));

      final now = DateTime(2026, 11, 1);
      final note = await journalService.openOrCreateTodayFlow(
        testContext,
        now: now,
        autoTagYear: false,
      );

      expect(note.tags, isNot(contains('journal/2026')));
      final inDb = await repository.getJournalEntry('2026-11-01');
      expect(inDb!.tags, isNot(contains('journal/2026')));
    });
  });
}
