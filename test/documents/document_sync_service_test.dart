import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_models.dart';
import 'package:quitepaper/core/attachments/cloudinary_client.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/documents/document_sync_service.dart';
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

class MockSyncApiClient extends SyncApiClient {
  String _baseUrl = 'https://test.api';
  @override
  String get baseUrl => _baseUrl;
  @override
  void setBaseUrl(String url) => _baseUrl = url;

  CloudinaryUploadAuth? lastRequestedAuth;
  Map<String, dynamic>? lastConfirmedData;

  @override
  Future<CloudinaryUploadAuth> getDocumentUploadAuth({
    required String documentId,
    String? noteId,
    String title = 'Scanned Document',
    String source = 'scanner',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  }) async {
    lastRequestedAuth = CloudinaryUploadAuth(
      uploadUrl: 'https://api.cloudinary.com/v1_1/test-cloud/raw/upload',
      cloudName: 'test-cloud',
      apiKey: 'test-key',
      signature: 'test-signature-doc',
      timestamp: 1700000000,
      publicId: 'user_123_doc_$documentId',
      folder: 'quitepaper_test',
    );
    return lastRequestedAuth!;
  }

  @override
  Future<Map<String, dynamic>> confirmDocumentUpload({
    required String documentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    String title = 'Scanned Document',
    String source = 'scanner',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
    String? ocrState,
    String? ocrLanguage,
  }) async {
    lastConfirmedData = {
      'documentId': documentId,
      'cloudPublicId': cloudPublicId,
      'cloudUrl': cloudUrl,
      'title': title,
      'source': source,
      'mimeType': mimeType,
      'pageCount': pageCount,
    };
    return {'success': true};
  }

  final Map<String, DocumentSyncPayload> serverDocuments = {};

  @override
  Future<DocumentSyncPayload?> getDocumentMetadata(String documentId) async {
    return serverDocuments[documentId];
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
      throw const CloudinaryException('Cloudinary direct document upload rejected', statusCode: 401);
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
  bool get hasKeyData => true;
  @override
  Uint8List getMasterKey() => masterKey;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentSyncService Direct Cloudinary Upload Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late DocumentLocalStorage storage;
    late MockSyncApiClient apiClient;
    late MockCloudinaryClient cloudinaryClient;
    late MockAuthService authService;
    late MockKeyManager keyManager;
    late DocumentSyncService syncService;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_doc_sync_');
      storage = DocumentLocalStorage(
        customDocumentsDirectory: tempDir,
        customTempDirectory: tempDir,
      );
      apiClient = MockSyncApiClient();
      cloudinaryClient = MockCloudinaryClient();
      authService = MockAuthService();
      keyManager = MockKeyManager(masterKey: Uint8List(32));

      syncService = DocumentSyncService(
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

    test('Uploads pending encrypted PDF document directly to Cloudinary and confirms with backend', () async {
      const documentId = '99999999-9999-9999-9999-999999999999';
      final encryptedBytes = Uint8List.fromList([0x51, 0x50, 0x44, 0x31, 1, 2, 3, 4]);

      // Save encrypted file locally
      final localPath = await storage.saveEncryptedBytes(
        documentId: documentId,
        encryptedBytes: encryptedBytes,
      );

      // Create database record with upload_pending
      await database.saveDocument(
        id: documentId,
        title: 'Important Contract',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'application/pdf',
        byteSize: 100,
        pageCount: 2,
        isDirty: true,
        uploadState: DocumentUploadState.uploadPending.identifier,
        localPath: localPath,
      );

      // Run sync loop
      final result = await syncService.syncPendingDocuments();
      expect(result.uploadedCount, 1);
      expect(result.failedCount, 0);
      expect(result.hasErrors, isFalse);

      // Verify Cloudinary client received direct upload
      expect(cloudinaryClient.lastUploadedBytes, equals(encryptedBytes));
      expect(cloudinaryClient.lastAuth?.publicId, contains(documentId));

      // Verify backend confirmation was sent
      expect(apiClient.lastConfirmedData?['documentId'], documentId);
      expect(apiClient.lastConfirmedData?['cloudPublicId'], contains(documentId));
      expect(apiClient.lastConfirmedData?['pageCount'], 2);

      // Verify DB record updated to synced
      final record = await database.getDocument(documentId);
      expect(record!.uploadState, 'synced');
      expect(record.isDirty, isFalse);
      expect(record.cloudUrl, contains('res.cloudinary.com'));
    });

    test('On new device: resolveDocument queries backend metadata, downloads from Cloudinary, and decrypts', () async {
      const documentId = '77777777-7777-7777-7777-777777777777';
      final rawPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 1, 2, 3]);
      final sha256 = DocumentCrypto.computeSha256(rawPdfBytes);
      final masterKey = keyManager.getMasterKey();

      final crypto = DocumentCrypto();
      final encryptedBytes = await crypto.encryptDocument(
        plaintextBytes: rawPdfBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
        keyVersion: 1,
      );

      // Populate backend metadata & mock Cloudinary response
      apiClient.serverDocuments[documentId] = DocumentSyncPayload(
        id: documentId,
        title: 'Tax Document',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'application/pdf',
        byteSize: rawPdfBytes.length,
        pageCount: 3,
        sha256: sha256,
        cloudPublicId: 'user_123_doc_$documentId',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v1/user_123_doc_$documentId',
      );

      cloudinaryClient.downloadBytesResponse = encryptedBytes;

      final documentService = DocumentService(
        database: database,
        keyManager: keyManager,
        crypto: crypto,
        storage: storage,
        cloudinaryClient: cloudinaryClient,
        apiClient: apiClient,
      );

      // Local DB initially has NO document record
      final preCheck = await database.getDocument(documentId);
      expect(preCheck, isNull);

      // Resolve document
      final resolution = await documentService.resolveDocument(documentId);

      expect(resolution.isAvailable, isTrue);
      expect(resolution.data!.pdfBytes, equals(rawPdfBytes));
      expect(resolution.data!.pageCount, 3);

      // Local DB should now have the synced document record
      final postCheck = await database.getDocument(documentId);
      expect(postCheck, isNotNull);
      expect(postCheck!.cloudUrl, isNotEmpty);
      expect(postCheck.uploadState, 'synced');
    });

