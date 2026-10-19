import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_processing_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';

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

class FakeAttachmentProcessingService extends AttachmentProcessingService {
  FakeAttachmentProcessingService({
    required super.database,
    required super.keyManager,
  });

  int processCalls = 0;

  @override
  Future<void> processAttachment({
    required String attachmentId,
    required Uint8List imageBytes,
    OcrLanguage language = OcrLanguage.english,
    bool force = false,
  }) async {
    processCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DefaultCryptoService cryptoService;
  late MockKeyManager keyManager;
  late AttachmentCrypto attachmentCrypto;
  late AttachmentLocalStorage attachmentStorage;
  late AttachmentService attachmentService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('link_preview_attachment_test_');
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
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Link Preview Attachment Tests', () {
    test('getAttachmentsForNote hides linkPreview kind but returns image kind', () async {
      const noteId = 'note-1';
      final now = DateTime.now();

      await db.saveAttachment(
        id: 'img-1',
        noteId: noteId,
        fileName: 'photo.png',
        kind: 'image',
        createdAt: now,
        updatedAt: now,
      );
      await db.saveAttachment(
        id: 'preview-1',
        noteId: noteId,
        fileName: 'preview.png',
        kind: 'linkPreview',
        createdAt: now,
        updatedAt: now,
      );

      final visible = await db.getAttachmentsForNote(noteId);
      final visibleIds = visible.map((a) => a.id).toList();

      expect(visibleIds, contains('img-1'));
      expect(visibleIds, isNot(contains('preview-1')));

      // Sanity: the hidden row still exists and is fetchable directly.
      final hidden = await db.getAttachment('preview-1');
      expect(hidden, isNotNull);
      expect(hidden!.kind, 'linkPreview');
    });

    test('watchAttachmentsForNote excludes linkPreview rows', () async {
      const noteId = 'note-2';
      final now = DateTime.now();

      await db.saveAttachment(
        id: 'img-2',
        noteId: noteId,
        fileName: 'photo.png',
        kind: 'image',
        createdAt: now,
        updatedAt: now,
      );
      await db.saveAttachment(
        id: 'preview-2',
        noteId: noteId,
        fileName: 'preview.png',
        kind: 'linkPreview',
        createdAt: now,
        updatedAt: now,
      );

      final emitted = await db
          .watchAttachmentsForNote(noteId)
          .first;
      final emittedIds = emitted.map((a) => a.id).toList();

      expect(emittedIds, contains('img-2'));
      expect(emittedIds, isNot(contains('preview-2')));
    });

    test('importImageFromBytes with kind:linkPreview, skipOcr:true marks ocr not_requested and stays hidden', () async {
      const noteId = 'note-3';
      // Minimal 1x1 PNG header-ish bytes; content is irrelevant for this path.
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final res = await attachmentService.importImageFromBytes(
        pngBytes,
        mimeType: 'image/png',
        fileName: 'link_preview.png',
        noteId: noteId,
        kind: 'linkPreview',
        skipOcr: true,
      );

      final attachment = res.attachment;
      expect(attachment.kind, 'linkPreview');
      expect(attachment.ocrState, 'not_requested');
      expect(attachment.noteId, noteId);
      // Snippet is still a qp://asset token (sentinel will embed this id, not a visible image).
      expect(res.markdownSnippet, '![Image](qp://asset/${attachment.id})');

      // Encrypted bytes round-trip intact.
      final resolution = await attachmentService.resolveAsset(attachment.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(pngBytes));

      // Excluded from the user-facing note attachment list.
      final visible = await db.getAttachmentsForNote(noteId);
      expect(visible.map((a) => a.id), isNot(contains(attachment.id)));
    });

    test('importImageFromBytes default (kind:image) stays visible and queues OCR state', () async {
      const noteId = 'note-4';
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final res = await attachmentService.importImageFromBytes(
        pngBytes,
        mimeType: 'image/png',
        fileName: 'image.png',
        noteId: noteId,
      );

      final attachment = res.attachment;
      expect(attachment.kind, 'image');
      // No processingService is wired here, but with kind:image/skipOcr:false the
      // row is still marked 'queued' (default behavior preserved).
      expect(attachment.ocrState, 'queued');

      final visible = await db.getAttachmentsForNote(noteId);
      expect(visible.map((a) => a.id), contains(attachment.id));
    });

    test('deferred OCR starts only when explicitly scheduled after import', () async {
      final processingService = FakeAttachmentProcessingService(
        database: db,
        keyManager: keyManager,
      );
      attachmentService = AttachmentService(
        database: db,
        keyManager: keyManager,
        crypto: attachmentCrypto,
        storage: attachmentStorage,
        processingService: processingService,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);

      final result = await attachmentService.importImageFromBytes(
        bytes,
        mimeType: 'image/png',
        deferOcr: true,
      );

      expect(result.attachment.ocrState, 'queued');
      expect(processingService.processCalls, 0);

      attachmentService.processImageOcrInBackground(
        attachmentId: result.attachment.id,
        imageBytes: bytes,
      );
      expect(processingService.processCalls, 1);
    });
  });
}
