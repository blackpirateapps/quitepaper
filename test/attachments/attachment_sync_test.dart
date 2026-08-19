import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_models.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/attachments/attachment_sync_service.dart';
import 'package:quitepaper/core/attachments/cloudinary_client.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';

class MockAuthService implements AuthService {
  @override
  AuthUser? currentUser = const AuthUser(
    id: 'user_123',
    email: 'user@example.com',
    idToken: 'mock-jwt-token',
  );

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-jwt-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSyncApiClient implements SyncApiClient {
  CloudinaryUploadAuth? lastRequestedAuth;
  Map<String, dynamic>? lastConfirmedData;

  @override
  Future<CloudinaryUploadAuth> getAttachmentUploadAuth({
    required String attachmentId,
    String? noteId,
    String mimeType = 'image/png',
    int byteSize = 0,
    String sha256 = '',
    String variant = 'original',
  }) async {
    lastRequestedAuth = CloudinaryUploadAuth(
      uploadUrl: 'https://api.cloudinary.com/v1_1/test-cloud/raw/upload',
      cloudName: 'test-cloud',
      apiKey: 'test-key',
      signature: 'test-signature-12345',
      timestamp: 1700000000,
      publicId: 'user_123_$attachmentId',
      folder: 'quitepaper_test',
    );
    return lastRequestedAuth!;
  }

  @override
  Future<Map<String, dynamic>> confirmAttachmentUpload({
    required String attachmentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    int byteSize = 0,
    String sha256 = '',
  }) async {
    lastConfirmedData = {
      'attachmentId': attachmentId,
      'cloudPublicId': cloudPublicId,
      'cloudUrl': cloudUrl,
    };
    return {'success': true};
  }

  final Map<String, AttachmentSyncPayload> serverAttachments = {};

  @override
  Future<AttachmentSyncPayload?> getAttachmentMetadata(String attachmentId) async {
    return serverAttachments[attachmentId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCloudinaryClient implements CloudinaryClient {
  Uint8List? lastUploadedBytes;
  CloudinaryUploadAuth? lastAuth;
  bool throwOnUpload = false;

  @override
  Future<CloudinaryUploadResult> uploadEncryptedBytes({
    required Uint8List encryptedBytes,
    required CloudinaryUploadAuth auth,
  }) async {
    if (throwOnUpload) {
      throw const CloudinaryException('Cloudinary upload rejected: invalid credentials', statusCode: 401);
    }
    lastUploadedBytes = encryptedBytes;
    lastAuth = auth;
    return CloudinaryUploadResult(
      publicId: auth.publicId,
      secureUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v1/${auth.publicId}',
      byteSize: encryptedBytes.length,
    );
  }

  Uint8List? downloadBytesResponse;

  @override
  Future<Uint8List> downloadEncryptedBytes({required String cloudUrl}) async {
    return downloadBytesResponse ?? Uint8List.fromList([1, 2, 3]);
  }
}

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey});
  final Uint8List masterKey;
  @override
  bool get isUnlocked => true;
  @override
  Uint8List getMasterKey() => masterKey;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentSyncService Direct Cloudinary Upload Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late AttachmentLocalStorage storage;
    late MockSyncApiClient apiClient;
    late MockCloudinaryClient cloudinaryClient;
    late MockAuthService authService;
    late MockKeyManager keyManager;
    late AttachmentSyncService syncService;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_sync_');
      storage = AttachmentLocalStorage(customBaseDirectory: tempDir);
      apiClient = MockSyncApiClient();
      cloudinaryClient = MockCloudinaryClient();
      authService = MockAuthService();
      keyManager = MockKeyManager(masterKey: Uint8List(32));

      syncService = AttachmentSyncService(
        database: database,
        storage: storage,
        apiClient: apiClient,
        cloudinaryClient: cloudinaryClient,
        authService: authService,
        keyManager: keyManager,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Uploads pending encrypted attachment directly to Cloudinary and confirms with backend', () async {
      const attachmentId = '99999999-9999-9999-9999-999999999999';
      final encryptedBytes = Uint8List.fromList([0x51, 0x50, 0x41, 0x31, 1, 2, 3, 4]);

      // Save encrypted file locally
      final localPath = await storage.saveEncryptedBytes(
        attachmentId: attachmentId,
        encryptedBytes: encryptedBytes,
      );

      // Create database record with upload_pending
      await database.saveAttachment(
        id: attachmentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'image/png',
        byteSize: 100,
        isDirty: true,
        uploadState: AttachmentUploadState.uploadPending.identifier,
        localPath: localPath,
      );

      // Run sync loop
      final result = await syncService.syncPendingAttachments();
      expect(result.uploadedCount, 1);
      expect(result.failedCount, 0);
      expect(result.hasErrors, isFalse);

      // Verify Cloudinary client received direct upload
      expect(cloudinaryClient.lastUploadedBytes, equals(encryptedBytes));
      expect(cloudinaryClient.lastAuth?.publicId, contains(attachmentId));

      // Verify backend confirmation was sent
      expect(apiClient.lastConfirmedData?['attachmentId'], attachmentId);
      expect(apiClient.lastConfirmedData?['cloudPublicId'], contains(attachmentId));

      // Verify DB record updated to synced
      final record = await database.getAttachment(attachmentId);
      expect(record!.uploadState, 'synced');
      expect(record.isDirty, isFalse);
      expect(record.cloudUrl, contains('res.cloudinary.com'));
    });

