import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/data/notes_query_executor.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_empty_state.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

class ProbeRepository extends DriftNotesRepository {
  ProbeRepository(super.db);
  Future<NotesQueryResult> Function(NotesQuery)? intercept;
  int queries = 0;
  @override
  Future<NotesQueryResult> executeNotesQuery(NotesQuery query) {
    queries++;
    return intercept?.call(query) ?? super.executeNotesQuery(query);
  }
}

void auditWidgets(String name, WidgetTesterCallback body) => testWidgets(
  name,
  (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }
  },
  variant: TargetPlatformVariant({
    name.contains('desktop') ? TargetPlatform.linux : TargetPlatform.android,
  }),
);

// Use the live calendar so Today/Yesterday grouping stays reproducible on replay.
final now = DateUtils.dateOnly(DateTime.now()).add(const Duration(hours: 12));
Note note(String id, {String? title, DateTime? updated, String? body}) => Note(
  id: id,
  title: title ?? id,
  content: body ?? 'Audit body for $id',
  createdAt: now,
  updatedAt: updated ?? now,
);
NotesQueryResult result(NotesQuery q, List<Note> notes) => NotesQueryResult(
  notes: notes,
  nextCursor: null,
  hasMore: false,
  totalCount: notes.length,
  generation: q.generation,
);
void record(String name, Map<String, Object?> values) =>
    debugPrint('AUDIT ${jsonEncode({'case': name, ...values})}');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProbeRepository repo;
  late SharedPreferences prefs;
  setUp(() async {
    // Isolate this replay from real user preferences.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repo = ProbeRepository(db);
    NoteMetadataExtractor.clearCache();
  });
  tearDown(() async {
    await db.close();
  });
  Future<ProviderContainer> mount(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: NotesScreen()),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    });
    return ProviderScope.containerOf(t.element(find.byType(NotesScreen)));
  }

  for (final layout in {
    'mobile': const Size(390, 844),
    'desktop': const Size(1440, 900),
  }.entries) {
    auditWidgets(
      'NL-01 ${layout.key}: initial failure retries existing notes',
      (t) async {
        repo.intercept = (_) async => throw StateError('Injected read failure');
        final c = await mount(t, layout.value);
        expect(c.read(notesCollectionProvider).error, isA<StateError>());
        expect(find.byType(NoteEmptyState), findsNothing);
        expect(find.text("Couldn't load notes"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        repo.intercept = (q) async =>
            result(q, [note('existing', title: 'Existing note')]);
        await t.tap(find.text('Retry'));
        await t.pumpAndSettle();
        expect(c.read(notesCollectionProvider).error, isNull);
        expect(find.text('Existing note'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
    auditWidgets(
      'NL-01 ${layout.key}: successful empty query keeps empty state',
      (t) async {
        repo.intercept = (q) async => result(q, []);
        await mount(t, layout.value);
        expect(find.byType(NoteEmptyState), findsOneWidget);
        expect(find.text('No notes yet'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );
  }
  for (final layout in {
    'mobile': const Size(390, 844),
    'desktop': const Size(1440, 900),
  }.entries) {
    auditWidgets(
      'NL-02 ${layout.key}: grouping preserves every sort and pin order',
      (t) async {
        final notes = [
          note(
            'a',
            title: 'Alpha',
            updated: now.subtract(const Duration(days: 1)),
          ),
          note(
            'b',
            title: 'Beta',
          ).copyWith(createdAt: now.subtract(const Duration(days: 2))),
          note(
            'c',
            title: 'Charlie',
            updated: now.subtract(const Duration(days: 1)),
          ).copyWith(isPinned: true),
        ];
        for (final item in notes) {
          await repo.saveNote(item);
        }
        final c = await mount(t, layout.value);
        for (final field in SortField.values) {
          for (final direction in SortDirection.values) {
            for (final pinnedFirst in [false, true]) {
              c
                  .read(notesQueryProvider.notifier)
                  .setSort(
                    NotesSort(
                      field: field,
                      direction: direction,
                      pinnedFirst: pinnedFirst,
                    ),
                  );
              await t.pumpAndSettle();
              final raw = c.read(notesCollectionProvider).notes;
              final rendered = t
                  .widgetList<NoteListTile>(find.byType(NoteListTile))
                  .map((w) => w.note.id)
                  .toList();
              expect(
                rendered,
                raw.map((n) => n.id).toList(),
                reason: '$field $direction pins=$pinnedFirst',
              );
              final groups = c.read(groupedNotesCollectionProvider);
              if (field == SortField.title) {
                expect(
                  groups.where((g) => g.header != 'Pinned').single.header,
                  'Notes',
                );
              } else if (field == SortField.created) {
                expect(groups.any((g) => g.header == 'Yesterday'), isFalse);
              }
            }
          }
        }
      },
    );
  }

  test(
    'NL-02: grouping preserves sort and pins across real keyset pages',
    () async {
      final notes = List.generate(
        85,
        (i) =>
            note(
              'paged-$i',
              title: 'Title ${i.toString().padLeft(3, '0')}',
              updated: now.subtract(Duration(days: i % 3)),
            ).copyWith(
              createdAt: now.subtract(Duration(days: i % 5)),
              isPinned: i % 11 == 0,
            ),
      );
      for (final item in notes) {
        await repo.saveNote(item);
      }
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c.dispose);
      c.read(notesCollectionProvider);
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

      for (final field in SortField.values) {
        for (final direction in SortDirection.values) {
          for (final pinnedFirst in [false, true]) {
            c
                .read(notesQueryProvider.notifier)
                .setSort(
                  NotesSort(
                    field: field,
                    direction: direction,
                    pinnedFirst: pinnedFirst,
                  ),
                );
            await ready();
            while (c.read(notesCollectionProvider).hasMore) {
              final state = c.read(notesCollectionProvider);
              expect(
                c
                    .read(groupedNotesCollectionProvider)
                    .expand((g) => g.notes)
                    .map((n) => n.id),
                state.notes.map((n) => n.id),
              );
              await c.read(notesCollectionProvider.notifier).loadMore();
            }
            expect(c.read(notesCollectionProvider).notes.length, 85);
            expect(
              c
                  .read(groupedNotesCollectionProvider)
                  .expand((g) => g.notes)
                  .map((n) => n.id),
              c.read(notesCollectionProvider).notes.map((n) => n.id),
            );
          }
        }
      }
    },
  );
  for (final layout in {
    'mobile': const Size(390, 844),
    'desktop': const Size(1440, 900),
  }.entries) {
    auditWidgets(
      'NL-03 ${layout.key}: tag-only updates refresh tile metadata',
      (t) async {
        final original = note('tags').copyWith(tags: ['before']);
        repo.intercept = (q) async => result(q, [original]);
        final c = await mount(t, layout.value);
        expect(find.text('#before'), findsOneWidget);
        c
            .read(notesCollectionProvider.notifier)
            .updateLocalNote(original.copyWith(tags: ['after']));
        await t.pumpAndSettle();
        expect(find.text('#before'), findsNothing);
        expect(find.text('#after'), findsOneWidget);
        expect(
          NoteMetadataExtractor.extract(
            c.read(notesCollectionProvider).notes.single,
          ).tags,
          ['after'],
        );
      },
    );
  }
  for (final layout in {
    'mobile': const Size(390, 844),
    'desktop': const Size(1440, 900),
  }.entries) {
    auditWidgets('NL-04 ${layout.key}: refresh keeps a deep visible anchor', (
      t,
    ) async {
      await t.runAsync(
        () => db.batch(
          (b) => b.insertAll(
            db.notesTable,
            List.generate(
              1040,
              (i) => NotesTableCompanion.insert(
                id: 'anchor-$i',
                title: Value('Anchor $i'),
                createdAt: now,
                updatedAt: now.subtract(Duration(minutes: i)),
              ),
            ),
          ),
        ),
      );
      final c = await mount(t, layout.value);
      final n = c.read(notesCollectionProvider.notifier);
      await t.runAsync(() async {
        while (c.read(notesCollectionProvider).notes.length < 1000) {
          await n.loadMore();
        }
      });
      await t.pumpAndSettle();
      final list = find
          .ancestor(
            of: find.byType(NoteListTile).first,
            matching: find.byType(ListView),
          )
          .first;
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      final position = t.state<ScrollableState>(scrollable).position;
      position.jumpTo(30000);
      await t.pumpAndSettle();
      final viewport = t.getRect(list);
      final visible = find
          .byType(NoteListTile)
          .evaluate()
          .where((e) => t.getRect(find.byWidget(e.widget)).overlaps(viewport));
      final tile = visible.first.widget as NoteListTile;
      final anchorId = tile.note.id;
      final anchorRect = t.getRect(find.byWidget(tile));
      final offset = position.pixels;
      final ids = c
          .read(notesCollectionProvider)
          .notes
          .map((n) => n.id)
          .toList();
      await t.runAsync(() async {
        await db.customStatement(
          "UPDATE notes SET title = 'Changed anchor' WHERE id = ?",
          [anchorId],
        );
        await n.refresh();
      });
      await t.pumpAndSettle();
      expect(c.read(notesCollectionProvider).notes.map((n) => n.id), ids);
      expect(position.pixels, offset);
      final current = find.byWidgetPredicate(
        (w) => w is NoteListTile && w.note.id == anchorId,
      );
      expect(current, findsOneWidget);
      expect(t.getRect(current).top, anchorRect.top);
      expect(t.takeException(), isNull);
    });
  }

  for (final count in [600, 1000]) {
    for (final layout in {
      'mobile': const Size(390, 844),
      'desktop': const Size(1440, 900),
    }.entries) {
      auditWidgets('NL-08 ${layout.key}: $count notes parse only mounted rows', (
        t,
      ) async {
        final notes = List.generate(
          count,
          (i) => note(
            'large-$i',
            body:
                '---\nmood: 7\n---\n${List.filled(30, '**Body** with [link](https://example.test)').join('\n')}',
          ),
        );
        repo.intercept = (q) async => result(q, notes);
        final c = await mount(t, layout.value);
        expect(NoteMetadataExtractor.cacheSize, lessThan(80));
        final tile = t.widget<NoteListTile>(find.byType(NoteListTile).first);
        final useful = NoteMetadataExtractor.extract(tile.note);
        final groups = c.read(groupedNotesCollectionProvider);
        final gate = Completer<NotesQueryResult>();
        NotesQuery? request;
        repo.intercept = (q) {
          request = q;
          return gate.future;
        };
        final refresh = c.read(notesCollectionProvider.notifier).refresh();
        await t.pump();
        expect(c.read(groupedNotesCollectionProvider), same(groups));
        expect(NoteMetadataExtractor.extract(tile.note), same(useful));
        gate.complete(result(request!, notes));
        await refresh;
        await t.pumpAndSettle();
        expect(NoteMetadataExtractor.extract(tile.note), same(useful));
        expect(NoteMetadataExtractor.cacheSize, lessThan(80));
        expect(t.takeException(), isNull);
      });
    }
  }
}
