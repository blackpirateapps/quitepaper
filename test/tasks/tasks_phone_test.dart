import 'dart:async';

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
import 'package:quitepaper/features/tasks/presentation/task_date_picker.dart';
import 'package:quitepaper/features/tasks/presentation/tasks_view.dart';

final _now = DateTime(2026, 11, 25);

Note _note(String id, String title, String content) => Note(
  id: id,
  title: title,
  content: content,
  createdAt: _now,
  updatedAt: _now,
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

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: (dark ? ThemeData.dark() : ThemeData.light()).copyWith(
    extensions: [dark ? AppColors.dark : AppColors.light],
  ),
  home: Scaffold(body: child),
);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final dark in [false, true]) {
    testWidgets(
      'phone list shares source headings and expands one task ($dark)',
      (tester) async {
        phone(tester);
        final items = [
          ..._items(_note('app', 'Name the app', '- [ ] new app')),
          ..._items(
            _note(
              'bag',
              'Bag package',
              '- [ ] Shirts 3x\n- [ ] Pants 1x\n- [ ] Jangia 5x\n- [ ] Shirt 3x\n- [ ] Umbrella',
            ),
          ),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taskItemsProvider.overrideWith((ref) => Stream.value(items)),
              taskSessionProvider.overrideWithValue(true),
              taskIndexFailuresProvider.overrideWith((ref) => Stream.value(0)),
              taskClockProvider.overrideWithValue(() => _now),
            ],
            child: _app(TasksView(onMenu: () {}), dark: dark),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Open 6'), findsOneWidget);
        expect(find.text('All tags'), findsOneWidget);
        expect(find.text('Bag package'), findsOneWidget);
        expect(find.text('Name the app'), findsOneWidget);
        expect(find.text('Add due date'), findsNothing);
        for (final checkbox in tester.widgetList<Checkbox>(
          find.byType(Checkbox),
        )) {
          expect(checkbox.shape, isA<CircleBorder>());
        }
        await tester.tap(find.text('Shirts 3x'));
        await tester.pumpAndSettle();
        expect(find.text('Add due date'), findsOneWidget);
        expect(find.text('Open note'), findsOneWidget);
        await tester.tap(find.text('Pants 1x'));
        await tester.pumpAndSettle();
        expect(find.text('Open note'), findsOneWidget);
        await tester.tap(find.text('Pants 1x'));
        await tester.pumpAndSettle();
        expect(find.text('Open note'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('first phone load hides counts until notes have been indexed', (
    tester,
  ) async {
    phone(tester);
    final stream = StreamController<List<TaskItem>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskItemsProvider.overrideWith((ref) => stream.stream),
          taskSessionProvider.overrideWithValue(true),
          taskIndexFailuresProvider.overrideWith((ref) => Stream.value(0)),
          taskClockProvider.overrideWithValue(() => _now),
        ],
        child: _app(const TasksView()),
      ),
    );
    await tester.pump();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Open 0'), findsNothing);
    expect(find.text('Finding tasks in your notes…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Your note checkboxes will appear here.'), findsNothing);
    stream.add(_items(_note('app', 'Name the app', '- [ ] new app')));
    await tester.pumpAndSettle();
    expect(find.text('Open 1'), findsOneWidget);
    expect(find.text('Finding tasks in your notes…'), findsNothing);
    expect(find.text('new app'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'phone date sheet dismisses, selects presets and clears explicitly',
    (tester) async {
      phone(tester);
      TaskDateSelection? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTaskDatePicker(
                  context,
                  today: TaskDate.local(_now),
                  current: TaskDate.tryParse('2026-11-27'),
                  taskTitle: 'Shirts 3x',
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('Open picker'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Shirts 3x'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
      }

      await open();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
      for (final preset in [
        ('Today', '2026-11-25'),
        ('Tomorrow', '2026-11-26'),
        ('In a week', '2026-12-02'),
      ]) {
        await open();
        await tester.tap(find.text(preset.$1));
        await tester.pumpAndSettle();
        expect(result!.value.toString(), preset.$2);
      }
      await open();
      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Clear date'));
      await tester.pumpAndSettle();
      expect(result!.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone expansion preserves canonical date, completion and undo commands',
    (tester) async {
      phone(tester);
      final db = AppDatabase.memory();
      final repository = DriftNotesRepository(db);
      addTearDown(db.close);
      Note? openedNote;
      await repository.saveNote(
        _note('bag', 'Bag package', '- [ ] Shirts 3x\n- [ ] Pants 1x'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            taskSessionProvider.overrideWithValue(true),
            taskClockProvider.overrideWithValue(() => _now),
          ],
          child: _app(
            TasksView(onNoteSelected: (note, task) => openedNote = note),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shirts 3x'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open note'));
      await tester.pumpAndSettle();
      expect(openedNote!.id, 'bag');
      await tester.tap(find.text('Add due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      final note = (await repository.getNoteById('bag'))!;
      expect(
        TaskDocument.extract(note.content).first.metadata!.due.toString(),
        '2026-11-26',
      );
      expect(find.text('Upcoming'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Open 1'), findsOneWidget);
      expect(find.text('Completed 1'), findsOneWidget);
      // Dismiss the date toast to reach the completion toast queued after it.
      final messenger = tester.state<ScaffoldMessengerState>(
        find.byType(ScaffoldMessenger),
      );
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Open 2'), findsOneWidget);
      expect(
        TaskDocument.extract(
          (await repository.getNoteById('bag'))!.content,
        ).first.completed,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      // Close active Drift streams before Riverpod disposes their subscriptions.
      await db.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
