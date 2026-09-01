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

    test('getOnThisDayEntries returns only previous year matching entries', () async {
      // Historical entries
      final n2025 = await repository.getOrCreateJournalEntry(DateTime(2025, 9, 1));
      final n2024 = await repository.getOrCreateJournalEntry(DateTime(2024, 9, 1));

      final entries = await journalService.getOnThisDayEntries(DateTime(2026, 9, 1));
      expect(entries.length, 2);
      expect(entries[0].id, n2025.id);
      expect(entries[1].id, n2024.id);
    });
  });
}
