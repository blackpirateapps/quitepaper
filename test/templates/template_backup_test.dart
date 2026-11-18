import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/backup/backup_models.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'template_domain_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late TemplateRepository repo;
  late BackupService backup;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    repo = TemplateRepository(db);
    backup = BackupService(
      database: db,
      cryptoService: DefaultCryptoService(),
      sharedPreferences: await SharedPreferences.getInstance(),
    );
  });
  tearDown(() => db.close());
  test(
    'encrypted backup restores user content/favorites and can instantiate',
    () async {
      await repo.insertUserTemplate(fixture());
      await repo.setFavorite(fixture().id, true);
      await repo.setFavorite('builtin.daily_planner.v1', true);
      final encrypted = await backup.generateBackupString(
        password: 'long-test-password',
      );
      expect(encrypted, isNot(contains(fixture().displayName)));
      expect(encrypted, isNot(contains(fixture().id)));
      final validated = await backup.validateBackupString(
        encrypted,
        password: 'long-test-password',
      );
      expect(validated.isValid, true);
      expect(validated.payload!.templates.single.toJson(), fixture().toJson());
      final clean = AppDatabase.memory();
      try {
        final restore = BackupService(
          database: clean,
          cryptoService: DefaultCryptoService(),
          sharedPreferences: await SharedPreferences.getInstance(),
        );
        await restore.restoreBackup(
          validated.payload!,
          strategy: RestoreStrategy.replace,
        );
        final restoredRepo = TemplateRepository(clean);
        expect((await restoredRepo.getUserTemplates()).single.content, 'Body');
        expect(await restoredRepo.getFavoriteTemplateIds(), {
          fixture().id,
          'builtin.daily_planner.v1',
        });
        final note = await TemplateService(
          repository: restoredRepo,
          notes: DriftNotesRepository(clean),
        ).instantiate(fixture().id);
        expect(note.content, 'Body');
      } finally {
        await clean.close();
      }
    },
  );
  test(
    'legacy payload without templates restores normally, replacement clears templates/favorites',
    () async {
      await repo.insertUserTemplate(fixture());
      await repo.setFavorite(fixture().id, true);
      final json = (await backup.generateBackupPayload()).toJson()
        ..remove('templates')
        ..remove('templateFavorites');
      final legacy = BackupPayload.fromJson(json);
      expect(legacy.templates, isEmpty);
      expect(legacy.templateFavorites, isEmpty);
      await backup.restoreBackup(legacy, strategy: RestoreStrategy.replace);
      expect(await repo.getUserTemplates(), isEmpty);
      expect(await repo.getFavoriteTemplateIds(), isEmpty);
    },
  );
  test(
    'merge prefers later metadata, ties preserve local row; combines valid favorites',
    () async {
      await repo.insertUserTemplate(fixture());
      await repo.setFavorite('builtin.meeting_notes.v1', true);
      final original = await backup.generateBackupPayload();
      await repo.renameUserTemplate(fixture().id, 'Local newer');
      await backup.restoreBackup(original);
      expect(
        (await repo.getUserTemplate(fixture().id))!.displayName,
        'Local newer',
      );
      final newerJson = fixture().toJson()
        ..['displayName'] = 'Backup newer'
        ..['updatedAt'] = DateTime.utc(2099).toIso8601String();
      final incoming = BackupPayload(
        manifest: original.manifest,
        notes: const [],
        tags: const [],
        templates: [NoteTemplate.fromJson(newerJson)],
        templateFavorites: [
          fixture().id,
          'builtin.daily_planner.v1',
          'missing-id',
          'builtin.future.v9',
        ],
      );
      await backup.restoreBackup(incoming);
      expect(
        (await repo.getUserTemplate(fixture().id))!.displayName,
        'Backup newer',
      );
      expect(await repo.getFavoriteTemplateIds(), {
        fixture().id,
        'builtin.meeting_notes.v1',
        'builtin.daily_planner.v1',
      });
      newerJson['displayName'] = 'Tie must not replace';
      await backup.restoreBackup(
        BackupPayload(
          manifest: original.manifest,
          notes: const [],
          tags: const [],
          templates: [NoteTemplate.fromJson(newerJson)],
        ),
      );
      expect(
        (await repo.getUserTemplate(fixture().id))!.displayName,
        'Backup newer',
      );
    },
  );
  test(
    'corrupt metadata and unsupported serialized bodies fail without changing local data',
    () async {
      await repo.insertUserTemplate(fixture());
      final payload = await backup.generateBackupPayload();
      for (final mutate in [
        (Map<String, dynamic> row) {
          row['defaultTags'] = [123];
        },
        (Map<String, dynamic> row) {
          row['schemaVersion'] = 999;
        },
        (Map<String, dynamic> row) {
          row['createdAt'] = 'invalid';
        },
      ]) {
        final json = payload.toJson();
        mutate((json['templates'] as List).single as Map<String, dynamic>);
        final validation = await backup.validateBackupString(jsonEncode(json));
        expect(validation.isValid, false);
      }
      final bad = NoteTemplate.fromJson(
        fixture().toJson()..['content'] = '[asset](qp://asset/private)',
      );
      await expectLater(
        backup.restoreBackup(
          BackupPayload(
            manifest: payload.manifest,
            notes: const [],
            tags: const [],
            templates: [bad],
          ),
          strategy: RestoreStrategy.replace,
        ),
        throwsA(isA<TemplateException>()),
      );
      expect((await repo.getUserTemplates()).single.content, 'Body');
    },
  );
  test(
    'failure later in restore rolls back template changes and replacement deletion',
    () async {
      await repo.insertUserTemplate(fixture());
      await repo.setFavorite(fixture().id, true);
      final payload = await backup.generateBackupPayload();
      // Fails during ordinary note restore AFTER the template writes have run.
      await db.customStatement(
        "CREATE TRIGGER injected_restore_failure BEFORE INSERT ON notes BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      final changed = NoteTemplate.fromJson(
        fixture().toJson()
          ..['displayName'] = 'Replacement'
          ..['updatedAt'] = DateTime.utc(2099).toIso8601String(),
      );
      final now = DateTime.utc(2026);
      final failing = BackupPayload(
        manifest: payload.manifest,
        templates: [changed],
        templateFavorites: ['builtin.daily_planner.v1'],
        tags: const [],
        notes: [
          BackupNote(
            id: 'failed',
            title: 'Failed',
            content: '',
            tags: const [],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      await expectLater(
        backup.restoreBackup(failing, strategy: RestoreStrategy.replace),
        throwsA(anything),
      );
      expect((await repo.getUserTemplates()).single.displayName, 'Template');
      expect(await repo.getFavoriteTemplateIds(), {fixture().id});
    },
  );
}
