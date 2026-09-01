import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

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

  group('DriftNotesRepository Journal Tests', () {
    test('getOrCreateJournalEntry creates note atomically with canonical frontmatter', () async {
      final date = DateTime(2026, 9, 1);
      final note = await repository.getOrCreateJournalEntry(date);

      expect(note.isJournal, isTrue);
      expect(note.journalDate, '2026-09-01');
      expect(note.title, 'September 1, 2026');
      expect(note.content, contains('journal: true'));
      expect(note.content, contains('date: 2026-09-01'));

      // Calling again returns the EXACT same note
      final secondCall = await repository.getOrCreateJournalEntry(date);
      expect(secondCall.id, note.id);
      expect(secondCall.journalDate, '2026-09-01');
    });

    test('user can customize journal note title while preserving journalDate', () async {
      final date = DateTime(2026, 9, 1);
      final note = await repository.getOrCreateJournalEntry(date);

      // User changes title to "A very quiet morning"
      final updatedNote = note.copyWith(
        title: 'A very quiet morning',
        content: '---\njournal: true\ndate: 2026-09-01\n---\nReflections written today.',
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(updatedNote);

      final retrieved = await repository.getJournalEntry('2026-09-01');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, note.id);
      expect(retrieved.title, 'A very quiet morning');
      expect(retrieved.journalDate, '2026-09-01');
      expect(retrieved.isJournal, isTrue);
    });

    test('watchJournalEntry emits changes when note is saved', () async {
      final dateStr = '2026-09-01';

      expect(
        repository.watchJournalEntry(dateStr),
        emitsInOrder([
          isNull, // Initially null
          predicate((n) => n != null && (n as dynamic).title == 'September 1, 2026'),
          predicate((n) => n != null && (n as dynamic).title == 'Updated Title'),
        ]),
      );

      await pumpEventQueue();

      final created = await repository.getOrCreateJournalEntry(DateTime(2026, 9, 1));
      await pumpEventQueue();

      await repository.saveNote(created.copyWith(title: 'Updated Title'));
      await pumpEventQueue();
    });

    test('watchOnThisDayEntries streams historical entries', () async {
      final stream = repository.watchOnThisDayEntries(
        month: 9,
        day: 1,
        beforeYear: 2026,
      );

      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          predicate((list) => (list as List).length == 1 && list.first.journalDate == '2025-09-01'),
        ]),
      );

      await pumpEventQueue();

      await repository.getOrCreateJournalEntry(DateTime(2025, 9, 1));
      await pumpEventQueue();

      await expectation;
    });
  });
}
