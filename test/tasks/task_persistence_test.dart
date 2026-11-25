import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';

const id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
const captureId = '78669d73-9ff1-4f09-b820-4a92c75f489a';
Note note(String id, String content) => Note(
  id: id,
  title: 'Work',
  content: content,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
TaskItem item(Note note, {int ordinal = 0}) => TaskItem(
  note: note,
  version: TaskDocument.version(note.content),
  occurrence: TaskDocument.extract(note.content)[ordinal],
);
void main() {
  late AppDatabase db;
  late DriftNotesRepository repo;
  late TaskService service;
  setUp(() {
    db = AppDatabase.memory();
    repo = DriftNotesRepository(db);
    service = TaskService(db, repo, inboxNamespace: () async => 'test-vault');
  });
  tearDown(() async => db.close());
  test(
    'canonical save indexes atomically, archive/trash/protection hide and restore repair',
    () async {
      await repo.saveNote(note('n', '- [ ] do it'));
      expect(await db.watchTaskRows().first, hasLength(1));
      await repo.archiveNote('n');
      expect(await db.watchTaskRows().first, isEmpty);
      await repo.unarchiveNote('n');
      await db.repairTaskIndex();
      expect(await db.watchTaskRows().first, hasLength(1));
      await repo.trashNote('n');
      expect(await db.watchTaskRows().first, isEmpty);
      await repo.restoreFromTrash('n');
      await db.repairTaskIndex();
      expect(await db.watchTaskRows().first, hasLength(1));
      await repo.saveNote(
        note('n', '<!-- quiet-paper-encrypted-note-v1: secret -->'),
      );
      expect(await db.watchTaskRows().first, isEmpty);
      expect(await db.customSelect('SELECT * FROM task_index').get(), isEmpty);
    },
  );
  test(
    'direct write is durably dirty; bounded repair restores the derived index',
    () async {
      for (var i = 0; i < 5; i++) {
        await repo.saveNote(note('n$i', '- [ ] old'));
      }
      await db.customStatement("UPDATE notes SET content='- [ ] new'");
      expect(await db.watchTaskRows().first, isEmpty);
      expect(await db.repairTaskIndex(batchSize: 2), 2);
      expect(await db.watchTaskRows().first, hasLength(2));
      expect(await db.repairTaskIndex(batchSize: 2), 2);
      expect(await db.repairTaskIndex(batchSize: 2), 1);
      final rows = await db.watchTaskRows().first;
      expect(rows.map((r) => r.read<String>('text')), everyElement('new'));
      await db.eraseAllLocalVaultData();
      expect(await db.customSelect('SELECT * FROM task_index').get(), isEmpty);
    },
  );
  test(
    'stale legacy command and unavailable session do not overwrite committed text',
    () async {
      final original = note('n', '- [ ] old');
      await repo.saveNote(original);
      await repo.saveNote(original.copyWith(content: '- [ ] new'));
      await expectLater(
        service.setCompleted(item(original), true),
        throwsA(isA<StaleTask>()),
      );
      expect((await repo.getNoteById('n'))!.content, '- [ ] new');
      final locked = TaskService(
        db,
        repo,
        inboxNamespace: () async => 'test',
        isAvailable: () => false,
      );
      await expectLater(
        locked.setDate(item(original), TaskDate.tryParse('2026-11-27')),
        throwsA(isA<StaleTask>()),
      );
    },
  );
  test(
    'explicit completion and field-aware undo preserve concurrent text and date',
    () async {
      final original = note('n', '- [ ] old <!-- qp-task:v1 id=$id -->');
      await repo.saveNote(original);
      final commit = await service.setCompleted(item(original), true);
      var live = (await repo.getNoteById('n'))!;
      live = live.copyWith(
        content: TaskDocument.setDate(
          live.content,
          TaskDocument.extract(live.content).single,
          TaskDate.tryParse('2026-11-27'),
        ).replaceFirst('old', 'new'),
      );
      await repo.saveNote(live);
      await commit.undo.run();
      final task = TaskDocument.extract(
        (await repo.getNoteById('n'))!.content,
      ).single;
      expect(task.completed, false);
      expect(task.text, 'new');
      expect(task.metadata!.due.toString(), '2026-11-27');
    },
  );
  test(
    'date command assigns identity, clear retains it and competing undo refuses',
    () async {
      final original = note('n', '- [ ] old');
      await repo.saveNote(original);
      final commit = await service.setDate(
        item(original),
        TaskDate.tryParse('2026-11-27'),
      );
      final live = (await repo.getNoteById('n'))!;
      final task = TaskDocument.extract(live.content).single;
      expect(task.metadata, isNotNull);
      await service.setDate(item(live), TaskDate.tryParse('2026-11-28'));
      await expectLater(commit.undo.run(), throwsA(isA<StaleTask>()));
      final current = (await repo.getNoteById('n'))!;
      await service.setDate(item(current), null);
      expect(
        TaskDocument.extract(
          (await repo.getNoteById('n'))!.content,
        ).single.metadata!.id,
        task.metadata!.id,
      );
    },
  );
  test(
    'capture retries converge on renamed inbox; undo preserves later edits',
    () async {
      final first = await service.capture(text: 'First', captureId: captureId);
      await repo.saveNote(first.note.copyWith(title: 'Renamed'));
      final retry = await service.capture(text: 'First', captureId: captureId);
      expect(retry.note.id, first.note.id);
      expect(retry.note.title, 'Renamed');
      expect(TaskDocument.extract(retry.note.content), hasLength(1));
      final second = await service.capture(text: 'Second', captureId: id);
      expect(second.note.id, first.note.id);
      expect(TaskDocument.extract(second.note.content), hasLength(2));
      await second.undo.run();
      expect(
        TaskDocument.extract((await repo.getNoteById(first.note.id))!.content),
        hasLength(1),
      );
      await repo.saveNote(
        first.note.copyWith(
          content: first.note.content.replaceFirst('First', 'Edited'),
        ),
      );
      await expectLater(first.undo.run(), throwsA(isA<StaleTask>()));
      await repo.trashNote(first.note.id);
      await expectLater(
        service.capture(text: 'Next', captureId: id),
        throwsA(isA<StaleTask>()),
      );
    },
  );
  test(
    'capture transaction rollback leaves neither inbox nor partial append',
    () async {
      await db.customStatement(
        'CREATE TRIGGER reject_task BEFORE INSERT ON task_index BEGIN SELECT RAISE(ABORT, "test failure"); END',
      );
      await expectLater(
        service.capture(text: 'First', captureId: captureId),
        throwsA(anything),
      );
      expect(await db.getAllNotesRaw(), isEmpty);
      await db.customStatement('DROP TRIGGER reject_task');
      await service.capture(text: 'First', captureId: captureId);
      expect(await db.getAllNotesRaw(), hasLength(1));
    },
  );
  test(
    'existing rich note capture preserves raw extension nodes and uses literal spans',
    () async {
      final rich = jsonEncode({
        '\$schema': 'quietpaper:rich_document:v1',
        'blocks': [
          {
            'type': 'paragraph',
            'id': 'keep',
            'spans': [
              {'text': 'body'},
            ],
            'future': 'keep',
          },
        ],
      });
      await repo.saveNote(note('n', rich));
      final result = await service.capture(
        text: '[link](x) **literal**',
        captureId: captureId,
        noteId: 'n',
      );
      final blocks = jsonDecode(result.note.content)['blocks'] as List;
      expect(blocks.first, jsonDecode(rich)['blocks'][0]);
      expect(
        TaskDocument.extract(result.note.content).single.text,
        '[link](x) **literal**',
      );
    },
  );
  test(
    'today journal is chosen by date argument and does not follow selected past note',
    () async {
      final old = await repo.getOrCreateJournalEntry(DateTime(2020, 1, 1));
      final result = await service.capture(
        text: 'Today',
        captureId: captureId,
        todayJournal: true,
        today: DateTime(2026, 11, 25),
      );
      expect(result.note.journalDate, '2026-11-25');
      expect(result.note.id, isNot(old.id));
    },
  );
}