    test('Captures Cloudinary upload error and returns failure summary', () async {
      const attachmentId = '88888888-8888-8888-8888-888888888888';
      final encryptedBytes = Uint8List.fromList([0x51, 0x50, 0x41, 0x31, 7, 7, 7]);

      final localPath = await storage.saveEncryptedBytes(
        attachmentId: attachmentId,
        encryptedBytes: encryptedBytes,
      );

      await database.saveAttachment(
        id: attachmentId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'image/jpeg',
        byteSize: 50,
        isDirty: true,
        uploadState: AttachmentUploadState.uploadPending.identifier,
        localPath: localPath,
      );

      // Throw error on upload
      cloudinaryClient.throwOnUpload = true;

      final result = await syncService.syncPendingAttachments();
      expect(result.failedCount, 1);
      expect(result.uploadedCount, 0);
      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('Cloudinary upload rejected'));

      // Check DB record marked as failed
      final record = await database.getAttachment(attachmentId);
      expect(record!.uploadState, 'failed');
      expect(record.isDirty, isTrue);
    });

    test('On new device: resolveAsset queries backend metadata, downloads from Cloudinary, and decrypts', () async {
      const assetId = '77777777-7777-7777-7777-777777777777';
      final rawImageBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
      final sha256 = AttachmentCrypto.computeSha256(rawImageBytes);
      final masterKey = keyManager.getMasterKey();

      final crypto = AttachmentCrypto();
      final encryptedBytes = await crypto.encryptAttachment(
        plaintextBytes: rawImageBytes,
        masterKeyBytes: masterKey,
        attachmentId: assetId,
        variant: 'original',
        keyVersion: 1,
      );

      // Populate backend metadata & mock Cloudinary response
      apiClient.serverAttachments[assetId] = AttachmentSyncPayload(
        id: assetId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'image/png',
        byteSize: rawImageBytes.length,
        sha256: sha256,
        cloudPublicId: 'user_123_$assetId',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v1/user_123_$assetId',
      );

      cloudinaryClient.downloadBytesResponse = encryptedBytes;

      final attachmentService = AttachmentService(
        database: database,
        keyManager: keyManager,
        crypto: crypto,
        storage: storage,
        cloudinaryClient: cloudinaryClient,
        apiClient: apiClient,
      );

      // Local DB initially has NO attachment record
      final preCheck = await database.getAttachment(assetId);
      expect(preCheck, isNull);

      // Resolve asset
      final resolution = await attachmentService.resolveAsset(assetId);

      expect(resolution.isAvailable, isTrue);
      expect(resolution.data, equals(rawImageBytes));

      // Local DB should now have the synced attachment record
      final postCheck = await database.getAttachment(assetId);
      expect(postCheck, isNotNull);
      expect(postCheck!.cloudUrl, isNotEmpty);
      expect(postCheck.uploadState, 'synced');
    });
  });
}
