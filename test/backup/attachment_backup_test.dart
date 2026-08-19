import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/backup/backup_models.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Attachment Backup & Restore Tests', () {
    late AppDatabase db;
    late Directory tempDir;
    late AttachmentLocalStorage storage;
    late BackupService backupService;
    late CryptoService cryptoService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_backup_att_');
      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      cryptoService = DefaultCryptoService();

      backupService = BackupService(
        database: db,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
        storage: storage,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Generates backup payload including attachments and restores them into clean database', () async {
      const noteId = '11111111-1111-1111-1111-111111111111';
      const attachmentId = '22222222-2222-2222-2222-222222222222';
      final encryptedBytes = Uint8List.fromList([0x51, 0x50, 0x41, 0x31, 5, 6, 7, 8]);

      // Save note
      await db.saveNote(
        id: noteId,
        title: 'Trip to Tokyo',
        content: 'Photo:\n![Tokyo Tower](qp://asset/$attachmentId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        tags: ['travel', 'japan'],
      );

      // Save encrypted file and db record
      final localPath = await storage.saveEncryptedBytes(
        attachmentId: attachmentId,
        encryptedBytes: encryptedBytes,
      );

      await db.saveAttachment(
        id: attachmentId,
        noteId: noteId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'image/jpeg',
        byteSize: 1024,
        sha256: 'fakehash123',
        localPath: localPath,
      );

      // Generate backup
      final payload = await backupService.generateBackupPayload();
      expect(payload.manifest.totalNotes, 1);
      expect(payload.manifest.totalAttachments, 1);
      expect(payload.attachments.length, 1);
      expect(payload.attachments.first.id, attachmentId);
      expect(payload.attachments.first.encryptedPayloadBase64, isNotNull);

      // Restore into fresh DB and directory
      final cleanDb = AppDatabase.memory();
      final cleanDir = await Directory.systemTemp.createTemp('qp_clean_restore_');
      final cleanStorage = AttachmentLocalStorage(customBaseDirectory: cleanDir);
      final prefs = await SharedPreferences.getInstance();

      final restoreService = BackupService(
        database: cleanDb,
        cryptoService: cryptoService,
        sharedPreferences: prefs,
        storage: cleanStorage,
      );

      final result = await restoreService.restoreBackup(payload, strategy: RestoreStrategy.replace);
      expect(result.totalRestored, 1);

      // Verify restored note and attachment in database
      final restoredNote = await cleanDb.getNoteWithTags(noteId);
      expect(restoredNote, isNotNull);

      final restoredAtt = await cleanDb.getAttachment(attachmentId);
      expect(restoredAtt, isNotNull);
      expect(restoredAtt!.isDirty, isTrue);
      expect(restoredAtt.uploadState, 'upload_pending');

      // Verify restored encrypted file on disk
      final hasFile = await cleanStorage.hasEncryptedFile(attachmentId: attachmentId);
      expect(hasFile, isTrue);

      final readBytes = await cleanStorage.readEncryptedBytes(attachmentId: attachmentId);
      expect(readBytes, equals(encryptedBytes));

      await cleanDb.close();
      if (await cleanDir.exists()) {
        await cleanDir.delete(recursive: true);
      }
    });

    test('Generates and decrypts Argon2id password-protected backup containing attachments', () async {
      const noteId = '33333333-3333-3333-3333-333333333333';
      const attachmentId = '44444444-4444-4444-4444-444444444444';
      const password = 'SuperSecurePassword2026!';

      await db.saveNote(
        id: noteId,
        title: 'Encrypted Note',
        content: '![Secret](qp://asset/$attachmentId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final localPath = await storage.saveEncryptedBytes(
        attachmentId: attachmentId,
        encryptedBytes: Uint8List.fromList([0x51, 0x50, 0x41, 0x31, 9, 9, 9]),
      );

      await db.saveAttachment(
        id: attachmentId,
        noteId: noteId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        localPath: localPath,
      );

      // Generate encrypted backup string
      final backupString = await backupService.generateBackupString(password: password);
      expect(backupString, contains('quietpaper:encrypted-backup:v1'));

      // Validate and decrypt
      final validation = await backupService.validateBackupString(backupString, password: password);
      expect(validation.isValid, isTrue);
      expect(validation.isEncrypted, isTrue);
      expect(validation.payload, isNotNull);
      expect(validation.payload!.attachments.length, 1);
      expect(validation.payload!.attachments.first.id, attachmentId);
    });
  });
}
