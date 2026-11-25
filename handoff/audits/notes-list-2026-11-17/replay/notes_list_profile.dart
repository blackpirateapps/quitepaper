// Isolated native profile harness. Uses synthetic data in an in-memory database.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

final capture = GlobalKey();
final harness = GlobalKey<AuditHostState>();
final errors = <String>[];
final metrics = <String, Object?>{};
final timings = <ui.FrameTiming>[];
bool recording = false;
late final ProviderContainer providers;
late final Directory output;

Map<String, Object> distribution(List<num> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) throw StateError('No measurements');
  num percentile(double p) => sorted[((sorted.length - 1) * p).round()];
  return {
    'count': sorted.length,
    'median': percentile(.5),
    'p95': percentile(.95),
    'max': sorted.last,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  output = Directory(Platform.environment['QP_NOTES_AUDIT_OUT']!);
  await output.create(recursive: true);
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    errors.add('$error');
    return true;
  };
  // Isolate this replay from real user preferences.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final repo = DriftNotesRepository(db);
  final now = DateTime(2026, 11, 17, 12);
  final body =
      '---\nmood: 7\n---\n'
      '${List.filled(20, 'Audit **paragraph** with a [link](https://example.test) and inline `code`.').join('\n')}'
      '\n| Task | Status |\n| --- | --- |\n| Test | Open |';
  await db.batch(
    (b) => b.insertAll(
      db.notesTable,
      List.generate(
        10000,
        (i) => NotesTableCompanion.insert(
          id: 'native-${i.toString().padLeft(5, '0')}',
          title: Value('Audit note ${i.toString().padLeft(5, '0')}'),
          content: Value(body),
          createdAt: now.subtract(Duration(minutes: i)),
          updatedAt: now.subtract(Duration(minutes: i)),
        ),
      ),
    ),
  );
  metrics['environment'] = {
    'mode': 'Flutter Linux profile',
    'notesInDatabase': 10000,
    'bodyCharactersPerNote': body.length,
    'database': 'in-memory SQLite',
    'mobileLimit':
        'Phone viewport rendered by Linux engine; no physical mobile GPU/OS or IME',
  };
  for (final q in <String, NotesQuery>{
    'updated': NotesQuery.defaultQuery,
    'title': const NotesQuery(sort: NotesSort(field: SortField.title)),
    'contentLinks': const NotesQuery(
      filter: NotesFilter(contentFilters: {ContentFilter.hasLinks}),
    ),
  }.entries) {
    final times = <int>[];
    for (var i = 0; i < 21; i++) {
      final timer = Stopwatch()..start();
      final page = await repo.executeNotesQuery(q.value);
      timer.stop();
      if (page.notes.length != 40) {
        throw StateError('Unexpected query size: ${page.notes.length}');
      }
      if (i > 0) times.add(timer.elapsedMicroseconds);
    }
    metrics['query_${q.key}_us'] = distribution(times);
  }
  for (final count in [400, 500, 600, 1000]) {
    NoteMetadataExtractor.clearCache();
    final notes = List.generate(
      count,
      (i) => Note(
        id: 'cache-$i',
        title: 'Cache $i',
        content: body,
        createdAt: now,
        updatedAt: now,
      ),
    );
    NoteMetadataExtractor.prewarmAll(notes);
    final times = <int>[];
    for (var trial = 0; trial < 7; trial++) {
      final timer = Stopwatch()..start();
      NoteMetadataExtractor.prewarmAll(notes);
      timer.stop();
      times.add(timer.elapsedMicroseconds);
    }
    metrics['prewarm_${count}_us'] = distribution(times);
  }
  NoteMetadataExtractor.clearCache();
  providers = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  WidgetsBinding.instance.addTimingsCallback((batch) {
    if (recording) timings.addAll(batch);
  });
  runApp(
    UncontrolledProviderScope(
      container: providers,
      child: AuditHost(key: harness),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 2));
  try {
    final n = providers.read(notesCollectionProvider.notifier);
    for (
      var i = 0;
      i < 500 && providers.read(notesCollectionProvider).initialLoading;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final loadTimer = Stopwatch()..start();
    while (providers.read(notesCollectionProvider).notes.length < 1000) {
      await n.loadMore();
    }
    loadTimer.stop();
    metrics['load_1000_notes_us'] = loadTimer.elapsedMicroseconds;
    await Future<void>.delayed(const Duration(seconds: 2));
    for (final size in {
      'desktop': const Size(1280, 680),
      'phone': const Size(390, 680),
    }.entries) {
      harness.currentState!.resize(size.value);
      await Future<void>.delayed(const Duration(seconds: 1));
      // A very tall unmeasured lazy list has an estimated extent. Find its
      // position through a real tile instead of guessing an extent threshold.
      await WidgetsBinding.instance.endOfFrame;
      final position = listScrollPosition();
      metrics['layout_${size.key}'] = {
        'actualRenderDp': [
          capture.currentContext!.size!.width,
          capture.currentContext!.size!.height,
        ],
        'loadedNotesBeforeScroll': providers
            .read(notesCollectionProvider)
            .notes
            .length,
        'scrollExtent': position.maxScrollExtent,
      };
      position.jumpTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await position.animateTo(
        500,
        duration: const Duration(milliseconds: 600),
        curve: Curves.linear,
      );
      position.jumpTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      timings.clear();
      recording = true;
      await position.animateTo(
        10000,
        duration: const Duration(seconds: 4),
        curve: Curves.linear,
      );
      await position.animateTo(
        0,
        duration: const Duration(seconds: 4),
        curve: Curves.linear,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      recording = false;
      metrics['scroll_${size.key}'] = {
        'viewportDp': [size.value.width, size.value.height],
        'loadedNotes': providers.read(notesCollectionProvider).notes.length,
        'frameBuildUs': distribution(
          timings.map((f) => f.buildDuration.inMicroseconds).toList(),
        ),
        'frameRasterUs': distribution(
          timings.map((f) => f.rasterDuration.inMicroseconds).toList(),
        ),
        'frameTotalSpanUs': distribution(
          timings.map((f) => f.totalSpan.inMicroseconds).toList(),
        ),
        'framesBuildOrRasterOver16667us': timings
            .where(
              (f) =>
                  f.buildDuration.inMicroseconds > 16667 ||
                  f.rasterDuration.inMicroseconds > 16667,
            )
            .length,
        'mountedTilesAtRest': tileCount(),
        'drive':
            'programmatic ScrollPosition.animateTo, two 4s linear sweeps, after warmup',
      };
      await screenshot('${size.key}.png');
    }
    metrics['beforeRefresh'] = providers
        .read(notesCollectionProvider)
        .notes
        .length;
    final refreshTimer = Stopwatch()..start();
    await n.refresh();
    refreshTimer.stop();
    metrics['afterRefresh'] = providers
        .read(notesCollectionProvider)
        .notes
        .length;
    metrics['refreshUs'] = refreshTimer.elapsedMicroseconds;
  } catch (error, stack) {
    errors.add('$error\n$stack');
    await screenshot('harness-error.png');
  }
  metrics['errors'] = errors;
  await File(
    '${output.path}/native-profile.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
  stdout.writeln('NOTES_AUDIT_COMPLETE ${jsonEncode(metrics)}');
  runApp(const SizedBox.shrink());
  await Future<void>.delayed(const Duration(milliseconds: 500));
  providers.dispose();
  await db.close();
  exit(errors.isEmpty ? 0 : 1);
}

ScrollPosition listScrollPosition() {
  ScrollPosition? found;
  void visit(Element e) {
    if (e.widget is NoteListTile) {
      found ??= Scrollable.maybeOf(e)?.position;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return found ??
      (throw StateError(
        'Notes scroll position not found; loaded=${providers.read(notesCollectionProvider).notes.length}',
      ));
}

int tileCount() {
  var count = 0;
  void visit(Element e) {
    if (e.widget is NoteListTile) count++;
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return count;
}

Future<void> screenshot(String name) async {
  final boundary =
      capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('${output.path}/$name').writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

class AuditHost extends StatefulWidget {
  const AuditHost({super.key});
  @override
  State<AuditHost> createState() => AuditHostState();
}

class AuditHostState extends State<AuditHost> {
  Size size = const Size(1280, 680);
  void resize(Size value) => setState(() {
    size = value;
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Quiet Paper Notes Audit',
    theme: AppTheme.light(),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: RepaintBoundary(key: capture, child: const NotesScreen()),
        ),
      ),
    ),
  );
}
