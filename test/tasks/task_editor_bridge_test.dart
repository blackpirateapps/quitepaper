import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_checklist_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tasks/application/task_editor_bridge.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';

const id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
void main() {
  testWidgets(
    'workspace date mutation flushes dirty Visual text and shares editor undo',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final repository = DriftNotesRepository(db);
      final note = Note(
        id: 'bridge',
        title: 'Source',
        content: '- [ ] Original <!-- qp-task:v1 id=$id -->',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await repository.saveNote(note);
      final service = TaskService(
        db,
        repository,
        inboxNamespace: () async => 'synthetic',
      );
      final item = TaskItem(
        note: note,
        version: TaskDocument.version(note.content),
        occurrence: TaskDocument.extract(note.content).single,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(home: EditorScreen(note: note)),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<RichChecklistEditor>(find.byType(RichChecklistEditor))
          .controller;
      controller.updateBlockSpans(0, const [
        RichInlineSpan(text: 'Pending Visual text'),
      ]);
      await tester.pump();
      final result = await service.setDate(
        item,
        TaskDate.tryParse('2026-11-27'),
      );
      await tester.pumpAndSettle();
      var saved = (await repository.getNoteById(note.id))!;
      var task = TaskDocument.extract(saved.content).single;
      expect(task.text, 'Pending Visual text');
      expect(task.metadata!.due.toString(), '2026-11-27');
      controller.undo();
      await tester.pumpAndSettle();
      await TaskEditorBridge.forNote(note.id)!.prepare();
      saved = (await repository.getNoteById(note.id))!;
      task = TaskDocument.extract(saved.content).single;
      expect(task.text, 'Pending Visual text');
      expect(task.metadata!.due, isNull);
      await expectLater(result.undo.run(), throwsA(isA<StaleTask>()));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
