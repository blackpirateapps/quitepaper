import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/on_this_day_view.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
    // Extractor cache is static/process-wide; clear it so each test parses fresh.
    NoteMetadataExtractor.clearCache();
  });

  tearDown(() async {
    NoteMetadataExtractor.clearCache();
    await db.close();
  });

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        historicalWeekNotesStreamProvider.overrideWith((ref) => Stream.value([])),
        earliestJournalYearFutureProvider.overrideWith((ref) => Future.value(null)),
        ...overrides,
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: OnThisDayView(),
        ),
      ),
    );
  }

  group('OnThisDayView place segment (Feature 3)', () {
    testWidgets('appends the city-level place to the metadata line when present',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final entry = Note(
        id: 'located',
        title: 'A day in Mumbai',
        content: '---\n'
            'journal: true\n'
            'date: 2020-10-09\n'
            'location:\n'
            '  address: "Mumbai, Maharashtra, India"\n'
            '  latitude: 19.0760\n'
            '  longitude: 72.8777\n'
            '---\n'
            'The sea was loud today.',
        createdAt: DateTime(2020, 10, 9),
        updatedAt: DateTime(2020, 10, 9),
        journalDate: '2020-10-09',
      );

      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([entry])),
        ],
      ));
      await tester.pumpAndSettle();

      // Date still renders exactly as today.
      expect(find.text('October 9, 2020'), findsOneWidget);
      // The place is appended as the first comma-separated token (city), muted.
      expect(find.text('· Mumbai'), findsOneWidget);
    });

    testWidgets('renders the line identical to today when the entry has no location',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final entry = Note(
        id: 'unlocated',
        title: 'A quiet day',
        content: '---\n'
            'journal: true\n'
            'date: 2020-10-09\n'
            '---\n'
            'Nothing to report.',
        createdAt: DateTime(2020, 10, 9),
        updatedAt: DateTime(2020, 10, 9),
        journalDate: '2020-10-09',
      );

      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([entry])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('October 9, 2020'), findsOneWidget);
      // No place segment, and no stray separator anywhere in the view.
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('shows no place for a password-protected (locked) entry',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Encrypted content marks the note as password protected; the metadata
      // cache exposes location == null for locked notes, so no place renders.
      final entry = Note(
        id: 'locked',
        title: '',
        content: '<!-- quiet-paper-encrypted-note-v1:AAAABBBBCCCC -->',
        createdAt: DateTime(2020, 10, 9),
        updatedAt: DateTime(2020, 10, 9),
        journalDate: '2020-10-09',
      );

      expect(entry.isPasswordProtected, isTrue);

      await tester.pumpWidget(createTestWidget(
        overrides: [
          onThisDayEntriesStreamProvider.overrideWith((ref) => Stream.value([entry])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('October 9, 2020'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });
}
