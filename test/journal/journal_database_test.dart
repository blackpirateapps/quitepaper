import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Journal Schema & Query Tests', () {
    test('schema version is 14', () {
      expect(db.schemaVersion, 14);
    });

    test('saveNote saves journalDate and getJournalEntry finds it', () async {
      final now = DateTime(2026, 9, 1, 10, 0);

      await db.saveNote(
        id: 'journal-1',
        title: 'September 1, 2026',
        content: '---\njournal: true\ndate: 2026-09-01\n---\nReflections.',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        journalDate: '2026-09-01',
      );

      final entry = await db.getJournalEntry('2026-09-01');
      expect(entry, isNotNull);
      expect(entry!.note.id, 'journal-1');
      expect(entry.note.journalDate, '2026-09-01');
      expect(entry.note.title, 'September 1, 2026');
    });

    test('automatic journalDate extraction from markdown content', () async {
      final now = DateTime(2026, 8, 15);

      await db.saveNote(
        id: 'journal-auto-1',
        title: 'August 15, 2026',
        content: '---\njournal: true\ndate: 2026-08-15\n---\nAuto extracted.',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final entry = await db.getJournalEntry('2026-08-15');
      expect(entry, isNotNull);
      expect(entry!.note.journalDate, '2026-08-15');
    });

    test('unique index enforces at most one journal note per date', () async {
      final now = DateTime(2026, 9, 1);

      await db.saveNote(
        id: 'entry-1',
        title: 'Entry 1',
        content: 'Note 1',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        journalDate: '2026-09-01',
      );

      // Attempting to insert another note with same journalDate throws unique constraint error
      expect(
        () async => db.saveNote(
          id: 'entry-2',
          title: 'Entry 2',
          content: 'Note 2',
          createdAt: now,
          updatedAt: now,
          isPinned: false,
          journalDate: '2026-09-01',
        ),
        throwsA(anything),
      );
    });

    test('normal notes with journal_date = null can be inserted with no collision', () async {
      final now = DateTime.now();

      await db.saveNote(
        id: 'normal-1',
        title: 'Note 1',
        content: 'Content 1',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      await db.saveNote(
        id: 'normal-2',
        title: 'Note 2',
        content: 'Content 2',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final n1 = await db.getNoteWithTags('normal-1');
      final n2 = await db.getNoteWithTags('normal-2');
      expect(n1?.note.journalDate, isNull);
      expect(n2?.note.journalDate, isNull);
    });

    test('getOnThisDayEntries returns historical entries in reverse chronological order', () async {
      // Historical entries for September 1st
      await db.saveNote(
        id: 'hist-2023',
        title: 'September 1, 2023',
        content: '2023 entry',
        createdAt: DateTime(2023, 9, 1),
        updatedAt: DateTime(2023, 9, 1),
        isPinned: false,
        journalDate: '2023-09-01',
      );

      await db.saveNote(
        id: 'hist-2025',
        title: 'September 1, 2025',
        content: '2025 entry',
        createdAt: DateTime(2025, 9, 1),
        updatedAt: DateTime(2025, 9, 1),
        isPinned: false,
        journalDate: '2025-09-01',
      );

      await db.saveNote(
        id: 'hist-2024',
        title: 'September 1, 2024',
        content: '2024 entry',
        createdAt: DateTime(2024, 9, 1),
        updatedAt: DateTime(2024, 9, 1),
        isPinned: false,
        journalDate: '2024-09-01',
      );

      // Trashed entry from 2022 (should be excluded)
      await db.saveNote(
        id: 'hist-2022-trashed',
        title: 'September 1, 2022',
        content: 'Trashed entry',
        createdAt: DateTime(2022, 9, 1),
        updatedAt: DateTime(2022, 9, 1),
        isPinned: false,
        isTrashed: true,
        journalDate: '2022-09-01',
      );

      // Entry on a different day (September 2)
      await db.saveNote(
        id: 'hist-2024-sep-2',
        title: 'September 2, 2024',
        content: 'Different day',
        createdAt: DateTime(2024, 9, 2),
        updatedAt: DateTime(2024, 9, 2),
        isPinned: false,
        journalDate: '2024-09-02',
      );

      // Today's entry (2026 - should be excluded by beforeYear: 2026)
      await db.saveNote(
        id: 'today-2026',
        title: 'September 1, 2026',
        content: 'Today entry',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
        isPinned: false,
        journalDate: '2026-09-01',
      );

      final results = await db.getOnThisDayEntries(
        month: 9,
        day: 1,
        beforeYear: 2026,
      );

      expect(results.length, 3);
      expect(results[0].note.id, 'hist-2025'); // Reverse chronological (2025 first)
      expect(results[1].note.id, 'hist-2024');
      expect(results[2].note.id, 'hist-2023');
    });

    test('getJournalDatesForMonth and watchJournalDatesForMonth return only dates for specified month', () async {
      final now = DateTime(2026, 9, 1);

      await db.saveNote(
        id: 'sep-1',
        title: 'Sep 1',
        content: 'Content 1',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        journalDate: '2026-09-01',
      );

      await db.saveNote(
        id: 'sep-15',
        title: 'Sep 15',
        content: 'Content 15',
        createdAt: DateTime(2026, 9, 15),
        updatedAt: DateTime(2026, 9, 15),
        isPinned: false,
        journalDate: '2026-09-15',
      );

      // Trashed note in Sep (should be excluded)
      await db.saveNote(
        id: 'sep-20-trashed',
        title: 'Sep 20',
        content: 'Content 20',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        isPinned: false,
        isTrashed: true,
        journalDate: '2026-09-20',
      );

      // August note (different month)
      await db.saveNote(
        id: 'aug-31',
        title: 'Aug 31',
        content: 'Content Aug',
        createdAt: DateTime(2026, 8, 31),
        updatedAt: DateTime(2026, 8, 31),
        isPinned: false,
        journalDate: '2026-08-31',
      );

      final dates = await db.getJournalDatesForMonth(2026, 9);
      expect(dates, containsAll(['2026-09-01', '2026-09-15']));
      expect(dates, isNot(contains('2026-09-20'))); // Trashed excluded
      expect(dates, isNot(contains('2026-08-31'))); // Different month excluded
      expect(dates.length, 2);

      // Verify stream emits the same
      final streamDates = await db.watchJournalDatesForMonth(2026, 9).first;
      expect(streamDates, equals(dates));
    });

    test('getAllJournalEntries and watchAllJournalEntries return active entries ordered newest date first', () async {
      await db.saveNote(
        id: 'j-2025-12',
        title: 'Dec 2025',
        content: 'Dec',
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
        isPinned: false,
        journalDate: '2025-12-01',
      );

      await db.saveNote(
        id: 'j-2026-09',
        title: 'Sep 2026',
        content: 'Sep',
        createdAt: DateTime(2026, 9, 15),
        updatedAt: DateTime(2026, 9, 15),
        isPinned: false,
        journalDate: '2026-09-15',
      );

      await db.saveNote(
        id: 'j-2026-08',
        title: 'Aug 2026',
        content: 'Aug',
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
        isPinned: false,
        journalDate: '2026-08-10',
      );

      // Trashed entry
      await db.saveNote(
        id: 'j-trashed',
        title: 'Trashed',
        content: 'Trashed',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        isPinned: false,
        isTrashed: true,
        journalDate: '2026-09-20',
      );

      final entries = await db.getAllJournalEntries();
      expect(entries.length, 3);
      expect(entries[0].note.id, 'j-2026-09'); // 2026-09-15 first
      expect(entries[1].note.id, 'j-2026-08'); // 2026-08-10 second
      expect(entries[2].note.id, 'j-2025-12'); // 2025-12-01 third

      final streamEntries = await db.watchAllJournalEntries().first;
      expect(streamEntries.map((e) => e.note.id).toList(), ['j-2026-09', 'j-2026-08', 'j-2025-12']);
    });

    test('validateJournalIntegrity returns empty list when database has no collisions', () async {
      await db.saveNote(
        id: 'j-1',
        title: 'J1',
        content: 'C1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        journalDate: '2026-09-01',
      );

      final issues = await db.validateJournalIntegrity();
      expect(issues, isEmpty);
    });
  });
}
