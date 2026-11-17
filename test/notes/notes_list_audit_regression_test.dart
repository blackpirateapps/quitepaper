import 'dart:convert';

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
}
