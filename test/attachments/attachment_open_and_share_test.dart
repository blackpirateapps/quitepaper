import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_open_service.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_share_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/attachments/attachment_temp_storage.dart';
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
  late AttachmentTempStorage tempStorage;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('attachment_open_share_test_');
    db = AppDatabase.memory();
    cryptoService = DefaultCryptoService();
    final masterKey = cryptoService.generateRandomBytes(32);
    keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

    attachmentCrypto = AttachmentCrypto(cryptoService: cryptoService);
    attachmentStorage = AttachmentLocalStorage(customBaseDirectory: tempDir);
    tempStorage = AttachmentTempStorage(customTempDirectoryProvider: () async => tempDir);

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

  group('AttachmentTempStorage Lifecycle Tests', () {
    test('creates ephemeral decrypted file with sanitized name in isolated folder', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final tempFile = await tempStorage.createTemporaryDecryptedFile(
        attachmentId: 'att-1234',
        rawFileName: '../../sensitive_report.docx',
        plaintextBytes: sampleBytes,
      );

      expect(await tempFile.exists(), isTrue);
      expect(tempFile.uri.pathSegments.last, 'sensitive_report.docx');
      expect(await tempFile.readAsBytes(), equals(sampleBytes));

      await tempStorage.deleteTemporaryFile(tempFile);
      expect(await tempFile.exists(), isFalse);
    });

    test('cleans stale temporary files older than specified age', () async {
      final oldDir = Directory('${tempDir.path}/${AttachmentTempStorage.tempFolderName}/old_att_folder');
      await oldDir.create(recursive: true);
      final oldFile = File('${oldDir.path}/stale.pdf');
      await oldFile.writeAsBytes([1, 2, 3]);

      // Set modification date to 2 hours ago on file
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      await oldFile.setLastModified(twoHoursAgo);

      final cleanedCount = await tempStorage.cleanStaleTempFiles(maxAge: const Duration(hours: 1));
      expect(cleanedCount, greaterThanOrEqualTo(1));
      expect(await oldFile.exists(), isFalse);
    });
  });

  group('AttachmentOpenService Tests', () {
    test('decrypts and prepares file for open call', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.blackpiratex.quietpaper/updater'), (call) async {
        if (call.method == 'openFile') {
          return true;
        }
        return null;
      });

      final bytes = Uint8List.fromList([65, 66, 67, 68]);
      final res = await attachmentService.importGenericFileFromBytes(
        bytes,
        fileName: 'readme.txt',
      );

      final openService = AttachmentOpenService(
        attachmentService: attachmentService,
        tempStorage: tempStorage,
      );

      final openResult = await openService.openAttachment(res.attachment.id);
      expect(openResult.status, AttachmentOpenStatus.opened);
    });
  });

  group('AttachmentShareService Tests', () {
    test('decrypts attachment to temp file for sharing', () async {
      final bytes = Uint8List.fromList([100, 101, 102]);
      final res = await attachmentService.importGenericFileFromBytes(
        bytes,
        fileName: 'data.json',
      );

      final shareService = AttachmentShareService(
        attachmentService: attachmentService,
        tempStorage: tempStorage,
      );

      // MethodChannel mock for share_plus
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        return null;
      });

      final success = await shareService.shareAttachment(res.attachment.id);
      expect(success, isTrue);
    });
  });
}
