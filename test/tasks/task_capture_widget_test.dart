import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/presentation/task_capture_dialog.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  setUp(() {
    db = AppDatabase.memory();
    repo = DriftNotesRepository(db);
  });
  tearDown(() async => db.close());
  Future<void> open(WidgetTester tester, TaskService service) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          taskServiceProvider.overrideWithValue(service),
          taskDestinationsProvider.overrideWith((ref) => Stream.value([])),
          taskClockProvider.overrideWithValue(() => DateTime(2026, 11, 25)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTaskCapture(context),
                child: const Text('Capture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'hardware Enter submits once and pending write disables duplicate submits',
    (tester) async {
      final namespace = Completer<String>();
      await open(
        tester,
        TaskService(db, repo, inboxNamespace: () => namespace.future),
      );
      await tester.enterText(find.byType(TextField), 'Unicode বাংলা 😀');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      namespace.complete('synthetic');
      await tester.pumpAndSettle();
      final notes = await db.getAllNotesRaw();
      expect(notes, hasLength(1));
      expect(TaskDocument.extract(notes.single.content), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'multiline rejection and local failure retain draft until safe retry',
    (tester) async {
      await open(
        tester,
        TaskService(db, repo, inboxNamespace: () async => 'synthetic'),
      );
      await tester.enterText(find.byType(TextField), 'one\ntwo');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(find.text('Enter one task on a single line.'), findsOneWidget);
      expect(await db.getAllNotesRaw(), isEmpty);
      await tester.enterText(find.byType(TextField), 'Retained draft');
      await db.customStatement(
        'CREATE TRIGGER reject_capture BEFORE INSERT ON task_index BEGIN SELECT RAISE(ABORT,"test"); END',
      );
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(find.text('Retained draft'), findsOneWidget);
      expect(find.textContaining('Your draft is retained'), findsOneWidget);
      expect(await db.getAllNotesRaw(), isEmpty);
      await db.customStatement('DROP TRIGGER reject_capture');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(await db.getAllNotesRaw(), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'mobile composition action does not submit uncommitted IME text',
    (tester) async {
      await open(
        tester,
        TaskService(db, repo, inboxNamespace: () async => 'synthetic'),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '日本語',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await db.getAllNotesRaw(), isEmpty);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '日本語',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await db.getAllNotesRaw(), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
