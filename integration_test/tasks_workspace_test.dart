import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';
import 'package:quitepaper/features/tasks/presentation/tasks_view.dart';

/// Synthetic isolated vault only. Runs on Linux or Android with the same target.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Tasks browse, date, completion, undo, jump and batched benchmark',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final repository = DriftNotesRepository(db);
      final service = TaskService(
        db,
        repository,
        inboxNamespace: () async => 'synthetic-native-test',
      );
      final now = DateTime(2026, 11, 25);
      final watch = Stopwatch()..start();
      const notes = 120, tasksPerNote = 50;
      await db.transaction(() async {
        for (var i = 0; i < notes; i++) {
          final md =
              '# Project $i\n${List.generate(tasksPerNote, (j) {
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
              ? md
              : jsonEncode(const RichDocumentParser().parse(md).toJson());
          await repository.saveNote(
            Note(
              id: 'synthetic-${i.toString().padLeft(3, '0')}',
              title: 'Project $i',
              content: content,
              tags: ['work/project'],
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
      final writeMs = watch.elapsedMilliseconds;
      await db.customStatement('DELETE FROM task_index');
      await db.customStatement(
        'INSERT OR IGNORE INTO task_dirty SELECT id FROM notes',
      );
      watch.reset();
      var batches = 0;
      while (await db.repairTaskIndex() > 0) {
        batches++;
        await Future<void>.delayed(Duration.zero);
      }
      final rebuildMs = watch.elapsedMilliseconds;
      watch.reset();
      final rows = await db.watchTaskRows().first;
      final readMs = watch.elapsedMilliseconds;
      expect(rows.length, notes * tasksPerNote);
      final sample = await repository.getNoteById('synthetic-000');
      var item = TaskItem(
        note: sample!,
        version: TaskDocument.version(sample.content),
        occurrence: TaskDocument.extract(sample.content)[1],
      );
      final dateCommit = await service.setDate(
        item,
        TaskDate.tryParse('2026-11-24'),
      );
      final live = dateCommit.note;
      item = TaskItem(
        note: live,
        version: TaskDocument.version(live.content),
        occurrence: TaskDocument.extract(live.content)[1],
      );
      final completion = await service.setCompleted(item, true);
      await completion.undo.run();
      expect(
        TaskDocument.extract(
          (await repository.getNoteById(sample.id))!.content,
        )[1].completed,
        false,
      );
      // All console output is synthetic aggregate timing, never note content.
      debugPrint(
        'TASKS_BENCHMARK ${jsonEncode({'notes': notes, 'tasks': rows.length, 'write_ms': writeMs, 'rebuild_ms': rebuildMs, 'batches': batches, 'read_ms': readMs, 'mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'})}',
      );
      Note? selected;
      TaskItem? selectedTask;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(prefs),
            taskSessionProvider.overrideWithValue(true),
            taskServiceProvider.overrideWithValue(service),
            taskClockProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  if (MediaQuery.sizeOf(context).width < 900) {
                    return const TasksView();
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 360,
                        child: TasksView(
                          onNoteSelected: (note, task) => setState(() {
                            selected = note;
                            selectedTask = task;
                          }),
                        ),
                      ),
                      Expanded(
                        child: selected == null
                            ? const Center(child: Text('Select a task'))
                            : EditorScreen(
                                key: ValueKey(selected!.id),
                                note: selected!,
                                initialTask: selectedTask,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
      await tester.tap(find.byTooltip('Search tasks'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search tasks and notes'),
        'Task 1',
      );
      await tester.pumpAndSettle();
      expect(find.text('Task 1 café বাংলা 😀'), findsWidgets);
      await tester.tap(find.text('Task 1 café বাংলা 😀').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open note'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
