import 'package:quitepaper/features/templates/data/template_repository.dart';
import '../templates/template_domain_test.dart' show fixture;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/features/email_import/application/email_import_gateway.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/backup/backup_models.dart';
import 'package:quitepaper/core/sync/conflict/conflict_resolver.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/email_import/application/email_parser.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/email_import/domain/note_import_source.dart';
import '../attachments/attachment_service_test.dart' show MockKeyManager;

class _DeferredDeleteStorage extends AttachmentLocalStorage {
  _DeferredDeleteStorage(Directory directory)
    : super(customBaseDirectory: directory);
  bool failDelete = true;
  @override
  Future<void> deleteEncryptedFile({
    required String attachmentId,
    String variant = 'original',
    String? localPath,
  }) async {
    if (failDelete) return;
    await super.deleteEncryptedFile(
      attachmentId: attachmentId,
      variant: variant,
      localPath: localPath,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late NotesRepository repo;
  late Directory dir;
  late AttachmentService vault;
  late AttachmentLocalStorage storage;
  late EmailImportService service;
  late MockKeyManager keys;
  const parser = EmailParser();
  EmailMessage email(String fixture) => parser.parseSync(
    File('test/email_import/fixtures/$fixture.eml').readAsBytesSync(),
  );
  setUp(() async {
    db = AppDatabase.memory();
    repo = DriftNotesRepository(db);
    dir = await Directory.systemTemp.createTemp('qp-email-test-');
    storage = AttachmentLocalStorage(customBaseDirectory: dir);
    keys = MockKeyManager(
      masterKey: Uint8List.fromList(List.generate(32, (i) => i)),
    );
    vault = AttachmentService(database: db, keyManager: keys, storage: storage);
    service = EmailImportService(
      database: db,
      repository: repo,
      attachments: vault,
    );
  });
  tearDown(() async {
    await db.close();
    AttachmentLocalStorage.purgeAllMemoryCache();
    await dir.delete(recursive: true);
  });

  test(
    'accountless import encrypts assets and reopens them after restart',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final localKeys = SecureKeyManager(
        secureStorage: const FlutterSecureStorage(),
      );
      final localVault = AttachmentService(
        database: db,
        keyManager: localKeys,
        storage: storage,
      );
      final localService = EmailImportService(
        database: db,
        repository: repo,
        attachments: localVault,
      );
      var notified = false;
      final gateway = EmailImportGateway(
        localService,
        canCreateLocalKey: () => true,
        onUnlocked: () => notified = true,
      );
      expect(gateway.isUnlocked, isFalse);
      await gateway.initialize();
      expect(notified, isTrue);
      final message = email('mixed');
      final note = await localService.save(
        email: message,
        mode: EmailImportMode.editable,
        title: message.subject,
      );
      final assets = await localVault.getAttachmentsForNote(note.id);
      final original = assets.singleWhere(
        (a) => a.mimeType == 'message/rfc822',
      );
      final ciphertext = await storage.readEncryptedBytes(
        attachmentId: original.id,
      );
      expect(ciphertext, isNot(orderedEquals(message.rawBytes!)));
      final masterKey = Uint8List.fromList(localKeys.getMasterKey());
      localKeys.lock();
      final restarted = SecureKeyManager(
        secureStorage: const FlutterSecureStorage(),
      );
      await restarted.initialize();
      expect(restarted.getMasterKey(), orderedEquals(masterKey));
      final reopenedVault = AttachmentService(
        database: db,
        keyManager: restarted,
        storage: storage,
      );
      expect(
        (await reopenedVault.resolveAsset(original.id)).data,
        orderedEquals(message.rawBytes!),
      );
      expect((await repo.getNoteById(note.id))!.importSources, isNotEmpty);
    },
  );

  test(
    'missing keys for an encrypted library cannot trigger key replacement',
    () async {
      await service.save(
        email: email('mixed'),
        mode: EmailImportMode.editable,
        title: 'Existing encrypted email',
      );
      FlutterSecureStorage.setMockInitialValues({});
      final missingKeys = SecureKeyManager(
        secureStorage: const FlutterSecureStorage(),
      );
      final gateway = EmailImportGateway(
        EmailImportService(
          database: db,
          repository: repo,
          attachments: AttachmentService(
            database: db,
            keyManager: missingKeys,
            storage: storage,
          ),
        ),
        canCreateLocalKey: () => true,
      );
      await expectLater(
        gateway.initialize(),
        throwsA(isA<EmailImportException>()),
      );
      expect(missingKeys.isUnlocked, isFalse);
      expect(
        await const FlutterSecureStorage().read(
          key: 'quietpaper_master_key_v1',
        ),
        isNull,
      );
    },
  );

  test(
    'signed-in vault must unlock its keys rather than create offline ones',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final missingKeys = SecureKeyManager(
        secureStorage: const FlutterSecureStorage(),
      );
      final gateway = EmailImportGateway(
        EmailImportService(
          database: db,
          repository: repo,
          attachments: AttachmentService(
            database: db,
            keyManager: missingKeys,
            storage: storage,
          ),
        ),
        canCreateLocalKey: () => false,
      );
      await gateway.initialize();
      expect(gateway.isUnlocked, isFalse);
      expect(
        await const FlutterSecureStorage().read(
          key: 'quietpaper_master_key_v1',
        ),
        isNull,
      );
    },
  );

