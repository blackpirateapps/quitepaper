import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_editor_bridge.dart';
import 'package:quitepaper/features/tasks/application/task_providers.dart';

void main() {
  test(
    'open read-only session immediately excludes its note and detaching restores eligibility',
    () async {
      final db = AppDatabase.memory();
      final repo = DriftNotesRepository(db);
      final note = Note(
        id: 'readonly',
        title: 'Read only',
        content: '- [ ] Task',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await repo.saveNote(note);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          taskSessionProvider.overrideWithValue(true),
        ],
      );
      final subscription = container.listen(taskItemsProvider, (_, next) {});
      final bridge = TaskEditorBridge(
        noteId: note.id,
        prepare: () async => note,
        apply: (_) async => note,
        reveal: (_) {},
      );
      bridge.attach();
      try {
        expect(await container.read(taskItemsProvider.future), hasLength(1));
        bridge.setReadOnly(true);
        expect(container.read(taskExcludedNotesProvider), contains(note.id));
        expect(await container.read(taskItemsProvider.future), isEmpty);
        bridge.detach();
        expect(container.read(taskExcludedNotesProvider), isEmpty);
        expect(await container.read(taskItemsProvider.future), hasLength(1));
      } finally {
        bridge.detach();
        subscription.close();
        container.dispose();
        await db.close();
      }
    },
  );
}
