import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';

const _id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
TaskItem _item(Note note, [int ordinal = 0]) => TaskItem(
  note: note,
  version: TaskDocument.version(note.content),
  occurrence: TaskDocument.extract(note.content)[ordinal],
);
Note _note(String content) => Note(
  id: 'note',
  title: 'Work',
  content: content,
  tags: const ['work'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;
  late TaskService service;
  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
    service = TaskService(
      db,
      repository,
      inboxNamespace: () async => 'synthetic',
    );
  });
  tearDown(() => db.close());

  for (final rich in [false, true]) {
    String content(String markdown) => rich
        ? jsonEncode(const RichDocumentParser().parse(markdown).toJson())
        : markdown;
    test(
      'rename preserves dates/completion, index and exact Undo rich=$rich',
      () async {
        final original = _note(
          content(
            '# Keep\r\n* [x] **Original** <!-- qp-task:v1 id=$_id due=2026-11-27 -->\r\n- [ ] Sibling\r\n',
          ),
        );
        await repository.saveNote(original);
        expect(
          TaskDocument.rename(
            original.content,
            _item(original).occurrence,
            'Original',
          ),
          original.content,
        );
        final commit = await service.rename(
          _item(original),
          'Buy [milk] **today** বাংলা',
        );
        final renamed = TaskDocument.extract(commit.note.content).first;
        expect(renamed.text, 'Buy [milk] **today** বাংলা');
        expect(renamed.completed, isTrue);
        expect(renamed.metadata!.due.toString(), '2026-11-27');
        expect(renamed.metadata!.id, _id);
        expect(
          (await db.watchTaskRows().first).map(
            (row) => row.read<String>('text'),
          ),
          contains(renamed.text),
        );
        expect(commit.note.tags, original.tags);
        await commit.undo.run();
        expect(
          (await repository.getNoteById('note'))!.content,
          original.content,
        );
      },
    );
    test(
      'delete includes descendants, keeps sibling and exact Undo rich=$rich',
      () async {
        final original = _note(
          content(
            '# Work\n- [ ] Parent <!-- qp-task:v1 id=$_id -->\n  - [x] Child\n    - [ ] Grandchild\n- [ ] Sibling\n\nKeep this paragraph.',
          ),
        );
        await repository.saveNote(original);
        final commit = await service.delete(_item(original));
        expect(
          TaskDocument.extract(commit.note.content).map((task) => task.text),
          ['Sibling'],
        );
        expect(commit.note.markdownContent, contains('Keep this paragraph.'));
        expect(await db.watchTaskRows().first, hasLength(1));
        await commit.undo.run();
        expect(
          (await repository.getNoteById('note'))!.content,
          original.content,
        );
        expect(await db.watchTaskRows().first, hasLength(4));
      },
    );
    test('rename and delete Undo refuse later changes rich=$rich', () async {
      final original = _note(
        content('- [ ] Original <!-- qp-task:v1 id=$_id -->'),
      );
      await repository.saveNote(original);
      final renamed = await service.rename(_item(original), 'Renamed');
      await service.setDate(
        _item(renamed.note),
        TaskDate.tryParse('2026-11-28'),
      );
      await expectLater(renamed.undo.run(), throwsA(isA<StaleTask>()));
      final current = (await repository.getNoteById('note'))!;
      final deleted = await service.delete(_item(current));
      await repository.saveNote(
        deleted.note.copyWith(content: content('New content')),
      );
      await expectLater(deleted.undo.run(), throwsA(isA<StaleTask>()));
      expect(
        (await repository.getNoteById('note'))!.markdownContent,
        contains('New content'),
      );
    });
    test(
      'stale rename/delete and empty/multiline rename leave source intact rich=$rich',
      () async {
        final original = _note(
          content('- [ ] Original <!-- qp-task:v1 id=$_id -->'),
        );
        await repository.saveNote(original);
        for (final text in ['', '  ', 'one\ntwo', 'one\rtwo']) {
          await expectLater(
            service.rename(_item(original), text),
            throwsA(isA<StaleTask>()),
          );
        }
        final renamed = await service.rename(_item(original), 'New name');
        await expectLater(
          service.rename(_item(original), 'Lost edit'),
          throwsA(isA<StaleTask>()),
        );
        await expectLater(
          service.delete(_item(original)),
          throwsA(isA<StaleTask>()),
        );
        expect(
          (await repository.getNoteById('note'))!.content,
          renamed.note.content,
        );
      },
    );
  }

  test(
    'Markdown rename retains ordered quote prefix, continuation and metadata bytes',
    () {
      const source =
          '> 2) [X] **Original** <!-- qp-task:v1 id=$_id due=2026-11-27 -->\r\n>    continuation\r\n> 3) [ ] Sibling\r\n';
      final renamed = TaskDocument.rename(
        source,
        TaskDocument.extract(source).first,
        'New name',
      );
      expect(renamed, source.replaceFirst('**Original**', 'New name'));
      final deleted = TaskDocument.delete(
        source,
        TaskDocument.extract(source).first,
      );
      expect(deleted, '> 3) [ ] Sibling\r\n');
    },
  );

  test(
    'Markdown deletion keeps blank separators, unrelated quoted notes and suffix bytes',
    () {
      const source =
          'Before\r\n\r\n- [ ] Parent\r\n  continuation\r\n\r\n  - [ ] Child\r\n\r\n> Keep this quote\r\n\r\nAfter';
      expect(
        TaskDocument.delete(source, TaskDocument.extract(source).first),
        'Before\r\n\r\n\r\n> Keep this quote\r\n\r\nAfter',
      );
    },
  );

  test(
    'delete refuses to remove descendants added after confirmation snapshot',
    () async {
      final original = _note('- [ ] Parent <!-- qp-task:v1 id=$_id -->');
      await repository.saveNote(original);
      final updated = original.copyWith(
        content: '${original.content}\n  - [ ] New child',
      );
      await repository.saveNote(updated);
      await expectLater(
        service.delete(_item(original)),
        throwsA(isA<StaleTask>()),
      );
      expect((await repository.getNoteById('note'))!.content, updated.content);
    },
  );
}
