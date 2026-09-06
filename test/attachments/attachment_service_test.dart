import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';

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

  group('AttachmentService Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late AttachmentLocalStorage storage;
    late MockKeyManager keyManager;
    late AttachmentService attachmentService;
    late CryptoService cryptoService;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_attachments_');
      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      attachmentService = AttachmentService(
        database: database,
        keyManager: keyManager,
        crypto: AttachmentCrypto(cryptoService: cryptoService),
        storage: storage,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Imports image bytes, persists encrypted payload and returns markdown token', () async {
      final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);

      final result = await attachmentService.importImageFromBytes(
        imageBytes,
        mimeType: 'image/png',
        preferredAltText: 'Test Diagram',
      );

      expect(result.attachment.id, isNotEmpty);
      expect(result.attachment.mimeType, 'image/png');
      expect(result.attachment.byteSize, imageBytes.length);
      expect(result.markdownSnippet, startsWith('![Test Diagram](qp://asset/'));

      // Check DB record
      final dbRecord = await database.getAttachment(result.attachment.id);
      expect(dbRecord, isNotNull);
      expect(dbRecord!.isDirty, isTrue);
      expect(dbRecord.uploadState, 'upload_pending');

      // Resolve asset
      final resolution = await attachmentService.resolveAsset(result.attachment.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(imageBytes));
    });

    test('Returns locked resolution when KeyManager is locked', () async {
      final imageBytes = Uint8List.fromList([10, 20, 30, 40]);
      final result = await attachmentService.importImageFromBytes(
        imageBytes,
        mimeType: 'image/jpeg',
      );

      // Invalidate memory cache and lock key manager
      storage.invalidateDecryptedCache(result.attachment.id);
      keyManager.lock();

      final resolution = await attachmentService.resolveAsset(result.attachment.id);
      expect(resolution.isLocked, isTrue);
      expect(resolution.isAvailable, isFalse);
    });

    test('Returns missing resolution for non-existent attachment', () async {
      const nonExistentId = '11111111-1111-1111-1111-111111111111';
      final resolution = await attachmentService.resolveAsset(nonExistentId);
      expect(resolution.isMissing, isTrue);
      expect(resolution.isAvailable, isFalse);
    });

    test('Soft deletes attachment and cleans up local storage', () async {
      final imageBytes = Uint8List.fromList([5, 6, 7, 8]);
      final result = await attachmentService.importImageFromBytes(
        imageBytes,
        mimeType: 'image/png',
      );

      await attachmentService.deleteAttachment(result.attachment.id);

      final dbRecord = await database.getAttachment(result.attachment.id);
      expect(dbRecord!.isDeleted, isTrue);

      final resolution = await attachmentService.resolveAsset(result.attachment.id);
      expect(resolution.isMissing, isTrue);
    });

    test('replaceImage replaces local unsynced image, discards old file, and rewrites note links', () async {
      // 1. Setup note with reference to initial image
      const noteId = 'test-note-1';
      final oldBytes = Uint8List.fromList([1, 2, 3, 4]);
      final initialResult = await attachmentService.importImageFromBytes(
        oldBytes,
        mimeType: 'image/png',
        noteId: noteId,
        preferredAltText: 'Original Diagram',
      );
      final oldAssetId = initialResult.attachment.id;

      await database.saveNote(
        id: noteId,
        title: 'Meeting Note',
        content: '# Notes\n![Diagram](qp://asset/$oldAssetId)\nSome text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // 2. Perform replaceImage with new edited bytes
      final newBytes = Uint8List.fromList([99, 98, 97, 96, 95]);
      final replaceResult = await attachmentService.replaceImage(
        oldAssetId: oldAssetId,
        newBytes: newBytes,
        mimeType: 'image/jpeg',
        fileName: 'edited_diagram.jpg',
        noteId: noteId,
        preferredAltText: 'Edited Diagram',
      );

      final newAssetId = replaceResult.newAttachment.id;
      expect(newAssetId, isNot(equals(oldAssetId)));
      expect(replaceResult.newAttachment.uploadState, equals('upload_pending'));
      expect(replaceResult.newAttachment.byteSize, equals(newBytes.length));

      // 3. Old image should be completely discarded
      final oldRecord = await database.getAttachment(oldAssetId);
      expect(oldRecord, isNull);
      final oldResolution = await attachmentService.resolveAsset(oldAssetId);
      expect(oldResolution.isMissing, isTrue);

      // 4. New image should be resolvable and decrypted properly
      final newResolution = await attachmentService.resolveAsset(newAssetId);
      expect(newResolution.isAvailable, isTrue);
      expect(newResolution.data, equals(newBytes));

      // 5. Note references should be rewritten to new asset ID and marked dirty
      final updatedNote = await database.getNoteWithTags(noteId);
      expect(updatedNote, isNotNull);
      expect(updatedNote!.note.content, contains('qp://asset/$newAssetId'));
      expect(updatedNote.note.content, isNot(contains('qp://asset/$oldAssetId')));
      expect(updatedNote.note.isDirty, isTrue);
    });

    test('replaceImage on synced image marks old attachment deleted for cloud GC and queues new image', () async {
      final oldBytes = Uint8List.fromList([10, 20, 30, 40]);
      final initialResult = await attachmentService.importImageFromBytes(
        oldBytes,
        mimeType: 'image/png',
      );
      final oldAssetId = initialResult.attachment.id;

      // Simulate attachment being synced to cloud
      await database.saveAttachment(
        id: oldAssetId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        uploadState: 'synced',
        cloudUrl: 'https://res.cloudinary.com/demo/image/upload/v1/sample.jpg',
        cloudPublicId: 'sample_cloudinary_id',
        serverRevision: 1,
      );

      final newBytes = Uint8List.fromList([50, 60, 70, 80]);
      final replaceResult = await attachmentService.replaceImage(
        oldAssetId: oldAssetId,
        newBytes: newBytes,
        mimeType: 'image/jpeg',
      );

      final newAssetId = replaceResult.newAttachment.id;

      // Old attachment should be soft-deleted in DB with sync queued for cloud garbage collector
      final oldRecord = await database.getAttachment(oldAssetId);
      expect(oldRecord, isNotNull);
      expect(oldRecord!.isDeleted, isTrue);
      expect(oldRecord.isDirty, isTrue);

      // Old local file should be deleted
      final hasOldFile = await storage.hasEncryptedFile(attachmentId: oldAssetId);
      expect(hasOldFile, isFalse);

      // New attachment should be queued for upload
      final newRecord = await database.getAttachment(newAssetId);
      expect(newRecord, isNotNull);
      expect(newRecord!.uploadState, equals('upload_pending'));
      expect(newRecord.isDirty, isTrue);
    });
  });
}
