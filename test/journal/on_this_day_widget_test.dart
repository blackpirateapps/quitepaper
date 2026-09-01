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
  });
}
