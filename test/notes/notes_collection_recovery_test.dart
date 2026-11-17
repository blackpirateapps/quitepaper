import 'dart:async';
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
import 'package:quitepaper/features/notes/domain/notes_cursor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

class RecoveryRepository extends DriftNotesRepository {
  RecoveryRepository(super.db);
  final requests = <NotesQuery>[];
  Future<NotesQueryResult> Function(NotesQuery)? intercept;
  @override
  Future<NotesQueryResult> executeNotesQuery(NotesQuery query) {
    requests.add(query);
    return intercept?.call(query) ?? super.executeNotesQuery(query);
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
  Note item(String id) =>
      Note(id: id, title: id, content: 'Body', createdAt: now, updatedAt: now);
  NotesQueryResult response(NotesQuery q, String id) => NotesQueryResult(
    notes: [item(id)],
    nextCursor: null,
    hasMore: false,
    totalCount: 1,
    generation: q.generation,
  );

  for (final oldFirst in [false, true]) {
    for (final staleFails in [false, true]) {
      test(
        'NL-05: stale refresh is ignored oldFirst=$oldFirst failure=$staleFails',
        () async {
          repo.intercept = (q) async => response(q, 'active');
          final n = c.read(notesCollectionProvider.notifier);
          await ready();
          final old = Completer<NotesQueryResult>();
          final fresh = Completer<NotesQueryResult>();
          repo.requests.clear();
          repo.intercept = (q) =>
              repo.requests.length == 1 ? old.future : fresh.future;
          final refresh = n.refresh();
          c.read(currentDestinationProvider.notifier).state =
              AppDestination.archive;
          expect(repo.requests.length, 2);
          expect(
            repo.requests[1].generation,
            greaterThan(repo.requests[0].generation),
          );
          void completeOld() {
            if (staleFails) {
              old.completeError(StateError('stale failure'));
            } else {
              old.complete(response(repo.requests[0], 'stale-active'));
            }
          }

          if (oldFirst) {
            completeOld();
            await refresh;
            expect(c.read(notesCollectionProvider).initialLoading, isTrue);
          }
          fresh.complete(response(repo.requests[1], 'archive'));
          await ready();
          if (!oldFirst) {
            completeOld();
            await refresh;
          }
          final state = c.read(notesCollectionProvider);
          expect(state.query.context, NotesContext.archive);
          expect(state.notes.single.id, 'archive');
          expect(state.error, isNull);
          expect(state.isRefreshing, isFalse);
        },
      );
    }
  }

  test('NL-05: only the latest refresh/filter/sort request wins', () async {
    repo.intercept = (q) async => response(q, 'initial');
    final n = c.read(notesCollectionProvider.notifier);
    await ready();
    final pending = <Completer<NotesQueryResult>>[];
    repo.requests.clear();
    repo.intercept = (q) {
      final gate = Completer<NotesQueryResult>();
      pending.add(gate);
      return gate.future;
    };
    final first = n.refresh();
    final second = n.refresh();
    c
        .read(notesQueryProvider.notifier)
        .toggleContentFilter(ContentFilter.hasLinks);
    c
        .read(notesQueryProvider.notifier)
        .setSort(const NotesSort(field: SortField.title));
    expect(pending.length, 4);
    expect(repo.requests.map((q) => q.generation).toSet().length, 4);
    pending.last.complete(response(repo.requests.last, 'latest'));
    await ready();
    for (var i = pending.length - 2; i >= 0; i--) {
      pending[i].complete(response(repo.requests[i], 'stale-$i'));
    }
    await Future.wait([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(notesCollectionProvider).notes.single.id, 'latest');
    expect(c.read(notesCollectionProvider).query.sort.field, SortField.title);
    expect(
      c.read(notesCollectionProvider).query.filter.contentFilters,
      contains(ContentFilter.hasLinks),
    );
  });

  test(
    'NL-05: completion after disposal never writes notifier state',
    () async {
      final gate = Completer<NotesQueryResult>();
      repo.intercept = (q) => gate.future;
      c.read(notesCollectionProvider);
      final request = repo.requests.single;
      c.dispose();
      gate.complete(response(request, 'disposed'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test('NL-05: stale load-more cleanup leaves the current page request locked', () async {
    NotesQueryResult page(NotesQuery q, String id) => NotesQueryResult(
      notes: [item(id)], nextCursor: NotesCursor.fromNote(item(id), q.sort),
      hasMore: true, totalCount: 3, generation: q.generation,
    );
    repo.intercept = (q) async => page(q, 'active');
    final n = c.read(notesCollectionProvider.notifier);
    await ready();
    final stale = Completer<NotesQueryResult>();
    repo.intercept = (_) => stale.future;
    final oldPage = n.loadMore();
    repo.intercept = (q) async => page(q, 'archive');
    c.read(notesQueryProvider.notifier).setContext(NotesContext.archive);
    await ready();
    final current = Completer<NotesQueryResult>();
    repo.intercept = (_) => current.future;
    final newPage = n.loadMore();
    final currentQuery = repo.requests.last;
    stale.completeError(StateError('Stale page failed'));
    await oldPage;
    expect(c.read(notesCollectionProvider).loadingMore, isTrue);
    expect(c.read(notesCollectionProvider).error, isNull);
    current.complete(response(currentQuery, 'archive-next'));
    await newPage;
    expect(c.read(notesCollectionProvider).loadingMore, isFalse);
    expect(c.read(notesCollectionProvider).notes.map((n) => n.id), ['archive', 'archive-next']);
  });

}
