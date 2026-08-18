import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/backup/backup_models.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CryptoService cryptoService;
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    cryptoService = DefaultCryptoService();
    tempDir = await Directory.systemTemp.createTemp('qp_backup_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupService Payload Generation & Unencrypted Backup', () {
    test('Generates complete snapshot payload from database', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'note-1',
        title: 'Note One',
        content: 'Content One',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['work', 'ideas'],
      );
      await db.saveNote(
        id: 'note-2',
        title: 'Note Two',
        content: 'Content Two',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        isArchived: true,
        tags: ['personal'],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
        appVersion: '1.2.0',
      );

      final payload = await service.generateBackupPayload();

      expect(payload.manifest.totalNotes, 2);
      expect(payload.manifest.activeNotes, 1);
      expect(payload.manifest.archivedNotes, 1);
      expect(payload.manifest.totalTags, 3);
      expect(payload.notes.length, 2);
      expect(payload.tags, containsAll(['work', 'ideas', 'personal']));
    });

    test('Creates and validates unencrypted .qpbackup file', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'note-1',
        title: 'Note One',
        content: 'Content One',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['test'],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      final file = await service.createBackupFile(
        directoryPath: tempDir.path,
        customFileName: 'test_backup.qpbackup',
      );

      expect(await file.exists(), isTrue);

      final validation = await service.validateBackupFile(file);
      expect(validation.isValid, isTrue);
      expect(validation.isEncrypted, isFalse);
      expect(validation.payload, isNotNull);
      expect(validation.payload!.notes.first.title, 'Note One');
    });
  });

  group('BackupService Encrypted Backup (Argon2id + XChaCha20-Poly1305)', () {
    test('Encrypts backup with password and validates with correct / incorrect password', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'secret-1',
        title: 'Top Secret Note',
        content: 'Confidential thoughts and plans.',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        tags: ['security'],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      final file = await service.createBackupFile(
        directoryPath: tempDir.path,
        customFileName: 'secret_backup.qpbackup',
        password: 'correct-horse-battery-staple',
      );

      expect(await file.exists(), isTrue);

      // 1. Validate without password (should return isEncrypted: true, payload: null)
      final unauthenticatedCheck = await service.validateBackupFile(file);
      expect(unauthenticatedCheck.isValid, isTrue);
      expect(unauthenticatedCheck.isEncrypted, isTrue);
      expect(unauthenticatedCheck.payload, isNull);

      // 2. Validate with WRONG password (should fail auth check)
      final wrongPasswordCheck = await service.validateBackupFile(
        file,
        password: 'wrong-password-1234',
      );
      expect(wrongPasswordCheck.isValid, isFalse);
      expect(wrongPasswordCheck.isEncrypted, isTrue);
      expect(wrongPasswordCheck.payload, isNull);
      expect(wrongPasswordCheck.errorMessage, contains('Incorrect backup password'));

      // 3. Validate with CORRECT password (should successfully decrypt)
      final correctCheck = await service.validateBackupFile(
        file,
        password: 'correct-horse-battery-staple',
      );
      expect(correctCheck.isValid, isTrue);
      expect(correctCheck.isEncrypted, isTrue);
      expect(correctCheck.payload, isNotNull);
      expect(correctCheck.payload!.notes.first.title, 'Top Secret Note');
      expect(correctCheck.payload!.notes.first.content, 'Confidential thoughts and plans.');
    });
  });

  group('BackupService Restore Strategies', () {
    test('RestoreStrategy.merge updates older notes and preserves newer local edits', () async {
      final oldDate = DateTime(2026, 1, 1);
      final newDate = DateTime(2026, 6, 1);
      final futureDate = DateTime(2026, 8, 1);

      // Local state:
      // - note-1 has old version
      // - note-2 has new local edit (futureDate)
      await db.saveNote(
        id: 'note-1',
        title: 'Old Local Title',
        content: 'Old Local Content',
        createdAt: oldDate,
        updatedAt: oldDate,
        isPinned: false,
      );
      await db.saveNote(
        id: 'note-2',
        title: 'Newer Local Title',
        content: 'Newer Local Content',
        createdAt: oldDate,
        updatedAt: futureDate,
        isPinned: false,
      );

      // Backup payload:
      // - note-1 has newer backup version (newDate > oldDate) -> SHOULD UPDATE
      // - note-2 has older backup version (newDate < futureDate) -> SHOULD SKIP
      // - note-3 is completely new -> SHOULD INSERT
      final backupPayload = BackupPayload(
        manifest: BackupManifest(
          format: 'quietpaper:backup:v1',
          version: 1,
          appVersion: '1.2.0',
          createdAt: newDate,
          isEncrypted: false,
          totalNotes: 3,
          activeNotes: 3,
          archivedNotes: 0,
          trashedNotes: 0,
          pinnedNotes: 0,
          totalTags: 1,
        ),
        tags: ['restored-tag'],
        notes: [
          BackupNote(
            id: 'note-1',
            title: 'Updated From Backup',
            content: 'Backup Content 1',
            tags: ['restored-tag'],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: oldDate,
            updatedAt: newDate,
          ),
          BackupNote(
            id: 'note-2',
            title: 'Stale Backup Title',
            content: 'Stale Backup Content',
            tags: [],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: oldDate,
            updatedAt: newDate,
          ),
          BackupNote(
            id: 'note-3',
            title: 'Brand New Note',
            content: 'Brand New Content',
            tags: [],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: newDate,
            updatedAt: newDate,
          ),
        ],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      final result = await service.restoreBackup(
        backupPayload,
        strategy: RestoreStrategy.merge,
      );

      expect(result.totalRestored, 1); // note-3
      expect(result.totalUpdated, 1); // note-1
      expect(result.totalSkipped, 1); // note-2

      final n1 = await (db.select(db.notesTable)..where((n) => n.id.equals('note-1'))).getSingle();
      expect(n1.title, 'Updated From Backup');

      final n2 = await (db.select(db.notesTable)..where((n) => n.id.equals('note-2'))).getSingle();
      expect(n2.title, 'Newer Local Title'); // preserved!

      final n3 = await (db.select(db.notesTable)..where((n) => n.id.equals('note-3'))).getSingle();
      expect(n3.title, 'Brand New Note');
    });

    test('RestoreStrategy.keepBoth clones colliding notes with (Restored) suffix', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'note-collision',
        title: 'Original Title',
        content: 'Original Content',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final backupPayload = BackupPayload(
        manifest: BackupManifest(
          format: 'quietpaper:backup:v1',
          version: 1,
          appVersion: '1.2.0',
          createdAt: now,
          isEncrypted: false,
          totalNotes: 1,
          activeNotes: 1,
          archivedNotes: 0,
          trashedNotes: 0,
          pinnedNotes: 0,
          totalTags: 0,
        ),
        tags: [],
        notes: [
          BackupNote(
            id: 'note-collision',
            title: 'Original Title',
            content: 'Backup Content',
            tags: [],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      final result = await service.restoreBackup(
        backupPayload,
        strategy: RestoreStrategy.keepBoth,
      );

      expect(result.totalConflicts, 1);

      final allNotes = await db.select(db.notesTable).get();
      expect(allNotes.length, 2);
      expect(allNotes.any((n) => n.title == 'Original Title'), isTrue);
      expect(allNotes.any((n) => n.title == 'Original Title (Restored)'), isTrue);
    });

    test('RestoreStrategy.replace clears current database and restores backup snapshot', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'old-note-1',
        title: 'To Be Wiped',
        content: 'Gone',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final backupPayload = BackupPayload(
        manifest: BackupManifest(
          format: 'quietpaper:backup:v1',
          version: 1,
          appVersion: '1.2.0',
          createdAt: now,
          isEncrypted: false,
          totalNotes: 1,
          activeNotes: 1,
          archivedNotes: 0,
          trashedNotes: 0,
          pinnedNotes: 0,
          totalTags: 0,
        ),
        tags: [],
        notes: [
          BackupNote(
            id: 'fresh-note-1',
            title: 'Fresh Clean Note',
            content: 'Clean content',
            tags: [],
            isPinned: false,
            isArchived: false,
            isTrashed: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      final result = await service.restoreBackup(
        backupPayload,
        strategy: RestoreStrategy.replace,
      );

      expect(result.totalRestored, 1);

      final allNotes = await db.select(db.notesTable).get();
      expect(allNotes.length, 1);
      expect(allNotes.first.id, 'fresh-note-1');
      expect(allNotes.first.title, 'Fresh Clean Note');
    });
  });

  group('Automated Rolling Backups & Pruning', () {
    test('Prunes oldest auto-backup files exceeding retention count', () async {
      final service = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
      );

      // Create 5 dummy auto-backup files
      for (var i = 1; i <= 5; i++) {
        final f = File('${tempDir.path}/quietpaper_autobackup_2026-08-0$i.qpbackup');
        await f.writeAsString('{"test": $i}');
        // Sleep slightly to guarantee different modification times
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }

      var files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 5);

      // Prune to keep only 3
      final pruned = await service.pruneOldAutoBackups(tempDir, 3);
      expect(pruned, 2);

      files = tempDir.listSync().whereType<File>().toList();
      expect(files.length, 3);
      // Newest files (04, 05, 03) should remain
      expect(files.any((f) => f.path.contains('2026-08-05')), isTrue);
      expect(files.any((f) => f.path.contains('2026-08-04')), isTrue);
      expect(files.any((f) => f.path.contains('2026-08-03')), isTrue);
      expect(files.any((f) => f.path.contains('2026-08-01')), isFalse);
    });
  });
}