    test('Uploads pending web snapshot document with source web_snapshot and mimeType text/html', () async {
      const documentId = '88888888-8888-8888-8888-888888888888';
      final encryptedBytes = Uint8List.fromList([0x51, 0x50, 0x44, 0x31, 5, 6, 7, 8]);

      final localPath = await storage.saveEncryptedBytes(
        documentId: documentId,
        encryptedBytes: encryptedBytes,
      );

      await database.saveDocument(
        id: documentId,
        title: 'Article (Web Snapshot)',
        source: DocumentSource.webSnapshot.identifier,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'text/html',
        byteSize: 500,
        pageCount: 1,
        isDirty: true,
        uploadState: DocumentUploadState.uploadPending.identifier,
        localPath: localPath,
      );

      final result = await syncService.syncPendingDocuments();
      expect(result.uploadedCount, 1);
      expect(result.failedCount, 0);

      // Verify backend confirmation received web_snapshot source and text/html MIME type
      expect(apiClient.lastConfirmedData?['documentId'], documentId);
      expect(apiClient.lastConfirmedData?['source'], DocumentSource.webSnapshot.identifier);
      expect(apiClient.lastConfirmedData?['mimeType'], 'text/html');

      final record = await database.getDocument(documentId);
      expect(record!.uploadState, 'synced');
      expect(record.source, 'web_snapshot');
      expect(record.mimeType, 'text/html');
    });

    test('On new device: resolves web snapshot, preserves web_snapshot source, and self-heals legacy mislabeled HTML records', () async {
      const documentId = '66666666-6666-6666-6666-666666666666';
      final rawHtmlBytes = Uint8List.fromList('<!DOCTYPE html><html><head><title>Test</title></head><body><h1>Article</h1></body></html>'.codeUnits);
      final sha256 = DocumentCrypto.computeSha256(rawHtmlBytes);
      final masterKey = keyManager.getMasterKey();

      final crypto = DocumentCrypto();
      final encryptedBytes = await crypto.encryptDocument(
        plaintextBytes: rawHtmlBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
        keyVersion: 1,
      );

      // Legacy server document metadata had source: scanner and mimeType: application/pdf
      apiClient.serverDocuments[documentId] = DocumentSyncPayload(
        id: documentId,
        title: 'Old Web Snapshot',
        source: DocumentSource.scanner, // legacy mislabeled source
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'application/pdf', // legacy mislabeled mime
        byteSize: rawHtmlBytes.length,
        pageCount: 1,
        sha256: sha256,
        cloudPublicId: 'user_123_doc_$documentId',
        cloudUrl: 'https://res.cloudinary.com/test-cloud/raw/upload/v1/user_123_doc_$documentId',
      );

      cloudinaryClient.downloadBytesResponse = encryptedBytes;

      final documentService = DocumentService(
        database: database,
        keyManager: keyManager,
        crypto: crypto,
        storage: storage,
        cloudinaryClient: cloudinaryClient,
        apiClient: apiClient,
      );

      final resolution = await documentService.resolveDocument(documentId);

      expect(resolution.isAvailable, isTrue);
      expect(resolution.data!.pdfBytes, equals(rawHtmlBytes));
      // Self-healed to web_snapshot
      expect(resolution.data!.source, DocumentSource.webSnapshot.identifier);

      // Local DB record should have been self-healed
      final localRecord = await database.getDocument(documentId);
      expect(localRecord!.source, DocumentSource.webSnapshot.identifier);
      expect(localRecord.mimeType, 'text/html');
    });
  });
}
