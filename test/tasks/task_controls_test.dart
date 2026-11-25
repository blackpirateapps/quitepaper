import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';
import 'package:quitepaper/features/tasks/presentation/tasks_view.dart';

Note _note(String id, String title, String content, List<String> tags) => Note(
  id: id,
  title: title,
  content: content,
  tags: tags,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
List<TaskItem> _items(Note note) => TaskDocument.extract(note.content)
    .map(
      (task) => TaskItem(
        note: note,
        version: TaskDocument.version(note.content),
        occurrence: task,
      ),
    )
    .toList();

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final notes = [
    _note('work', 'Client note', '- [ ] Send estimate\n- [x] Invoice sent', [
      'work/client',
    ]),
    _note('home', 'Home note', '- [ ] Buy milk', ['home']),
    _note('none', 'Other note', '- [ ] Unrelated', []),
  ];
  for (final dark in [false, true]) {
    testWidgets(
      'phone multi-tag sheet searches, stages, cancels and clears filters dark=$dark',
      (tester) async {
        phone(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskItemsProvider.overrideWith(
                (ref) => Stream.value(notes.expand(_items).toList()),
              ),
              taskSessionProvider.overrideWithValue(true),
              taskIndexFailuresProvider.overrideWith((ref) => Stream.value(0)),
              taskClockProvider.overrideWithValue(() => DateTime(2026, 11, 25)),
            ],
            child: MaterialApp(
              theme: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
                extensions: [dark ? AppColors.dark : AppColors.light],
              ),
              home: const Scaffold(body: TasksView()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('All tags'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'CLIENT');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-filter-tag-work/client')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-filter-tag-home')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('task-filter-tag-work/client')),
        );
        await tester.tap(find.byTooltip('Clear tag search'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-filter-tag-home')));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('2 tags'), findsOneWidget);
        expect(find.text('Send estimate'), findsOneWidget);
        expect(find.text('Buy milk'), findsOneWidget);
        expect(find.text('Unrelated'), findsNothing);
        expect(find.text('Open 2'), findsOneWidget);
        expect(find.text('Completed 1'), findsOneWidget);
        await tester.tap(find.text('2 tags'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear filters'));
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('2 tags'), findsOneWidget);
        await tester.tap(find.byTooltip('Search tasks'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'estimate');
        await tester.pumpAndSettle();
        expect(find.text('Open 1'), findsOneWidget);
        expect(find.text('Buy milk'), findsNothing);
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2 tags'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Search tags'),
          'missing',
        );
        await tester.pumpAndSettle();
        expect(find.text('No tags match your search.'), findsOneWidget);
        await tester.tap(find.text('Clear filters'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('All tags'), findsOneWidget);
        expect(find.text('Open 3'), findsOneWidget);
        expect(find.text('Unrelated'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'source heading and subtitle open exact notes; rename/delete cancel and Undo persist',
    (tester) async {
      phone(tester);
      final db = AppDatabase.memory();
      final repository = DriftNotesRepository(db);
      addTearDown(db.close);
      for (final note in notes) {
        await repository.saveNote(note);
      }
      Note? opened;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            taskSessionProvider.overrideWithValue(true),
            taskClockProvider.overrideWithValue(() => DateTime(2026, 11, 25)),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
            home: Scaffold(
              body: TasksView(onNoteSelected: (note, task) => opened = note),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open note: Client note'));
      await tester.pumpAndSettle();
      expect(opened!.id, 'work');
      await tester.tap(find.byTooltip('Open note: Home note'));
      await tester.pumpAndSettle();
      expect(opened!.id, 'home');
      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Buy bread',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Buy milk'), findsOneWidget);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Task name'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a task name on a single line.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Task name'),
        'Buy bread',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Buy bread'), findsOneWidget);
      expect(
        TaskDocument.extract(
          (await repository.getNoteById('home'))!.content,
        ).single.text,
        'Buy bread',
      );
      // Clear the rename toast before checking deletion and its own Undo.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy bread'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Buy bread'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Buy bread'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Buy bread'), findsOneWidget);
      expect(
        TaskDocument.extract(
          (await repository.getNoteById('home'))!.content,
        ).single.text,
        'Buy bread',
      );
      expect(tester.takeException(), isNull);
      await db.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test(
    'any selected tag includes descendants and combines with task search',
    () {
      final items = notes.expand(_items).toList();
      expect(filterTasks(items, '', {'work', 'home'}), hasLength(3));
      expect(
        filterTasks(items, 'estimate', {'work', 'home'}).single.note.id,
        'work',
      );
      expect(filterTasks(items, '', {'wor'}), isEmpty);
      expect(filterTasks(items, '', {}), hasLength(4));
    },
  );
}
