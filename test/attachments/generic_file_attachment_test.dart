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

  late AppDatabase db;
  late DefaultCryptoService cryptoService;
  late MockKeyManager keyManager;
  late AttachmentCrypto attachmentCrypto;
  late AttachmentLocalStorage attachmentStorage;
  late AttachmentService attachmentService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('generic_attachment_test_');
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

  group('Generic Encrypted File Attachment Tests', () {
    test('imports generic files (e.g. DOCX, XLSX, ZIP, Python) with client-side authenticated encryption', () async {
      final sampleDocxBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00]);
      final res = await attachmentService.importGenericFileFromBytes(
        sampleDocxBytes,
        fileName: 'Project_Specification.docx',
      );

      final attachment = res.attachment;
      expect(attachment.fileName, 'Project_Specification.docx');
      expect(attachment.kind, 'file');
      expect(attachment.mimeType, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(attachment.byteSize, sampleDocxBytes.length);
      expect(attachment.ocrState, 'not_requested');
      expect(res.markdownSnippet, '[Project_Specification.docx](qp://asset/${attachment.id})');

      // Verify encrypted file format starts with QPA1 magic header
      final diskFile = File(attachment.localPath!);
      expect(await diskFile.exists(), isTrue);
      final encryptedBytes = await diskFile.readAsBytes();
      expect(String.fromCharCodes(encryptedBytes.sublist(0, 4)), 'QPA1');

      // Verify decrypted resolution returns exact 100% byte fidelity
      final resolution = await attachmentService.resolveAsset(attachment.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(sampleDocxBytes));
    });

    test('supports zero-byte files as valid encrypted attachments', () async {
      final emptyBytes = Uint8List(0);
      final res = await attachmentService.importGenericFileFromBytes(
        emptyBytes,
        fileName: 'empty_log.txt',
      );

      final attachment = res.attachment;
      expect(attachment.byteSize, 0);
      expect(attachment.fileName, 'empty_log.txt');
      expect(attachment.sha256, AttachmentCrypto.computeSha256(emptyBytes));

      final resolution = await attachmentService.resolveAsset(attachment.id);
      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(emptyBytes));
    });

    test('rejects files exceeding 50 MB with clear error message', () async {
      final oversizedBytes = Uint8List(51 * 1024 * 1024);
      expect(
        () => attachmentService.importGenericFileFromBytes(
          oversizedBytes,
          fileName: 'large_dataset.bin',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('File exceeds maximum allowed size of 50 MB'),
        )),
      );
    });

    test('strictly sanitizes filename when importing', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final res = await attachmentService.importGenericFileFromBytes(
        bytes,
        fileName: '../../../../etc/passwd',
      );

      expect(res.attachment.fileName, 'passwd');
      expect(res.markdownSnippet, '[passwd](qp://asset/${res.attachment.id})');
    });

    test('renaming attachment updates metadata without altering byte hash or storage payload', () async {
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final initial = await attachmentService.importGenericFileFromBytes(
        sampleBytes,
        fileName: 'original_name.xlsx',
      );

      final origSha = initial.attachment.sha256;
      final origByteSize = initial.attachment.byteSize;
      final origLocalPath = initial.attachment.localPath;

      // Rename
      await attachmentService.renameAttachment(initial.attachment.id, 'renamed_quarterly_budget.xlsx');

      final updated = await db.getAttachment(initial.attachment.id);
      expect(updated, isNotNull);
      expect(updated!.fileName, 'renamed_quarterly_budget.xlsx');
      expect(updated.sha256, origSha);
      expect(updated.byteSize, origByteSize);
      expect(updated.localPath, origLocalPath);
      expect(updated.isDirty, isTrue);

      // Decrypted bytes still match perfectly
      final resolution = await attachmentService.resolveAsset(initial.attachment.id);
      expect(resolution.data, equals(sampleBytes));
    });

    test('deleting attachment removes local encrypted file and sets tombstone', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3]);
      final res = await attachmentService.importGenericFileFromBytes(
        sampleBytes,
        fileName: 'to_delete.zip',
      );

      final diskFile = File(res.attachment.localPath!);
      expect(await diskFile.exists(), isTrue);

      await attachmentService.deleteAttachment(res.attachment.id, enqueueSync: false);

      final record = await db.getAttachment(res.attachment.id);
      expect(record!.isDeleted, isTrue);
      expect(await diskFile.exists(), isFalse);
    });
  });
}
