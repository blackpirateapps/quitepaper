import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<void> seedNotes(int count) async {
    final baseTime = DateTime(2026, 8, 1, 10, 0, 0);
    for (int i = 0; i < count; i++) {
      final idNum = (i + 1).toString().padLeft(4, '0');
      await repository.saveNote(
        Note(
          id: 'note-$idNum',
          title: 'Note $idNum',
          content: 'Content $idNum',
          createdAt: baseTime.add(Duration(minutes: i)),
          updatedAt: baseTime.add(Duration(minutes: i)),
        ),
      );
    }
  }

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  test('Race condition between loadMore and table updates never freezes loadingMore at true', () async {
    await seedNotes(100);

    final container = createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(notesCollectionProvider.notifier);

    // Wait for initial load (limit 40)
    while (container.read(notesCollectionProvider).initialLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final state0 = container.read(notesCollectionProvider);
    expect(state0.notes.length, 40);
    expect(state0.loadingMore, isFalse);
    expect(state0.hasMore, isTrue);

    // Trigger loadMore and concurrently trigger a table update before loadMore finishes
    final loadMoreFuture = notifier.loadMore();

    // Trigger table update immediately while loadMore is querying
    await db.customUpdate(
      "UPDATE notes SET title = 'Note 0001 Updated' WHERE id = 'note-0001'",
      updates: {db.notesTable},
    );

    // Wait for loadMore and any debounced table update to settle
    await loadMoreFuture;
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final state1 = container.read(notesCollectionProvider);
    // Crucial invariant: loadingMore MUST NOT be frozen at true!
    expect(state1.loadingMore, isFalse);

    // Now verify that subsequent loadMore works without getting stuck
    await notifier.loadMore();
    final state2 = container.read(notesCollectionProvider);
    expect(state2.loadingMore, isFalse);
    expect(state2.notes.length, greaterThan(40));
  });

  test('Multi-page pagination smoothly loads 100 notes without duplicates', () async {
    await seedNotes(100);

    final container = createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(notesCollectionProvider.notifier);

    // Initial batch (40 notes)
    while (container.read(notesCollectionProvider).initialLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(notesCollectionProvider).notes.length, 40);
    expect(container.read(notesCollectionProvider).hasMore, isTrue);

    // Page 2 (40 notes -> 80 total)
    await notifier.loadMore();
    expect(container.read(notesCollectionProvider).notes.length, 80);
    expect(container.read(notesCollectionProvider).hasMore, isTrue);
    expect(container.read(notesCollectionProvider).loadingMore, isFalse);

    // Page 3 (20 notes -> 100 total)
    await notifier.loadMore();
    final finalState = container.read(notesCollectionProvider);
    expect(finalState.notes.length, 100);
    expect(finalState.hasMore, isFalse);
    expect(finalState.loadingMore, isFalse);

    // Ensure all note IDs are unique
    final noteIds = finalState.notes.map((n) => n.id).toSet();
    expect(noteIds.length, 100);

    // Further loadMore does nothing
    await notifier.loadMore();
    expect(container.read(notesCollectionProvider).notes.length, 100);
    expect(container.read(notesCollectionProvider).loadingMore, isFalse);
  });

  test('Debounced refresh preserves loaded note count and scroll depth', () async {
    await seedNotes(100);

    final container = createContainer();
    addTearDown(container.dispose);

    final notifier = container.read(notesCollectionProvider.notifier);

    while (container.read(notesCollectionProvider).initialLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Load second page so user has 80 notes visible
    await notifier.loadMore();
    expect(container.read(notesCollectionProvider).notes.length, 80);

    // Trigger table update (simulating sync or metadata change)
    await db.customUpdate(
      "UPDATE notes SET title = 'Note 0010 Updated' WHERE id = 'note-0010'",
      updates: {db.notesTable},
    );

    // Wait for debouncer (350ms) to fire refresh
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final stateAfterRefresh = container.read(notesCollectionProvider);
    // Preserved loaded note count!
    expect(stateAfterRefresh.notes.length, 80);
    expect(stateAfterRefresh.loadingMore, isFalse);
    expect(stateAfterRefresh.hasMore, isTrue);

    // Subsequent loadMore can load remaining 20 notes
    await notifier.loadMore();
    expect(container.read(notesCollectionProvider).notes.length, 100);
  });
}
