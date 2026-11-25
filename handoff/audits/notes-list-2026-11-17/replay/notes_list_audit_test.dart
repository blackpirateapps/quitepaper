// Audit characterization probes: a pass confirms the documented behavior,
// including known defects. These are deliberately outside test/ discovery.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../test/support/pump_until_found.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/data/notes_query_executor.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_empty_state.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';
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

class ProbePicker extends FilePicker {
  ProbePicker(this.path);
  final String path;
  Uint8List? suppliedBytes;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    suppliedBytes = bytes;
    return path;
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
  ProviderContainer container() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  Future<void> waitReady(ProviderContainer c) async {
    for (var i = 0; i < 500; i++) {
      if (!c.read(notesCollectionProvider).initialLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Initial query did not finish in 5 seconds');
  }

  Future<void> seed(int count) async {
    await db.batch(
      (b) => b.insertAll(
        db.notesTable,
        List.generate(
          count,
          (i) => NotesTableCompanion.insert(
            id: 'n-${i.toString().padLeft(5, '0')}',
            createdAt: now,
            updatedAt: now.subtract(Duration(minutes: i)),
          ),
        ),
      ),
    );
  }

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
      'NL-01 ${layout.key}: initial failure is shown as empty library',
      (t) async {
        repo.intercept = (_) async =>
            throw StateError('Injected database failure');
        final c = await mount(t, layout.value);
        expect(c.read(notesCollectionProvider).error, isA<StateError>());
        expect(find.byType(NoteEmptyState), findsOneWidget);
        expect(find.text('No notes yet'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        record('NL-01 ${layout.key}', {
          'emptyLibrary': true,
          'retryVisible': false,
        });
      },
    );

    auditWidgets(
      'NL-11 ${layout.key}: failed context load keeps previous context notes',
      (t) async {
        await repo.saveNote(
          note('active-visible', title: 'Active visible note'),
        );
        final c = await mount(t, layout.value);
        expect(
          c.read(notesCollectionProvider).notes.single.isArchived,
          isFalse,
        );
        repo.intercept = (_) async =>
            throw StateError('Injected archive load failure');
        c.read(currentDestinationProvider.notifier).state =
            AppDestination.archive;
        await t.pumpAndSettle();
        final state = c.read(notesCollectionProvider);
        expect(state.query.context, NotesContext.archive);
        expect(state.error, isA<StateError>());
        expect(find.text('Active visible note'), findsOneWidget);
        expect(state.notes.single.isArchived, isFalse);
        record('NL-11 ${layout.key}', {
          'context': 'archive',
          'renderedNoteArchived': false,
          'errorRetained': true,
        });
      },
    );

    auditWidgets(
      'NL-02 ${layout.key}: title sort is reordered by date grouping',
      (t) async {
        await repo.saveNote(
          note(
            'a',
            title: 'Alpha',
            updated: now.subtract(const Duration(days: 1)),
          ),
        );
        await repo.saveNote(note('b', title: 'Beta'));
        await repo.saveNote(
          note(
            'c',
            title: 'Charlie',
            updated: now.subtract(const Duration(days: 1)),
          ),
        );
        final c = await mount(t, layout.value);
        c
            .read(notesQueryProvider.notifier)
            .setSort(
              const NotesSort(
                field: SortField.title,
                direction: SortDirection.ascending,
                pinnedFirst: false,
              ),
            );
        await t.pumpAndSettle();
        final raw = c
            .read(notesCollectionProvider)
            .notes
            .map((n) => n.title)
            .toList();
        final rendered = t
            .widgetList<NoteListTile>(find.byType(NoteListTile))
            .map((w) => w.note.title)
            .toList();
        expect(raw, ['Alpha', 'Beta', 'Charlie']);
        expect(rendered, ['Alpha', 'Charlie', 'Beta']);
        record('NL-02 ${layout.key}', {
          'queryOrder': raw,
          'renderedOrder': rendered,
        });
      },
    );

    auditWidgets(
      'NL-03 ${layout.key}: tag-only update retains stale preview tags',
      (t) async {
        final original = note('tags').copyWith(tags: ['before']);
        await repo.saveNote(original);
        final c = await mount(t, layout.value);
        c
            .read(notesCollectionProvider.notifier)
            .updateLocalNote(original.copyWith(tags: ['after']));
        await t.pumpAndSettle();
        final current = c.read(notesCollectionProvider).notes.single;
        final meta = NoteMetadataExtractor.extract(current);
        expect(current.tags, ['after']);
        expect(meta.tags, ['before']);
        record('NL-03 ${layout.key}', {
          'modelTags': current.tags,
          'previewTags': meta.tags,
        });
      },
    );

    auditWidgets(
      'NL-07 ${layout.key}: 1000 notes remain lazily mounted while scrolling',
      (t) async {
        // Inject a fully loaded collection to measure UI virtualization independently
        // of database and pagination. Native harness covers actual query timings.
        final notes = List.generate(1000, (i) => note('Virtual note $i'));
        repo.intercept = (q) async => result(q, notes);
        final c = await mount(t, layout.value);
        final counts = <int>[];
        final samples = <int>[];
        final list = find
            .ancestor(
              of: find.byType(NoteListTile).first,
              matching: find.byType(ListView),
            )
            .first;
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;
        final state = t.state<ScrollableState>(scrollable);
        for (var i = 0; i < 30; i++) {
          state.position.jumpTo(i * 240.0);
          final timer = Stopwatch()..start();
          await t.pump(const Duration(milliseconds: 16));
          timer.stop();
          samples.add(timer.elapsedMicroseconds);
          counts.add(find.byType(NoteListTile).evaluate().length);
        }
        expect(c.read(notesCollectionProvider).notes.length, 1000);
        expect(counts.reduce((a, b) => a > b ? a : b), lessThan(40));
        expect(t.takeException(), isNull);
        samples.sort();
        record('NL-07 ${layout.key}', {
          'loaded': 1000,
          'maxMounted': counts.reduce((a, b) => a > b ? a : b),
          'pumpMedianUs': samples[samples.length ~/ 2],
          'pumpMaxUs': samples.last,
          'warning':
              'debug widget wall-clock pump times, not native frame timings',
        });
      },
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(600, 800),
    const Size(899, 700),
    const Size(900, 700),
  ]) {
    auditWidgets('Responsive smoke ${size.width}dp', (t) async {
      await repo.saveNote(
        note(
          'responsive',
          title: '日本語 বাংলা A very long title that must wrap without overflow',
          body: '- [ ] Task\n| Left | Right |\n| --- | --- |\n| Alpha | Beta |',
        ),
      );
      final c = await mount(t, size);
      expect(find.byType(NoteListTile), findsOneWidget);
      expect(t.takeException(), isNull);
      c.read(currentDestinationProvider.notifier).state =
          AppDestination.archive;
      await t.pumpAndSettle();
      expect(find.text('Archive is empty'), findsOneWidget);
      expect(t.takeException(), isNull);
      record('responsive', {
        'width': size.width,
        'height': size.height,
        'overflow': false,
      });
    });
  }

  test(
    'NL-04: refresh truncates a collection beyond the 250-note batch cap',
    () async {
      await seed(440);
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(notesCollectionProvider.notifier);
      await waitReady(c);
      for (var i = 0; i < 20 && c.read(notesCollectionProvider).hasMore; i++) {
        await n.loadMore();
      }
      expect(c.read(notesCollectionProvider).notes.length, 440);
      await n.refresh();
      expect(c.read(notesCollectionProvider).notes.length, 250);
      expect(c.read(notesCollectionProvider).totalCount, 440);
      record('NL-04', {
        'beforeRefresh': 440,
        'afterRefresh': 250,
        'total': 440,
      });
    },
  );

  test(
    'NL-05: stale refresh overwrites a newly selected archive context',
    () async {
      repo.intercept = (q) async => result(q, [note('active')]);
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(notesCollectionProvider.notifier);
      await waitReady(c);
      final old = Completer<NotesQueryResult>();
      final fresh = Completer<NotesQueryResult>();
      final requests = <NotesQuery>[];
      repo.intercept = (q) {
        requests.add(q);
        return requests.length == 1 ? old.future : fresh.future;
      };
      final refresh = n.refresh();
      c.read(currentDestinationProvider.notifier).state =
          AppDestination.archive;
      expect(requests.length, 2);
      expect(requests[0].generation, requests[1].generation);
      fresh.complete(
        result(requests[1], [note('archived').copyWith(isArchived: true)]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(notesCollectionProvider).notes.single.id, 'archived');
      old.complete(result(requests[0], [note('active')]));
      await refresh;
      expect(
        c.read(notesCollectionProvider).query.context,
        NotesContext.archive,
      );
      expect(c.read(notesCollectionProvider).notes.single.id, 'active');
      record('NL-05', {
        'generation': requests.first.generation,
        'context': 'archive',
        'visibleNote': 'active',
      });
    },
  );

  test(
    'NL-06: Retry does not retry a failed refresh at the end of the list',
    () async {
      repo.intercept = (q) async => result(q, [note('only')]);
      final c = container();
      addTearDown(c.dispose);
      final n = c.read(notesCollectionProvider.notifier);
      await waitReady(c);
      repo.intercept = (_) async =>
          throw StateError('Injected refresh failure');
      await n.refresh();
      final before = repo.queries;
      await n.retry();
      expect(repo.queries, before);
      expect(c.read(notesCollectionProvider).error, isA<StateError>());
      record('NL-06', {
        'queriesBeforeRetry': before,
        'queriesAfterRetry': repo.queries,
        'errorRetained': true,
      });
    },
  );

  test('NL-08: repeated prewarm above cache capacity evicts every entry', () {
    for (final count in [400, 500, 600, 1000]) {
      NoteMetadataExtractor.clearCache();
      final notes = List.generate(
        count,
        (i) => note(
          'cache-$i',
          body:
              '---\ntitle: Cache test\nmood: 7\n---\n'
              '${List.filled(50, 'Paragraph with **bold** and [link](https://example.test).').join('\n')}',
        ),
      );
      NoteMetadataExtractor.prewarmAll(notes);
      // Keep references to the currently cached tail. A second identical prewarm
      // should preserve instances if it actually hits the cache.
      final tail = notes.skip(count > 500 ? count - 500 : 0).toList();
      final refs = tail.map(NoteMetadataExtractor.extract).toList();
      final timer = Stopwatch()..start();
      NoteMetadataExtractor.prewarmAll(notes);
      timer.stop();
      // Reverse lookup avoids introducing additional evictions during inspection.
      var hits = 0;
      for (var i = tail.length - 1; i >= 0; i--) {
        if (identical(refs[i], NoteMetadataExtractor.extract(tail[i]))) hits++;
      }
      expect(hits, count > 500 ? 0 : count);
      record('NL-08', {
        'notes': count,
        'preservedCachedInstances': hits,
        'repeatPrewarmUs': timer.elapsedMicroseconds,
      });
    }
  });

  auditWidgets(
    'NL-09 desktop: ZIP overwrite reports success without writing archive',
    (t) async {
      await repo.saveNote(note('Export Alpha'));
      await repo.saveNote(note('Export Beta'));
      final temp = (await t.runAsync(
        () => Directory.systemTemp.createTemp('qp-notes-export-'),
      ))!;
      addTearDown(() => temp.delete(recursive: true));
      final target = File('${temp.path}/notes.zip');
      await t.runAsync(() => target.writeAsString('EXISTING CONTENT'));
      FilePicker? previous;
      try {
        previous = FilePicker.platform;
      } catch (_) {
        /* No plugin registered in widget tests. */
      }
      final picker = ProbePicker(target.path);
      FilePicker.platform = picker;
      addTearDown(() {
        if (previous != null) {
          FilePicker.platform = previous;
        }
      });
      await mount(t, const Size(1440, 900));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.tap(find.text('Export Alpha'));
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      await t.tap(find.text('Export Beta'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('More actions'));
      await t.pumpAndSettle();
      await t.tap(find.text('Export as ZIP…'));
      await t.pumpAndSettle();
      await pumpUntilFound(t, find.text('Exported 2 notes'));
      expect(picker.suppliedBytes, isNotEmpty);
      expect(await t.runAsync(target.readAsString), 'EXISTING CONTENT');
      expect(find.text('Exported 2 notes'), findsOneWidget);
      record('NL-09', {
        'suppliedZipBytes': picker.suppliedBytes!.length,
        'actualFile': 'EXISTING CONTENT',
        'successShown': true,
      });
    },
  );

  test('NL-10: paginated query drops journal and share metadata', () async {
    final original = note('metadata').copyWith(
      journalDate: '2026-11-17',
      shareId: 'share-id',
      shareUrl: 'https://example.test/share',
    );
    await repo.saveNote(original);
    await repo.setNoteShareInfo(
      original.id,
      shareId: 'share-id',
      shareUrl: 'https://example.test/share',
    );
    final full = (await repo.getNoteById(original.id))!;
    final paged = (await repo.executeNotesQuery(
      NotesQuery.defaultQuery,
    )).notes.single;
    expect(full.journalDate, '2026-11-17');
    expect(full.shareId, 'share-id');
    expect(paged.journalDate, isNull);
    expect(paged.shareId, isNull);
    expect(paged.shareUrl, isNull);
    record('NL-10', {
      'fullJournalDate': full.journalDate,
      'pagedJournalDate': paged.journalDate,
      'fullShareId': full.shareId,
      'pagedShareId': paged.shareId,
    });
  });
}
