import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/import/application/markdown_import_service.dart';
import 'package:quitepaper/features/import/domain/import_image_reference.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

class MockTestKeyManager implements KeyManager {
  MockTestKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

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
  group('MarkdownImportService Image Ingestion Tests', () {
    late AppDatabase db;
    late NotesRepository repository;
    late Directory tempDir;
    late AttachmentLocalStorage storage;
    late MockTestKeyManager keyManager;
    late AttachmentService attachmentService;
    late CryptoService cryptoService;
    late MarkdownImportService importService;
    late File testImageFile;

    setUp(() async {
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
      tempDir = await Directory.systemTemp.createTemp('qp_import_service_test_');
      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockTestKeyManager(masterKey: masterKey, isUnlocked: true);

      attachmentService = AttachmentService(
        database: db,
        keyManager: keyManager,
        crypto: AttachmentCrypto(cryptoService: cryptoService),
        storage: storage,
      );

      importService = MarkdownImportService(
        repository,
        attachmentService: attachmentService,
      );

      testImageFile = File(p.join(tempDir.path, 'photo.png'))
        ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('imports note, encrypts linked image and rewrites markdown link to qp://asset/UUID', () async {
      final imageRef = ImportImageReference(
        originalSyntax: '![My Photo](images/photo.png)',
        rawTarget: 'images/photo.png',
        altText: 'My Photo',
        resolvedFilePath: testImageFile.path,
        fileSizeBytes: 8,
        status: ImportImageStatus.resolved,
      );

      final item = MarkdownImportItem(
        id: 'note-import-img-1',
        filePath: p.join(tempDir.path, 'note.md'),
        relativePath: 'note.md',
        title: 'Note With Image',
        content: '# Title\n\n![My Photo](images/photo.png)\n\nCaption text.',
        tags: ['photos'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        fileSizeBytes: 100,
        isSelected: true,
        imageReferences: [imageRef],
      );

      final count = await importService.importNotes([item]);
      expect(count, equals(1));

      final savedNote = await repository.getNoteById('note-import-img-1');
      expect(savedNote, isNotNull);
      expect(savedNote!.content.contains('qp://asset/'), isTrue);
      expect(savedNote.content.contains('images/photo.png'), isFalse);

      final attachments = await db.getAllAttachments();
      expect(attachments.length, equals(1));
      expect(attachments.first.byteSize, equals(8));
      expect(attachments.first.noteId, equals('note-import-img-1'));
    });

    test('deduplicates shared image across multiple notes in batch', () async {
      final imageRef1 = ImportImageReference(
        originalSyntax: '![Shared](photo.png)',
        rawTarget: 'photo.png',
        altText: 'Shared',
        resolvedFilePath: testImageFile.path,
        fileSizeBytes: 8,
        status: ImportImageStatus.resolved,
      );

      final imageRef2 = ImportImageReference(
        originalSyntax: '![Shared 2](photo.png)',
        rawTarget: 'photo.png',
        altText: 'Shared 2',
        resolvedFilePath: testImageFile.path,
        fileSizeBytes: 8,
        status: ImportImageStatus.resolved,
      );

      final item1 = MarkdownImportItem(
        id: 'note-1',
        filePath: '/tmp/note1.md',
        relativePath: 'note1.md',
        title: 'Note 1',
        content: '![Shared](photo.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 50,
        imageReferences: [imageRef1],
      );

      final item2 = MarkdownImportItem(
        id: 'note-2',
        filePath: '/tmp/note2.md',
        relativePath: 'note2.md',
        title: 'Note 2',
        content: '![Shared 2](photo.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 50,
        imageReferences: [imageRef2],
      );

      final count = await importService.importNotes([item1, item2]);
      expect(count, equals(2));

      // Both notes should have been saved with canonical qp://asset/ URIs
      final saved1 = await repository.getNoteById('note-1');
      final saved2 = await repository.getNoteById('note-2');
      expect(saved1!.content, contains('qp://asset/'));
      expect(saved2!.content, contains('qp://asset/'));

      // Ingested once into database
      final attachments = await db.getAllAttachments();
      expect(attachments.length, equals(1));
    });
  });
}
