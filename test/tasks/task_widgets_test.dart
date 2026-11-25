import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';
import 'package:quitepaper/features/tasks/presentation/task_date_picker.dart';
import 'package:quitepaper/features/tasks/presentation/tasks_view.dart';

TaskItem task(
  String id,
  String text, {
  bool completed = false,
  String? due,
  List<String> tags = const [],
}) {
  final n = Note(
    id: id,
    title: 'Source $id',
    content: '',
    tags: tags,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  return TaskItem(
    note: n,
    version: 'test',
    occurrence: TaskOccurrence(
      ordinal: 0,
      start: 0,
      end: 0,
      checkOffset: 0,
      text: text,
      completed: completed,
      metadata: due == null
          ? null
          : TaskMetadata(
              id: '03fe77cf-8000-4d05-ba80-d365fd69b17c',
              due: TaskDate.tryParse(due),
            ),
    ),
  );
}

void main() {
  testWidgets(
    'date presets stage, Cancel discards, Save commits, Clear is explicit',
    (tester) async {
      TaskDateSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showTaskDatePicker(
                    context,
                    today: TaskDate.tryParse('2026-11-25')!,
                    current: TaskDate.tryParse('2026-11-27'),
                  );
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In a week'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.value.toString(), '2026-12-02');
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear date'));
      await tester.pumpAndSettle();
      expect(result!.value, isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'narrow large text list groups, counts and combined search/tag in ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final items = [
          task('a', 'Estimate', due: '2026-11-24', tags: ['work/client']),
          task('b', 'Layout', due: '2026-11-25'),
          task(
            'c',
            'Completed estimate',
            completed: true,
            due: '2026-11-23',
            tags: ['work/client'],
          ),
          task('d', 'Later', due: '2026-11-28'),
          task('e', 'Undated'),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskItemsProvider.overrideWith((ref) => Stream.value(items)),
              taskSessionProvider.overrideWithValue(true),
              taskIndexFailuresProvider.overrideWith((ref) => Stream.value(0)),
              taskClockProvider.overrideWithValue(() => DateTime(2026, 11, 25)),
            ],
            child: MaterialApp(
              theme: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
                extensions: [dark ? AppColors.dark : AppColors.light],
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: const Scaffold(body: TasksView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open 4'), findsOneWidget);
        expect(find.text('Completed 1'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Due today'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Search tasks'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'estimate');
        await tester.pumpAndSettle();
        expect(find.text('Open 1'), findsOneWidget);
        expect(find.text('Completed 1'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide search'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Open 1'), findsOneWidget);
        await tester.tap(find.byTooltip('Search tasks'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'estimate',
        );
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('#work').last);
        await tester.pumpAndSettle();
        expect(find.text('Estimate'), findsOneWidget);
        await tester.tap(find.text('Completed 1'));
        await tester.pumpAndSettle();
        expect(find.text('Completed estimate'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'local calendar grouping and deterministic ordering use owning tag subtree',
    () {
      final today = TaskDate.tryParse('2026-11-25')!;
      final tasks = [
        task('e', 'none'),
        task('d', 'later', due: '2026-11-26'),
        task('c', 'today', due: '2026-11-25'),
        task('b', 'late', due: '2026-11-24'),
        task('a', 'done', completed: true, due: '2026-11-24'),
      ];
      tasks.sort((a, b) => compareTasks(a, b, today));
      expect(tasks.map((t) => t.group(today)), [
        TaskGroup.overdue,
        TaskGroup.today,
        TaskGroup.upcoming,
        TaskGroup.undated,
        TaskGroup.completed,
      ]);
      expect(tasks[2].group(today.addDays(2)), TaskGroup.overdue);
      expect(
        filterTasks(
          [
            task('a', 'বাংলা café', tags: ['work/project']),
          ],
          'বাংলা',
          'work',
        ),
        hasLength(1),
      );
      expect(
        filterTasks(
          [
            task('a', 'বাংলা café', tags: ['work/project']),
          ],
          'café',
          'wor',
        ),
        isEmpty,
      );
    },
  );
}