  test(
    'creates searchable note, encrypted original/attachment, tags and indexed provenance',
    () async {
      final message = email('mixed');
      final note = await service.save(
        email: message,
        mode: EmailImportMode.editable,
        title: message.subject,
      );
      final loaded = (await repo.getNoteById(note.id))!;
      expect(loaded.importSources, note.importSources);
      expect(loaded.tags, ['email']);
      expect(loaded.content, contains('From: Alice'));
      expect(loaded.content, contains('invoice.pdf'));
      final assets = await vault.getAttachmentsForNote(note.id);
      expect(assets, hasLength(2));
      for (final asset in assets) {
        expect(storage.getDecryptedCache(asset.id), isNull);
      }
      final original = assets.singleWhere(
        (a) => a.mimeType == 'message/rfc822',
      );
      final resolved = await vault.resolveAsset(original.id);
      expect(resolved.data, orderedEquals(message.rawBytes!));
      final ciphertext = await storage.readEncryptedBytes(
        attachmentId: original.id,
      );
      expect(ciphertext, isNot(orderedEquals(message.rawBytes!)));
      expect(
        assets.every((a) => a.isDirty && a.ocrState == 'not_requested'),
        isTrue,
      );
      expect(
        await db.findEmailDuplicates(
          rawHash: message.rawHash,
          fingerprint: message.fingerprint,
        ),
        contains((noteId: note.id, exact: true)),
      );
      expect(
        await db.customSelect('SELECT * FROM email_import_preparations').get(),
        isEmpty,
      );
      expect(await repo.watchNotes(searchQuery: 'Alice').first, isNotEmpty);
      expect(await repo.watchNotes(filterTag: 'email').first, hasLength(1));
    },
  );
  test('archive excludes converted body and saves only original', () async {
    final note = await service.save(
      email: email('related'),
      mode: EmailImportMode.archive,
      title: 'Archive',
    );
    expect(note.content, isNot(contains('Portrait')));
    expect(await vault.getAttachmentsForNote(note.id), hasLength(1));
  });
  test('shared content has no fabricated archive or metadata', () async {
    final shared = parser.sharedText(text: 'Shared paragraph');
    final note = await service.save(
      email: shared,
      mode: EmailImportMode.editable,
      title: 'Shared',
    );
    expect(note.importSources.single.inputType, 'shared_text');
    expect(note.content, contains('Shared content'));
    expect(note.content, contains('Date unavailable'));
    expect(await vault.getAttachmentsForNote(note.id), isEmpty);
    await expectLater(
      service.save(
        email: shared,
        mode: EmailImportMode.archive,
        title: 'Archive',
      ),
      throwsA(isA<EmailImportException>()),
    );
  });
  for (final rich in [false, true]) {
    test(
      'append preserves ${rich ? 'rich AST block identities' : 'Markdown'}, title and prior sources',
      () async {
        final content = rich
            ? jsonEncode(
                const RichDocumentParser()
                    .parse('Existing **bold**\n\n- item')
                    .toJson(),
              )
            : 'Existing **bold**\n\n- item';
        final original = Note(
          id: 'destination',
          title: 'Keep title',
          content: content,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        await repo.saveNote(original);
        final saved = await service.save(
          email: email('plain'),
          mode: EmailImportMode.append,
          title: 'Email section',
          destination: original,
        );
        expect(saved.title, 'Keep title');
        expect(saved.markdownContent, contains('Email section'));
        expect(saved.markdownContent, contains('Existing **bold**'));
        if (rich) {
          final before = RichDocument.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
          final after = RichDocument.fromJson(
            jsonDecode(saved.content) as Map<String, dynamic>,
          );
          expect(after.blocks.first.id, before.blocks.first.id);
        }
        await repo.saveNote(original.copyWith(content: saved.content));
        expect((await repo.getNoteById(saved.id))!.importSources, hasLength(1));
      },
    );
  }
  test(
    'stale append rolls back prepared assets and preserves newer destination',
    () async {
      final dest = Note(
        id: 'dest',
        title: 'Title',
        content: 'Before',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await repo.saveNote(dest);
      await repo.saveNote(
        dest.copyWith(content: 'Newer', updatedAt: DateTime.utc(2026, 2)),
      );
      await expectLater(
        service.save(
          email: email('mixed'),
          mode: EmailImportMode.append,
          title: 'x',
          destination: dest,
        ),
        throwsA(
          isA<EmailImportException>().having(
            (e) => e.code,
            'code',
            'destination_changed',
          ),
        ),
      );
      expect((await repo.getNoteById('dest'))!.content, 'Newer');
      expect(await db.getAllAttachments(), isEmpty);
      expect(await dir.list().toList(), isEmpty);
    },
  );
  test(
    'exact and related detection, explicit duplicate copy and source index rebuild',
    () async {
      final original = email('plain');
      final first = await service.save(
        email: original,
        mode: EmailImportMode.editable,
        title: 'First',
      );
      await expectLater(
        service.save(
          email: original,
          mode: EmailImportMode.editable,
          title: 'Copy',
        ),
        throwsA(isA<EmailImportException>()),
      );
      final copy = await service.save(
        email: original,
        mode: EmailImportMode.editable,
        title: 'Copy',
        allowDuplicate: true,
      );
      expect(copy.id, isNot(first.id));
      final related = parser.parseSync(
        Uint8List.fromList(
          utf8.encode(
            utf8
                .decode(original.rawBytes!)
                .replaceAll('Hello world.', 'Different body'),
          ),
        ),
      );
      expect(
        (await db.findEmailDuplicates(
          rawHash: related.rawHash,
          fingerprint: related.fingerprint,
          messageId: related.messageId,
        )).every((d) => !d.exact),
        isTrue,
      );
      await db.customStatement('DELETE FROM note_import_source_index');
      await db.rebuildImportSourceIndex();
      expect(
        await db.findEmailDuplicates(fingerprint: original.fingerprint),
        hasLength(2),
      );
      await repo.deletePermanently(first.id);
      expect(
        await db.findEmailDuplicates(fingerprint: original.fingerprint),
        hasLength(1),
      );
    },
  );
  test('CID image references use one encrypted asset and skip OCR', () async {
    final note = await service.save(
      email: email('related'),
      mode: EmailImportMode.editable,
      title: 'Picture',
    );
    expect(note.content, isNot(contains('email-cid:')));
    expect(note.content, contains('![Portrait](qp://asset/'));
    expect(
      (await vault.getAttachmentsForNote(
        note.id,
      )).every((a) => a.ocrState == 'not_requested'),
      isTrue,
    );
  });
  test(
    'cancel and locked vault leave no visible notes or orphaned ciphertext',
    () async {
      var checks = 0;
      await expectLater(
        service.save(
          email: email('mixed'),
          mode: EmailImportMode.editable,
          title: 'Cancel',
          isCancelled: () => ++checks > 1,
        ),
        throwsA(isA<EmailImportException>()),
      );
      expect(await db.getAllNotesRaw(), isEmpty);
      expect(await db.getAllAttachments(), isEmpty);
      expect(await dir.list().toList(), isEmpty);
      keys.lock();
      await expectLater(
        service.save(
          email: email('plain'),
          mode: EmailImportMode.editable,
          title: 'Locked',
        ),
        throwsA(isA<EmailImportException>()),
      );
    },
  );
  test(
    'interrupted preparation journal removes ciphertext without a DB attachment row',
    () async {
      await db.customStatement(
        'INSERT INTO email_import_preparations(asset_id) VALUES (?)',
        ['interrupted'],
      );
      await storage.saveEncryptedBytes(
        attachmentId: 'interrupted',
        encryptedBytes: Uint8List.fromList([1, 2, 3]),
      );
      await service.recoverInterruptedImports();
      expect(await dir.list().toList(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM email_import_preparations').get(),
        isEmpty,
      );
    },
  );
  test(
    'source survives encrypted payload and backup serialization; legacy payload remains valid',
    () async {
      final note = await service.save(
        email: email('plain'),
        mode: EmailImportMode.editable,
        title: 'Saved',
      );
      final source = note.importSources.single;
      final plaintext = NotePlaintext(
        title: note.title,
        body: note.content,
        tags: note.tags,
        importSources: [source],
      );
      final crypto = DefaultCryptoService();
      final envelope = await crypto.encryptNote(
        plaintext: plaintext,
        masterKeyBytes: keys.masterKey,
        noteId: note.id,
      );
      expect(
        (await crypto.decryptNote(
          envelope: envelope,
          masterKeyBytes: keys.masterKey,
          noteId: note.id,
        )).importSources,
        [source],
      );
      final backup = BackupNote(
        id: note.id,
        title: note.title,
        content: note.content,
        tags: note.tags,
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        importSources: [source],
      );
      expect(BackupNote.fromJson(backup.toJson()).importSources, [source]);
      expect(
        NotePlaintext.fromJson({
          'title': 'old',
          'body': 'legacy',
          'tags': [],
        }).importSources,
        isEmpty,
      );
    },
  );
  test('merge unions source identities without changing body merge policy', () {
    final a = NoteImportSource(
      fingerprint: 'a',
      importedAt: DateTime.utc(2026),
      subject: 'A',
      sender: 'A',
    );
    final b = NoteImportSource(
      fingerprint: 'b',
      importedAt: DateTime.utc(2026),
      subject: 'B',
      sender: 'B',
    );
    final merged = ConflictResolver(database: db).merge3Way(
      base: const NotePlaintext(title: 'T', body: 'body', tags: []),
      local: NotePlaintext(
        title: 'T',
        body: 'body',
        tags: [],
        importSources: [a],
      ),
      remote: NotePlaintext(
        title: 'T',
        body: 'body',
        tags: [],
        importSources: [b],
      ),
    );
    expect(merged.mergedPlaintext.importSources, [a, b]);
  });
  test('database restart retains provenance and indexed duplicates', () async {
    final file = File('${dir.path}/notes.sqlite');
    final disk = AppDatabase(NativeDatabase(file));
    final diskRepo = DriftNotesRepository(disk);
    final source = NoteImportSource(
      fingerprint: 'persisted',
      importedAt: DateTime.utc(2026),
      subject: 'S',
      sender: 'F',
    );
    await diskRepo.saveNote(
      Note(
        id: 'disk',
        title: 'T',
        content: 'C',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        importSources: [source],
      ),
    );
    await disk.close();
    final reopened = AppDatabase(NativeDatabase(file));
    expect(
      (await DriftNotesRepository(reopened).getNoteById('disk'))!.importSources,
      [source],
    );
    expect(
      await reopened.findEmailDuplicates(fingerprint: 'persisted'),
      hasLength(1),
    );
    await reopened.close();
  });
  test(
    'schema 20 upgrades defensively with empty sources and intact note fields',
    () async {
      final file = File('${dir.path}/migration.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await DriftNotesRepository(old).saveNote(
        Note(
          id: 'legacy',
          title: 'Old',
          content: 'Unchanged',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await old.close();
      final connection = sqlite.sqlite3.open(file.path);
      connection.execute('DROP TABLE note_import_source_index');
      connection.execute('DROP TABLE email_import_preparations');
      connection.execute('ALTER TABLE notes DROP COLUMN import_sources');
      connection.execute('DROP TABLE template_favorites');
      connection.execute('DROP TABLE note_templates');
      connection.execute('PRAGMA user_version=20');
      connection.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      final note = (await DriftNotesRepository(
        upgraded,
      ).getNoteById('legacy'))!;
      expect(note.title, 'Old');
      expect(note.content, 'Unchanged');
      expect(note.importSources, isEmpty);
      expect(
        await upgraded.findEmailDuplicates(fingerprint: 'absent'),
        isEmpty,
      );
      await upgraded.close();
    },
  );
  for (final layout in ['templates', 'email']) {
    test('schema 21 $layout layout upgrades to 23 without data loss', () async {
      final file = File('${dir.path}/v21-$layout.sqlite');
      final previous = AppDatabase(NativeDatabase(file));
      final source = NoteImportSource(
        fingerprint: 'existing-email',
        importedAt: DateTime.utc(2026),
        subject: 'Subject',
        sender: 'Sender',
      );
      await DriftNotesRepository(previous).saveNote(
        Note(
          id: 'existing',
          title: 'Keep title',
          content: 'Keep body',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          tags: ['keep'],
          importSources: layout == 'email' ? [source] : [],
        ),
      );
      if (layout == 'templates') {
        final templates = TemplateRepository(previous);
        await templates.insertUserTemplate(fixture());
        await templates.setFavorite(fixture().id, true);
      }
      await previous.close();
      final connection = sqlite.sqlite3.open(file.path);
      if (layout == 'templates') {
        connection.execute('DROP TABLE note_import_source_index');
        connection.execute('DROP TABLE email_import_preparations');
        connection.execute('ALTER TABLE notes DROP COLUMN import_sources');
      } else {
        connection.execute('DROP TABLE template_favorites');
        connection.execute('DROP TABLE note_templates');
      }
      connection.execute('PRAGMA user_version=21');
      connection.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final repository = DriftNotesRepository(upgraded);
        final existing = (await repository.getNoteById('existing'))!;
        expect(existing.title, 'Keep title');
        expect(existing.content, 'Keep body');
        expect(existing.tags, ['keep']);
        expect(existing.importSources, layout == 'email' ? [source] : isEmpty);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .data['user_version'],
          23,
        );
        final templates = TemplateRepository(upgraded);
        if (layout == 'templates') {
          expect(
            (await templates.getUserTemplate(fixture().id))!.content,
            fixture().content,
          );
          expect(await templates.getFavoriteTemplateIds(), {fixture().id});
        } else {
          expect(
            await upgraded.findEmailDuplicates(fingerprint: source.fingerprint),
            hasLength(1),
          );
          await templates.insertUserTemplate(fixture());
          await templates.setFavorite(fixture().id, true);
        }
        final upgradedVault = AttachmentService(
          database: upgraded,
          keyManager: keys,
          storage: storage,
        );
        final imported =
            await EmailImportService(
              database: upgraded,
              repository: repository,
              attachments: upgradedVault,
            ).save(
              email: email('plain'),
              mode: EmailImportMode.editable,
              title: 'New email',
            );
        expect(
          (await repository.getNoteById(imported.id))!.importSources,
          isNotEmpty,
        );
        expect(
          await upgraded.findEmailDuplicates(
            fingerprint: email('plain').fingerprint,
          ),
          hasLength(1),
        );
        expect(
          (await templates.getUserTemplates()).single.content,
          fixture().content,
        );
      } finally {
        await upgraded.close();
      }
    });
  }
  test(
    'real backup restore reconstructs sources, original bytes and duplicate index',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final note = await service.save(
        email: email('mixed'),
        mode: EmailImportMode.editable,
        title: 'Backup',
      );
      final backup = BackupService(
        database: db,
        cryptoService: DefaultCryptoService(),
        sharedPreferences: prefs,
        storage: storage,
      );
      final templates = TemplateRepository(db);
      await templates.insertUserTemplate(fixture());
      await templates.setFavorite(fixture().id, true);
      final payload = BackupPayload.fromJson(
        (await backup.generateBackupPayload()).toJson(),
      );
      final restoredDb = AppDatabase.memory();
      final restoredStorage = AttachmentLocalStorage(
        customBaseDirectory: Directory('${dir.path}/restored'),
      );
      final restore = BackupService(
        database: restoredDb,
        cryptoService: DefaultCryptoService(),
        sharedPreferences: prefs,
        storage: restoredStorage,
      );
      await restore.restoreBackup(payload);
      expect(
        (await TemplateRepository(
          restoredDb,
        ).getUserTemplates()).single.content,
        fixture().content,
      );
      expect(await TemplateRepository(restoredDb).getFavoriteTemplateIds(), {
        fixture().id,
      });
      final restored = (await DriftNotesRepository(
        restoredDb,
      ).getNoteById(note.id))!;
      expect(restored.importSources, note.importSources);
      expect(
        await restoredDb.findEmailDuplicates(
          fingerprint: email('mixed').fingerprint,
        ),
        hasLength(1),
      );
      final restoredVault = AttachmentService(
        database: restoredDb,
        keyManager: keys,
        storage: restoredStorage,
      );
      expect(
        (await restoredVault.resolveAsset(
          restored.importSources.single.sourceAssetId!,
        )).data,
        orderedEquals(email('mixed').rawBytes!),
      );
      await restoredDb.close();
    },
  );
  test(
    'legacy sync envelope preserves sources and schedules encrypted repair',
    () async {
      final saved = await service.save(
        email: email('plain'),
        mode: EmailImportMode.editable,
        title: 'Saved',
      );
      await db.saveNote(
        id: saved.id,
        title: 'Remote edit',
        content: saved.content,
        createdAt: saved.createdAt,
        updatedAt: saved.updatedAt,
        isPinned: false,
        isDirty: false,
        serverRevision: 7,
        importSources: [],
      );
      final row = (await db.getNoteWithTags(saved.id))!.note;
      expect(NoteImportSource.decode(row.importSources), saved.importSources);
      expect(row.isDirty, isTrue);
      expect(row.serverRevision, 7);
    },
  );
  test(
    'merging provenance preserves newer note text and its timestamps',
    () async {
      final saved = await service.save(
        email: email('plain'),
        mode: EmailImportMode.editable,
        title: 'Saved',
      );
      final additional = NoteImportSource(
        fingerprint: 'another',
        importedAt: DateTime.utc(2026),
        subject: 'S',
        sender: 'F',
      );
      final before = (await repo.getNoteById(saved.id))!;
      await db.mergeImportSources(saved.id, [additional]);
      final after = (await repo.getNoteById(saved.id))!;
      expect(after.content, before.content);
      expect(after.updatedAt, before.updatedAt);
      expect(after.importSources, hasLength(2));
      expect(
        await db.findEmailDuplicates(fingerprint: 'another'),
        hasLength(1),
      );
    },
  );
  test(
    'failed file cleanup retains its durable journal until recovery can delete',
    () async {
      final deferred = _DeferredDeleteStorage(dir);
      final guarded = EmailImportService(
        database: db,
        repository: repo,
        attachments: AttachmentService(
          database: db,
          keyManager: keys,
          storage: deferred,
        ),
      );
      var checks = 0;
      await expectLater(
        guarded.save(
          email: email('mixed'),
          mode: EmailImportMode.editable,
          title: 'Cancel',
          isCancelled: () => ++checks > 1,
        ),
        throwsA(isA<EmailImportException>()),
      );
      expect(await db.getAllNotesRaw(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM email_import_preparations').get(),
        isNotEmpty,
      );
      expect(await dir.list().toList(), isNotEmpty);
      deferred.failDelete = false;
      await guarded.recoverInterruptedImports();
      expect(
        await db.customSelect('SELECT * FROM email_import_preparations').get(),
        isEmpty,
      );
      expect(await dir.list().toList(), isEmpty);
    },
  );
}
