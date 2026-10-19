import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/sync/conflict/conflict_model.dart';
import 'package:quitepaper/core/sync/conflict/conflict_resolver.dart';
import 'package:quitepaper/core/sync/conflict/merge_result.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

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
  Future<WrappedMasterKeyData?> getStoredWrappedKeyData() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthService implements AuthService {
  MockAuthService({this.testUser});
  final AuthUser? testUser;

  @override
  AuthUser? get currentUser => testUser;

  @override
  Stream<AuthUser?> get authStateChanges =>
      Stream.value(testUser).asBroadcastStream();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOcrSyncApiClient extends SyncApiClient {
  List<OcrPageSyncPayload> lastPushedPages = [];
  PushOcrSyncResponse? nextPushResponse;
  PullOcrSyncResponse? nextPullResponse;

  @override
  Future<PushOcrSyncResponse> pushOcrPages(
    List<OcrPageSyncPayload> pages, {
    String? deviceId,
    String? idempotencyKey,
  }) async {
    lastPushedPages = List.from(pages);
    if (nextPushResponse != null) {
      return nextPushResponse!;
    }
    final results = pages
        .map((p) => PushResultItem(
              id: '${p.resourceType}:${p.resourceId}:${p.pageNumber}',
              revision: (p.baseRevision ?? 0) + 1,
              status: 'applied',
              updatedAt: DateTime.now(),
            ))
        .toList();
    return PushOcrSyncResponse(
      results: results,
      conflicts: [],
      cursor: 1,
    );
  }

  @override
  Future<PullOcrSyncResponse> pullOcrPages({
    required int cursor,
    int limit = 50,
  }) async {
    if (nextPullResponse != null) {
      return nextPullResponse!;
    }
    return const PullOcrSyncResponse(
      changes: [],
      cursor: 0,
      hasMore: false,
    );
  }

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async =>
      const PushSyncResponse(results: [], conflicts: [], cursor: 0);

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 50,
  }) async =>
      const PullSyncResponse(changes: [], cursor: 0, hasMore: false);

  @override
  Future<WrappedMasterKeyData?> getKeys() async => null;

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async =>
      keyData;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockKeyManager keyManager;
  late MockAuthService authService;
  late MockOcrSyncApiClient apiClient;
  late ConflictResolver resolver;
  late SyncEngine syncEngine;
  late Uint8List masterKey;
  late OcrCrypto ocrCrypto;

  setUp(() {
    db = AppDatabase.memory();
    masterKey = Uint8List.fromList(List.generate(32, (i) => i));
    keyManager = MockKeyManager(masterKey: masterKey);
    authService = MockAuthService(
      testUser: const AuthUser(
        id: 'user-1',
        email: 'user@test.local',
        idToken: 'token-123',
      ),
    );
    apiClient = MockOcrSyncApiClient();
    ocrCrypto = OcrCrypto();
    resolver = ConflictResolver(
      database: db,
      keyManager: keyManager,
      ocrCrypto: ocrCrypto,
    );
    syncEngine = SyncEngine(
      database: db,
      cryptoService: DefaultCryptoService(),
      keyManager: keyManager,
      authService: authService,
      apiClient: apiClient,
      conflictResolver: resolver,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  group('OCR Synchronization Tests', () {
    test('Pushes dirty document and attachment OCR pages and marks them synced', () async {
      const docId = 'doc-uuid-1';
      const attId = 'att-uuid-1';

      // 1. Create encrypted payload for document page
      final docOcr = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Line 1: Document text',
            width: 100,
            height: 100,
          ),
        ],
      );
      final docEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: docOcr,
        masterKeyBytes: masterKey,
      );

      // 2. Create encrypted payload for attachment page
      final attOcr = OcrDocument(
        documentId: attId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Line 1: Attachment text',
            width: 200,
            height: 200,
          ),
        ],
      );
      final attEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: attOcr,
        masterKeyBytes: masterKey,
      );

      // Save as dirty rows in local database
      await db.saveDocumentOcrPage(
        documentId: docId,
        pageNumber: 1,
        encryptedPayload: base64Encode(docEnc),
        processedAt: DateTime.now(),
        isDirty: true,
      );

      await db.saveAttachmentOcrPage(
        attachmentId: attId,
        pageNumber: 1,
        encryptedPayload: base64Encode(attEnc),
        processedAt: DateTime.now(),
        isDirty: true,
      );

      // Run syncNow
      await syncEngine.syncNow();

      // Verify that both pages were pushed
      expect(apiClient.lastPushedPages.length, equals(2));
      final pushedDoc = apiClient.lastPushedPages
          .firstWhere((p) => p.resourceType == 'document');
      final pushedAtt = apiClient.lastPushedPages
          .firstWhere((p) => p.resourceType == 'attachment');

      expect(pushedDoc.resourceId, equals(docId));
      expect(pushedAtt.resourceId, equals(attId));

      // Verify that local rows were marked synced (isDirty = false, revision updated)
      final localDoc = await db.getDocumentOcrPage(docId, 1);
      final localAtt = await db.getAttachmentOcrPage(attId, 1);

      expect(localDoc!.isDirty, isFalse);
      expect(localDoc.revision, equals(1));

      expect(localAtt!.isDirty, isFalse);
      expect(localAtt.revision, equals(1));
    });

    test('Push OCR conflict with non-overlapping lines automatically 3-way merges', () async {
      const docId = 'doc-uuid-merge';

      // Local version
      final localDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Line 1: Common\nLine 2: Local change',
            width: 100,
            height: 100,
          ),
        ],
      );
      final localEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: localDoc,
        masterKeyBytes: masterKey,
      );
      await db.saveDocumentOcrPage(
        documentId: docId,
        pageNumber: 1,
        encryptedPayload: base64Encode(localEnc),
        processedAt: DateTime.now(),
        revision: 1,
        baseRevision: 1,
        isDirty: true,
      );

      // Remote server head with non-overlapping change on Line 3
      final remoteDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Line 1: Common\nLine 3: Remote addition',
            width: 100,
            height: 100,
          ),
        ],
      );
      final remoteEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: remoteDoc,
        masterKeyBytes: masterKey,
      );

      apiClient.nextPushResponse = PushOcrSyncResponse(
        results: [],
        conflicts: [
          OcrConflictItem(
            id: 'document:$docId:1',
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            serverRevision: 2,
            baseRevision: 1,
            code: 'SYNC_CONFLICT',
            message: 'Conflict detected',
            serverHead: OcrConflictServerHead(
              revision: 2,
              contentCiphertext: base64Encode(remoteEnc),
              updatedAt: DateTime.now(),
            ),
          ),
        ],
        cursor: 2,
      );

      await syncEngine.syncNow();

      // Check that it was auto-merged and marked dirty for immediate push
      final mergedRow = await db.getDocumentOcrPage(docId, 1);
      expect(mergedRow, isNotNull);
      expect(mergedRow!.isDirty, isTrue);
      expect(mergedRow.baseRevision, equals(2));

      // Decrypt and verify content contains both local and remote additions
      final dec = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: base64Decode(mergedRow.encryptedPayload),
        masterKeyBytes: masterKey,
        documentId: docId,
      );
      expect(dec.pages.first.plainText, contains('Line 2: Local change'));
      expect(dec.pages.first.plainText, contains('Line 3: Remote addition'));

      // Verify no conflict record was created since it auto-merged
      final conflicts = await db.getPendingConflicts();
      expect(conflicts, isEmpty);
    });

    test('Push OCR conflict with clashing line creates SyncConflict', () async {
      const docId = 'doc-uuid-conflict';

      // Local change on line 1
      final localDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Invoice total: \$500.00',
            width: 100,
            height: 100,
          ),
        ],
      );
      final localEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: localDoc,
        masterKeyBytes: masterKey,
      );
      await db.saveDocumentOcrPage(
        documentId: docId,
        pageNumber: 1,
        encryptedPayload: base64Encode(localEnc),
        processedAt: DateTime.now(),
        revision: 1,
        baseRevision: 1,
        isDirty: true,
      );

      // Remote conflicting change on line 1
      final remoteDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Invoice total: \$750.00',
            width: 100,
            height: 100,
          ),
        ],
      );
      final remoteEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: remoteDoc,
        masterKeyBytes: masterKey,
      );

      apiClient.nextPushResponse = PushOcrSyncResponse(
        results: [],
        conflicts: [
          OcrConflictItem(
            id: 'document:$docId:1',
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            serverRevision: 3,
            baseRevision: 1,
            code: 'SYNC_CONFLICT',
            message: 'Conflict detected',
            serverHead: OcrConflictServerHead(
              revision: 3,
              contentCiphertext: base64Encode(remoteEnc),
              updatedAt: DateTime.now(),
            ),
          ),
        ],
        cursor: 3,
      );

      await syncEngine.syncNow();

      // Verify a SyncConflict record was created
      final conflicts = await db.getPendingConflicts();
      expect(conflicts.length, equals(1));
      final syncConflict = SyncConflict.fromEntity(conflicts.first);

      expect(syncConflict.isOcrConflict, isTrue);
      expect(syncConflict.extraData?['resourceType'], equals('document'));
      expect(syncConflict.extraData?['resourceId'], equals(docId));
      expect(syncConflict.extraData?['pageNumber'], equals(1));
      expect(syncConflict.conflictRegions.isNotEmpty, isTrue);

      // Verify local row was marked isDirty = false temporarily so it does not loop
      final localRow = await db.getDocumentOcrPage(docId, 1);
      expect(localRow!.isDirty, isFalse);
    });

    test('Pull remote OCR page applies cleanly when local page is not dirty', () async {
      const docId = 'doc-uuid-pull';

      final remoteDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Pulled remote OCR text from other device',
            width: 500,
            height: 700,
          ),
        ],
      );
      final remoteEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: remoteDoc,
        masterKeyBytes: masterKey,
      );

      apiClient.nextPullResponse = PullOcrSyncResponse(
        changes: [
          PullOcrPageChangeItem(
            resourceType: 'document',
            resourceId: docId,
            pageNumber: 1,
            revision: 5,
            contentCiphertext: base64Encode(remoteEnc),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        cursor: 5,
        hasMore: false,
      );

      await syncEngine.syncNow();

      final pulledRow = await db.getDocumentOcrPage(docId, 1);
      expect(pulledRow, isNotNull);
      expect(pulledRow!.revision, equals(5));
      expect(pulledRow.baseRevision, equals(5));
      expect(pulledRow.isDirty, isFalse);

      final dec = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: base64Decode(pulledRow.encryptedPayload),
        masterKeyBytes: masterKey,
        documentId: docId,
      );
      expect(dec.pages.first.plainText, equals('Pulled remote OCR text from other device'));
    });
  });

  group('ConflictResolver OCR Methods Tests', () {
    test('resolveOcrKeepMine keeps local OCR text and marks dirty for push', () async {
      const docId = 'doc-res-1';

      final localDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Local preserved OCR text',
            width: 100,
            height: 100,
          ),
        ],
      );
      final localEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: localDoc,
        masterKeyBytes: masterKey,
      );
      await db.saveDocumentOcrPage(
        documentId: docId,
        pageNumber: 1,
        encryptedPayload: base64Encode(localEnc),
        processedAt: DateTime.now(),
        revision: 1,
        baseRevision: 1,
        isDirty: false,
      );

      // Create fallback note so foreign key succeeds
      await db.saveNote(
        id: 'note-res-1',
        title: 'Note',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final conflict = SyncConflict(
        id: 'conf-ocr-1',
        noteId: 'note-res-1',
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 4,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        extraData: {
          'isOcr': true,
          'resourceType': 'document',
          'resourceId': docId,
          'pageNumber': 1,
        },
      );
      await db.saveConflict(
        id: conflict.id,
        noteId: conflict.noteId,
        baseRevision: conflict.baseRevision,
        localRevision: conflict.localRevision,
        remoteRevision: conflict.remoteRevision,
        conflictType: conflict.conflictType.name,
        state: conflict.state.name,
        createdAt: conflict.createdAt,
        dataJson: conflict.toDataJson(),
      );

      await resolver.resolveKeepMine(conflict);

      final updatedRow = await db.getDocumentOcrPage(docId, 1);
      expect(updatedRow!.isDirty, isTrue);
      expect(updatedRow.baseRevision, equals(4));

      final pending = await db.getPendingConflicts();
      expect(pending, isEmpty);
    });

    test('resolveOcrKeepTheirs applies remote OCR payload', () async {
      const docId = 'doc-res-2';

      final remoteDoc = OcrDocument(
        documentId: docId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Remote chosen OCR text',
            width: 100,
            height: 100,
          ),
        ],
      );
      final remoteEnc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: remoteDoc,
        masterKeyBytes: masterKey,
      );

      await db.saveNote(
        id: 'note-res-2',
        title: 'Note',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final conflict = SyncConflict(
        id: 'conf-ocr-2',
        noteId: 'note-res-2',
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 6,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        extraData: {
          'isOcr': true,
          'resourceType': 'document',
          'resourceId': docId,
          'pageNumber': 1,
          'remoteEncryptedPayload': base64Encode(remoteEnc),
        },
      );
      await db.saveConflict(
        id: conflict.id,
        noteId: conflict.noteId,
        baseRevision: conflict.baseRevision,
        localRevision: conflict.localRevision,
        remoteRevision: conflict.remoteRevision,
        conflictType: conflict.conflictType.name,
        state: conflict.state.name,
        createdAt: conflict.createdAt,
        dataJson: conflict.toDataJson(),
      );

      await resolver.resolveKeepTheirs(conflict);

      final updatedRow = await db.getDocumentOcrPage(docId, 1);
      expect(updatedRow!.isDirty, isFalse);
      expect(updatedRow.revision, equals(6));

      final dec = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: base64Decode(updatedRow.encryptedPayload),
        masterKeyBytes: masterKey,
        documentId: docId,
      );
      expect(dec.pages.first.plainText, equals('Remote chosen OCR text'));

      final pending = await db.getPendingConflicts();
      expect(pending, isEmpty);
    });

    test('resolveWithCustomMerge saves manually edited OCR text encrypted', () async {
      const attId = 'att-res-3';

      await db.saveNote(
        id: 'note-res-3',
        title: 'Note',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final conflict = SyncConflict(
        id: 'conf-ocr-3',
        noteId: 'note-res-3',
        baseRevision: 1,
        localRevision: 1,
        remoteRevision: 7,
        conflictType: ConflictType.content,
        state: ConflictState.manualRequired,
        createdAt: DateTime.now(),
        extraData: {
          'isOcr': true,
          'resourceType': 'attachment',
          'resourceId': attId,
          'pageNumber': 1,
        },
      );
      await db.saveConflict(
        id: conflict.id,
        noteId: conflict.noteId,
        baseRevision: conflict.baseRevision,
        localRevision: conflict.localRevision,
        remoteRevision: conflict.remoteRevision,
        conflictType: conflict.conflictType.name,
        state: conflict.state.name,
        createdAt: conflict.createdAt,
        dataJson: conflict.toDataJson(),
      );

      await resolver.resolveWithCustomMerge(
        conflict: conflict,
        resolvedTitle: 'Ignored for OCR',
        resolvedContent: 'Manually unified OCR transcription text',
        resolvedTags: [],
      );

      final updatedRow = await db.getAttachmentOcrPage(attId, 1);
      expect(updatedRow!.isDirty, isTrue);
      expect(updatedRow.baseRevision, equals(7));

      final dec = await ocrCrypto.decryptOcrDocument(
        encryptedEnvelopeBytes: base64Decode(updatedRow.encryptedPayload),
        masterKeyBytes: masterKey,
        documentId: attId,
      );
      expect(dec.pages.first.plainText, equals('Manually unified OCR transcription text'));

      final pending = await db.getPendingConflicts();
      expect(pending, isEmpty);
    });
  });
}
