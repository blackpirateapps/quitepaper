import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';
import 'package:uuid/uuid.dart';
import 'template_domain_test.dart' show fixture;

void main() {
  late AppDatabase db;
  late TemplateRepository repo;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.memory();
    repo = TemplateRepository(db);
  });
  tearDown(() => db.close());

  test(
    'fresh schema, CRUD, favorite streams, deletion cleanup, no note/sync rows',
    () async {
      expect(db.schemaVersion, 23);
      final rows = <List<NoteTemplate>>[];
      final favorites = <Set<String>>[];
      final sub = repo.watchUserTemplates().listen(rows.add);
      final favSub = repo.watchFavoriteTemplateIds().listen(favorites.add);
      await repo.insertUserTemplate(fixture());
      await repo.setFavorite(fixture().id, true);
      expect((await repo.getUserTemplate(fixture().id))!.content, 'Body');
      await repo.renameUserTemplate(fixture().id, ' Renamed ');
      expect(
        (await repo.getUserTemplate(fixture().id))!.displayName,
        'Renamed',
      );
      await repo.setFavorite('builtin.meeting_notes.v1', true);
      await repo.setFavorite('builtin.unknown.v2', true);
      await repo.setFavorite('builtin.meeting_notes.v1', false);
      expect(await repo.getFavoriteTemplateIds(), {
        fixture().id,
        'builtin.unknown.v2',
      });
      await repo.deleteUserTemplate(fixture().id);
      expect(await repo.getFavoriteTemplateIds(), {'builtin.unknown.v2'});
      expect(await repo.getUserTemplates(), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(rows.any((r) => r.isNotEmpty), true);
      expect(rows.last, isEmpty);
      expect(favorites.any((r) => r.contains(fixture().id)), true);
      expect(await db.select(db.notesTable).get(), isEmpty);
      expect(await db.select(db.syncQueueTable).get(), isEmpty);
      await sub.cancel();
      await favSub.cancel();
    },
  );
  test('built-in mutations prohibited, duplicate names allowed', () async {
    final a = fixture();
    final b = NoteTemplate(
      id: const Uuid().v4(),
      displayName: a.displayName,
      content: a.content,
      storageFormat: a.storageFormat,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    );
    await repo.insertUserTemplate(a);
    await repo.insertUserTemplate(b);
    expect((await repo.getUserTemplates()).length, 2);
    expect(
      repo.renameUserTemplate('builtin.daily_planner.v1', 'Oops'),
      throwsA(isA<TemplateException>()),
    );
    expect(
      repo.deleteUserTemplate('builtin.daily_planner.v1'),
      throwsA(isA<TemplateException>()),
    );
  });
  test('transaction rollback restores deletion and favorites', () async {
    await repo.insertUserTemplate(fixture());
    await repo.setFavorite(fixture().id, true);
    await expectLater(
      db.transaction(() async {
        await repo.deleteUserTemplate(fixture().id);
        throw StateError('injected');
      }),
      throwsStateError,
    );
    expect(await repo.getUserTemplate(fixture().id), isNotNull);
    expect(await repo.getFavoriteTemplateIds(), {fixture().id});
  });
  test('vault erase removes templates and favorites', () async {
    await repo.insertUserTemplate(fixture());
    await repo.setFavorite('builtin.daily_planner.v1', true);
    await db.eraseAllLocalVaultData();
    expect(await repo.getUserTemplates(), isEmpty);
    expect(await repo.getFavoriteTemplateIds(), isEmpty);
  });
  test(
    'user templates and favorites survive a closed database connection',
    () async {
      final dir = await Directory.systemTemp.createTemp('qp-template-restart');
      final file = File('${dir.path}/vault.sqlite');
      final first = AppDatabase(NativeDatabase(file));
      final firstRepo = TemplateRepository(first);
      await firstRepo.insertUserTemplate(fixture());
      await firstRepo.setFavorite(fixture().id, true);
      await firstRepo.setFavorite('builtin.daily_planner.v1', true);
      await first.close();
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final secondRepo = TemplateRepository(reopened);
        expect(
          (await secondRepo.getUserTemplates()).single.content,
          fixture().content,
        );
        expect(await secondRepo.getFavoriteTemplateIds(), {
          fixture().id,
          'builtin.daily_planner.v1',
        });
      } finally {
        await reopened.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'upgrade real pre-feature v20 schema preserves notes, tags, sync, journal, attachments',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'qp-template-migration',
      );
      final file = File('${dir.path}/vault.sqlite');
      final previous = AppDatabase(NativeDatabase(file));
      await previous.saveNote(
        id: 'ordinary',
        title: 'Original',
        content: 'Body',
        isPinned: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        tags: ['work/plan'],
        serverRevision: 7,
        isDirty: false,
      );
      await previous.saveNote(
        id: 'journal',
        title: 'Journal',
        content: 'Day',
        isPinned: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        journalDate: '2026-11-18',
      );
      await previous.saveAttachment(
        id: 'asset',
        noteId: 'ordinary',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await previous.setSyncMetadata('template-test', 'cursor');
      await previous.close();
      // Remove both branches' additions to recreate the actual v20 layout.
      final baseline = sqlite.sqlite3.open(file.path);
      baseline.execute('DROP TABLE template_favorites');
      baseline.execute('DROP TABLE note_templates');
      baseline.execute('DROP TABLE note_import_source_index');
      baseline.execute('DROP TABLE email_import_preparations');
      baseline.execute('ALTER TABLE notes DROP COLUMN import_sources');
      baseline.execute('PRAGMA user_version=20');
      baseline.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final schema = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(schema.data['user_version'], 23);
        final ordinary = (await upgraded.getNoteWithTags('ordinary'))!;
        expect(ordinary.note.title, 'Original');
        expect(ordinary.note.content, 'Body');
        expect(ordinary.note.serverRevision, 7);
        expect(ordinary.note.isDirty, false);
        expect(ordinary.tagNames, ['work/plan']);
        expect(
          (await upgraded.getNoteWithTags('journal'))!.note.journalDate,
          '2026-11-18',
        );
        expect(await upgraded.getAttachment('asset'), isNotNull);
        expect(await upgraded.getSyncMetadata('template-test'), 'cursor');
        final migrated = TemplateRepository(upgraded);
        await migrated.insertUserTemplate(fixture());
        await migrated.setFavorite('builtin.daily_planner.v1', true);
        expect((await migrated.getUserTemplates()).length, 1);
      } finally {
        await upgraded.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    '1,000 templates and large bodies, rapid toggles, restart persistence',
    () async {
      await db.transaction(() async {
        for (var i = 0; i < 1000; i++) {
          final t = fixture();
          await repo.insertUserTemplate(
            NoteTemplate(
              id: const Uuid().v4(),
              displayName: 'Template $i',
              content: i == 0 ? 'large body\n' * 100000 : 'Body',
              storageFormat: t.storageFormat,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
            ),
          );
        }
      });
      expect((await repo.getUserTemplates()).length, 1000);
      for (var i = 0; i < 30; i++) {
        await repo.setFavorite('builtin.daily_planner.v1', i.isEven);
      }
      expect(await repo.getFavoriteTemplateIds(), isEmpty);
      expect(await db.select(db.notesTable).get(), isEmpty);
    },
  );
}
