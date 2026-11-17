import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/data/notes_query_executor.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

class RecoveryRepository extends DriftNotesRepository {
  RecoveryRepository(super.db);
  final requests = <NotesQuery>[];
  @override
  Future<NotesQueryResult> executeNotesQuery(NotesQuery query) {
    requests.add(query);
    return super.executeNotesQuery(query);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecoveryRepository repo;
  late ProviderContainer c;
  final now = DateTime(2026, 11, 17, 12);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repo = RecoveryRepository(db);
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> ready() async {
    for (
      var i = 0;
      i < 500 && c.read(notesCollectionProvider).initialLoading;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.read(notesCollectionProvider).initialLoading, isFalse);
  }

  Future<void> seed(int count) async {
    await db.batch(
      (b) => b.insertAll(
        db.notesTable,
        List.generate(
          count,
          (i) => NotesTableCompanion.insert(
            id: 'n-${i.toString().padLeft(5, '0')}',
            title: Value('Note $i'),
            createdAt: now,
            updatedAt: now.subtract(Duration(minutes: i)),
          ),
        ),
      ),
    );
  }

  for (final loaded in [440, 1000]) {
    test(
      'NL-04: refresh retains $loaded loaded notes and continuation cursor',
      () async {
        await seed(loaded + 40);
        final n = c.read(notesCollectionProvider.notifier);
        await ready();
        while (c.read(notesCollectionProvider).notes.length < loaded) {
          await n.loadMore();
        }
        final before = c.read(notesCollectionProvider);
        final anchor = before.notes[loaded - 10].id;
        await db.customStatement(
          "UPDATE notes SET title = 'Changed' WHERE id = ?",
          [anchor],
        );
        repo.requests.clear();
        await n.refresh();
        final after = c.read(notesCollectionProvider);
        expect(after.notes.map((n) => n.id), before.notes.map((n) => n.id));
        expect(after.notes[loaded - 10].title, 'Changed');
        expect(after.cursor, before.cursor);
        expect(after.hasMore, isTrue);
        expect(
          repo.requests.every((q) => q.limit <= NotesQuery.maxBatchSize),
          isTrue,
        );
        expect(repo.requests.length, (loaded / NotesQuery.maxBatchSize).ceil());
        await n.loadMore();
        expect(c.read(notesCollectionProvider).notes.length, loaded + 40);
        expect(
          c.read(notesCollectionProvider).notes.map((n) => n.id).toSet().length,
          loaded + 40,
        );
        await n.loadMore();
        expect(c.read(notesCollectionProvider).hasMore, isFalse);
        await n.refresh();
        expect(c.read(notesCollectionProvider).notes.length, loaded + 40);
        await n.loadMore();
        expect(c.read(notesCollectionProvider).cursor, isNull);
      },
    );
  }
}
