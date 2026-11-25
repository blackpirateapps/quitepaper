import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:sqlite3/sqlite3.dart';

// Reproduce the schema left behind by the experimental Tasks build. The
// ordinary installed app neither creates these tables nor drains task_dirty.
const legacyTaskSchema = '''
CREATE TABLE task_dirty (
  note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE
);
CREATE TABLE task_index (
  note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
  text TEXT NOT NULL
);
CREATE TABLE task_index_failures (
  note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE
);
CREATE TRIGGER task_note_insert AFTER INSERT ON notes BEGIN
  INSERT OR IGNORE INTO task_dirty(note_id) VALUES(new.id); END;
CREATE TRIGGER task_note_update
AFTER UPDATE OF content,is_archived,is_trashed,deleted_at ON notes BEGIN
  INSERT OR IGNORE INTO task_dirty(note_id) VALUES(new.id);
  DELETE FROM task_index WHERE note_id=new.id AND
    (new.is_archived=1 OR new.is_trashed=1 OR new.deleted_at IS NOT NULL OR
    ltrim(new.content) LIKE '<!-- quiet-paper-encrypted-note-v1:%'); END;
CREATE TRIGGER task_note_delete AFTER DELETE ON notes BEGIN
  DELETE FROM task_index WHERE note_id=old.id;
  DELETE FROM task_dirty WHERE note_id=old.id;
  DELETE FROM task_index_failures WHERE note_id=old.id; END;
INSERT INTO task_dirty VALUES('existing');
INSERT INTO task_index VALUES('existing', 'Keep this derived task');
INSERT INTO task_index_failures VALUES('existing');
''';

Note note(String id) => Note(
  id: id,
  title: 'Saved title',
  content: 'Saved body',
  createdAt: DateTime(2026, 11, 25),
  updatedAt: DateTime(2026, 11, 25),
);

void main() {
  late Directory root;
  late File file;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('qp_task_trigger_repair_');
    file = File('${root.path}/notebook.sqlite');
    final initial = AppDatabase(NativeDatabase(file));
    try {
      await DriftNotesRepository(initial).saveNote(note('existing'));
    } finally {
      await initial.close();
    }
  });

  tearDown(() => root.delete(recursive: true));

  void installLegacyTriggers() {
    final raw = sqlite3.open(file.path);
    try {
      raw.execute(legacyTaskSchema);
    } finally {
      raw.close();
    }
  }

  test(
    'reopen repairs queued-note autosaves and repeated new-note saves',
    () async {
      installLegacyTriggers();
      final db = AppDatabase(NativeDatabase(file));
      final repository = DriftNotesRepository(db);
      final editor = EditorNotifier(
        initialNote: note('existing'),
        repository: repository,
      );
      try {
        editor.updateContent('First edit #repair ');
        await editor.flushPendingChanges();
        editor.updateContent('Second edit #repair ');
        await editor.flushPendingChanges();
        expect(editor.state.isDirty, isFalse);
        expect(editor.state.isSaving, isFalse);
        final saved = await repository.getNoteById('existing');
        expect(saved!.content, 'Second edit #repair ');
        expect(saved.tags, contains('repair'));

        await repository.saveNote(note('new'));
        await repository.saveNote(
          note('new').copyWith(content: 'Updated new note'),
        );
        expect(
          (await repository.getNoteById('new'))!.content,
          'Updated new note',
        );
        expect(
          await db.customSelect('SELECT * FROM task_dirty').get(),
          hasLength(2),
        );
        expect(
          (await db.customSelect('SELECT text FROM task_index').getSingle())
              .read<String>('text'),
          'Keep this derived task',
        );
        final matches = await repository
            .watchNotes(searchQuery: 'Second')
            .first;
        expect(matches.map((n) => n.id), contains('existing'));
      } finally {
        editor.dispose();
        await db.close();
      }
    },
  );

  test(
    'repair preserves archive cleanup and delete trigger behavior',
    () async {
      installLegacyTriggers();
      final db = AppDatabase(NativeDatabase(file));
      final repository = DriftNotesRepository(db);
      try {
        await repository.saveNote(note('existing'));
        await repository.archiveNote('existing');
        expect(
          await db.customSelect('SELECT * FROM task_index').get(),
          isEmpty,
        );
        expect(
          await db.customSelect('SELECT * FROM task_dirty').get(),
          hasLength(1),
        );
        await repository.deletePermanently('existing');
        expect(
          await db.customSelect('SELECT * FROM task_dirty').get(),
          isEmpty,
        );
        expect(
          await db.customSelect('SELECT * FROM task_index_failures').get(),
          isEmpty,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'repair is idempotent without changing notes, queue or schema version',
    () async {
      installLegacyTriggers();
      List<String>? repairedSql;
      for (var pass = 0; pass < 2; pass++) {
        final db = AppDatabase(NativeDatabase(file));
        try {
          final saved = await DriftNotesRepository(db).getNoteById('existing');
          expect(saved!.content, note('existing').content);
          expect(saved.createdAt, note('existing').createdAt);
          expect(saved.updatedAt, note('existing').updatedAt);
          expect(
            await db.customSelect('SELECT * FROM task_dirty').get(),
            hasLength(1),
          );
          expect(
            await db.customSelect('SELECT * FROM task_index').get(),
            hasLength(1),
          );
          final sql =
              (await db
                      .customSelect(
                        "SELECT sql FROM sqlite_master WHERE type='trigger' "
                        "AND name LIKE 'task_note_%' ORDER BY name",
                      )
                      .get())
                  .map((r) => r.read<String>('sql'))
                  .toList();
          expect(sql, hasLength(3));
          expect(sql.join(), isNot(contains('INSERT OR IGNORE')));
          if (repairedSql != null) expect(sql, repairedSql);
          repairedSql = sql;
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            db.schemaVersion,
          );
        } finally {
          await db.close();
        }
      }
    },
  );

  test('ordinary notebooks do not acquire Tasks tables or triggers', () async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      await DriftNotesRepository(db).saveNote(note('existing'));
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name LIKE 'task_%'",
            )
            .get(),
        isEmpty,
      );
    } finally {
      await db.close();
    }
  });
}
