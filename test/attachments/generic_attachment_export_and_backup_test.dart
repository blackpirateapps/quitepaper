import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/backup/backup_models.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/features/export/application/attachment_export_resolver.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DefaultCryptoService cryptoService;
  late MockKeyManager keyManager;
  late AttachmentCrypto attachmentCrypto;
  late AttachmentLocalStorage attachmentStorage;
  late AttachmentService attachmentService;
  late DocumentService documentService;
  late BackupService backupService;
  late AttachmentExportResolver exportResolver;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('attachment_export_backup_test_');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase.memory();
    cryptoService = DefaultCryptoService();
    final masterKey = cryptoService.generateRandomBytes(32);
    keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

    attachmentCrypto = AttachmentCrypto(cryptoService: cryptoService);
    attachmentStorage = AttachmentLocalStorage(customBaseDirectory: tempDir);

    attachmentService = AttachmentService(
      database: db,
      keyManager: keyManager,
      crypto: attachmentCrypto,
      storage: attachmentStorage,
    );

    final docStorage = DocumentLocalStorage(customDocumentsDirectory: tempDir);
    final docCrypto = DocumentCrypto(cryptoService: cryptoService);
    documentService = DocumentService(
      database: db,
      keyManager: keyManager,
      crypto: docCrypto,
      storage: docStorage,
    );

    backupService = BackupService(
      database: db,
      storage: attachmentStorage,
      documentStorage: docStorage,
      cryptoService: cryptoService,
      sharedPreferences: prefs,
    );

    exportResolver = AttachmentExportResolver(
      database: db,
      attachmentService: attachmentService,
      documentService: documentService,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Generic Attachment Export & Backup Tests', () {
    test('resolves generic file link references and embeds them into export package', () async {
      final noteId = 'note-export-1';
      await db.saveNote(
        id: noteId,
        title: 'Project Note',
        content: 'Content placeholder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final fileBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x11, 0x22]);
      final imported = await attachmentService.importGenericFileFromBytes(
        fileBytes,
        fileName: 'Project_Archive.zip',
        noteId: noteId,
      );

      final markdownText = '# Project\n\nDownload source: [Project_Archive.zip](qp://asset/${imported.attachment.id})';

      final exportResult = await exportResolver.resolveResourcesForNote(
        noteId: noteId,
        canonicalMarkdown: markdownText,
        strategy: AttachmentExportStrategy.embedLocally,
      );

      expect(exportResult.attachments.length, 1);
      expect(exportResult.attachments.first.originalFilename, 'Project_Archive.zip');
      expect(exportResult.attachments.first.bytes, equals(fileBytes));
      expect(exportResult.attachments.first.relativePath, 'attachments/Project_Archive.zip');
      expect(
        exportResult.transformedMarkdown,
        '# Project\n\nDownload source: [Project_Archive.zip](attachments/Project_Archive.zip)',
      );
    });

    test('creates backup with generic files and restores byte-for-byte fidelity', () async {
      final noteId = 'note-backup-1';
      await db.saveNote(
        id: noteId,
        title: 'Financial Model',
        content: 'Financial summary',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final xlsxBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x99, 0x88, 0x77]);
      final imported = await attachmentService.importGenericFileFromBytes(
        xlsxBytes,
        fileName: 'Q3_Forecast.xlsx',
        noteId: noteId,
      );

      // Generate backup payload
      final payload = await backupService.generateBackupPayload();
      expect(payload.attachments.length, 1);
      expect(payload.attachments.first.fileName, 'Q3_Forecast.xlsx');
      expect(payload.attachments.first.kind, 'file');
      expect(payload.attachments.first.byteSize, xlsxBytes.length);

      // Delete attachment
      await db.deleteAttachment(imported.attachment.id, enqueueSync: false);
      expect(await db.getAttachment(imported.attachment.id), isNotNull);
      expect((await db.getAttachment(imported.attachment.id))!.isDeleted, isTrue);

      // Restore backup with replace strategy
      final restoreRes = await backupService.restoreBackup(payload, strategy: RestoreStrategy.replace);
      expect(restoreRes.totalRestored, greaterThanOrEqualTo(1));

      final restoredRecord = await db.getAttachment(imported.attachment.id);
      expect(restoredRecord, isNotNull);
      expect(restoredRecord!.fileName, 'Q3_Forecast.xlsx');
      expect(restoredRecord.kind, 'file');
      expect(restoredRecord.isDeleted, isFalse);

      // Verify decrypted bytes
      final resolution = await attachmentService.resolveAsset(imported.attachment.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(xlsxBytes));
    });
  });
}
