import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';

/// Run with `flutter run -d linux --release -t tool/benchmark_tasks.dart`.
/// Synthetic in-memory data; no real vault/key/account initialization.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.memory();
  final repo = DriftNotesRepository(db);
  final clock = Stopwatch()..start();
  final now = DateTime(2026, 11, 25);
  const notes = 120, perNote = 50;
  final candidates = <TaskItem>[];
  await db.transaction(() async {
    for (var i = 0; i < notes; i++) {
      final markdown =
          '# Project $i\n${List.generate(perNote, (j) {
            final due = j % 4 == 0
                ? '2026-11-24'
                : j % 4 == 1
                ? '2026-11-25'
                : j % 4 == 2
                ? '2026-12-02'
                : null;
            final metadata = j % 5 == 4 ? '' : TaskMetadata(id: const Uuid().v5(Namespace.url.value, 'synthetic:$i:$j'), due: TaskDate.tryParse(due)).comment;
            return '- [${j % 4 == 0 ? 'x' : ' '}] Task $j café বাংলা 😀$metadata';
          }).join('\n')}\n\n```md\n- [ ] literal\n```';
      final content = i.isEven
          ? markdown
          : jsonEncode(const RichDocumentParser().parse(markdown).toJson());
      final note = Note(
        id: 'synthetic-$i',
        title: 'Project $i',
        content: content,
        tags: ['work/project'],
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveNote(note);
      candidates.addAll(
        TaskDocument.extract(
          content,
        ).map((t) => TaskItem(note: note, version: 'benchmark', occurrence: t)),
      );
    }
  });
  final writeMs = clock.elapsedMilliseconds;
  await db.customStatement('DELETE FROM task_index');
  await db.customStatement(
    'INSERT OR IGNORE INTO task_dirty SELECT id FROM notes',
  );
  clock.reset();
  var batches = 0;
  while (await db.repairTaskIndex() > 0) {
    batches++;
    await Future<void>.delayed(Duration.zero);
  }
  final rebuildMs = clock.elapsedMilliseconds;
  clock.reset();
  final rows = await db.watchTaskRows().first;
  final readMs = clock.elapsedMilliseconds;
  final samples = <int>[];
  for (var i = 0; i < 30; i++) {
    clock.reset();
    final results = filterTasks(candidates, 'Task 1 café', const {'work'})
      ..sort((a, b) => compareTasks(a, b, TaskDate.local(now)));
    if (results.isEmpty) throw StateError('Benchmark search failed');
    samples.add(clock.elapsedMicroseconds);
  }
  samples.sort();
  stdout.writeln(
    'TASKS_BENCHMARK ${jsonEncode({'mode': const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug', 'notes': notes, 'tasks': rows.length, 'write_ms': writeMs, 'rebuild_ms': rebuildMs, 'batches': batches, 'read_ms': readMs, 'search_sort_median_us': samples[15], 'search_sort_p95_us': samples[28], 'search_samples': samples.length})}',
  );
  await db.close();
  exit(rows.length == notes * perNote ? 0 : 1);
}
