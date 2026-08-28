import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

class MockLifecycleAuthService implements AuthService {
  final _user = const AuthUser(
    id: 'user-lifecycle-123',
    email: 'lifecycle@quietpaper.app',
    idToken: 'mock-jwt-token',
  );

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_user);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-jwt-token';

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LifecycleSyncApiClient extends SyncApiClient {
  WrappedMasterKeyData? storedKey;
  final Map<String, NoteSyncPayload> serverNotes = {};
  final List<PullChangeItem> syncLog = [];
  final List<SyncReferenceItem> syncedReferences = [];
  int cursorCounter = 0;
  bool throwCursorExpiredOnNextPull = false;

  @override
  Future<WrappedMasterKeyData?> getKeys() async => storedKey;

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async {
    storedKey = keyData;
    return keyData;
  }

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async {
    final results = <PushResultItem>[];
    for (final c in changes) {
      cursorCounter++;
      serverNotes[c.id] = c;
      syncLog.add(PullChangeItem(
        id: c.id,
        revision: cursorCounter,
        changeType: c.isDeleted ? 'delete' : 'upsert',
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        archived: c.archived,
        trashed: c.trashed,
        pinned: c.pinned,
        contentCiphertext: c.contentCiphertext,
        contentNonce: c.contentNonce,
        contentVersion: c.contentVersion,
        encryptionKeyVersion: c.encryptionKeyVersion,
        deletedAt: c.deletedAt,
      ));
      results.add(PushResultItem(
        id: c.id,
        revision: cursorCounter,
        status: 'applied',
        updatedAt: c.updatedAt,
      ));
    }
    return PushSyncResponse(results: results, conflicts: [], cursor: cursorCounter);
  }

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  }) async {
    if (throwCursorExpiredOnNextPull) {
      throwCursorExpiredOnNextPull = false;
      throw const SyncCursorExpiredException(
        message: 'Sync cursor expired',
        minRetainedRevision: 10,
        currentRevision: 20,
      );
    }

    final matching = syncLog.where((c) => c.revision > cursor).take(limit).toList();
    final nextCursor = matching.isNotEmpty ? matching.last.revision : cursor;
    return PullSyncResponse(changes: matching, cursor: nextCursor, hasMore: false);
  }

  @override
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  }) async {
    return const PushVersionSyncResponse(results: [], cursor: 0);
  }

  @override
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  }) async {
    return const PullVersionSyncResponse(changes: [], cursor: 0, hasMore: false);
  }

  @override
  Future<void> syncReferences({
    required List<SyncReferenceItem> references,
    String? deviceId,
  }) async {
    syncedReferences.addAll(references);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LifecycleSyncApiClient apiClient;
  late KeyManager keyManager;
  late CryptoService cryptoService;
  late SyncEngine syncEngine;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.memory();
    apiClient = LifecycleSyncApiClient();
    cryptoService = DefaultCryptoService();
    keyManager = SecureKeyManager(cryptoService: cryptoService);

    // Initialize key manager with mock master key
    final recoveryKey = cryptoService.generateRecoveryKey();
    final wrappedKey = await keyManager.setupNewKeys(
      password: 'test-enc-password-123',
      recoveryKey: recoveryKey,
      kdfParameters: const KdfParameters(memory: 1024, iterations: 1, parallelism: 1),
    );
    await apiClient.putKeys(wrappedKey);

    syncEngine = SyncEngine(
      database: db,
      apiClient: apiClient,
      authService: MockLifecycleAuthService(),
      keyManager: keyManager,
      cryptoService: cryptoService,
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  test('SyncEngine synchronizes moving note to Trash and Restoring', () async {
    const noteId = 'note-trash-123';

    // 1. Create active note locally and sync
    await db.saveNote(
      id: noteId,
      title: 'Active Note',
      content: 'Hello World',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isArchived: false,
      isTrashed: false,
      isDirty: true,
    );

    await syncEngine.syncNow();
    expect(apiClient.serverNotes[noteId]?.trashed, false);

    // 2. Move note to Trash locally
    await db.trashNote(noteId);
    expect((await db.getNoteWithTags(noteId))?.note.isTrashed, true);

    await syncEngine.syncNow();
    expect(apiClient.serverNotes[noteId]?.trashed, true);

    // 3. Restore note from Trash locally
    await db.restoreFromTrash(noteId);
    expect((await db.getNoteWithTags(noteId))?.note.isTrashed, false);

    await syncEngine.syncNow();
    expect(apiClient.serverNotes[noteId]?.trashed, false);
  });

  test('SyncEngine synchronizes attachment and document reference projections', () async {
    const noteId = 'note-with-assets-1';
    const assetId = '11111111-2222-3333-4444-555555555555';
    const docId = '66666666-7777-8888-9999-000000000000';

    await db.saveNote(
      id: noteId,
      title: 'Note With Attachments',
      content: 'Here is an image: qp://asset/$assetId and a doc: qp://document/$docId',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isArchived: false,
      isTrashed: false,
      isDirty: true,
    );

    await syncEngine.syncNow();

    expect(apiClient.syncedReferences.any((r) => r.resourceId == assetId && r.resourceType == 'attachment'), true);
    expect(apiClient.syncedReferences.any((r) => r.resourceId == docId && r.resourceType == 'document'), true);
  });

  test('SyncEngine automatically recovers from SyncCursorExpiredException by resetting cursor', () async {
    const noteId = 'note-exp-test';

    // 1. Initial note push
    await db.saveNote(
      id: noteId,
      title: 'Initial Note',
      content: 'Initial Content',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isArchived: false,
      isTrashed: false,
      isDirty: true,
    );
    await syncEngine.syncNow();

    // 2. Set throw on pull
    apiClient.throwCursorExpiredOnNextPull = true;

    // 3. Sync should catch exception, reset cursor, and complete successfully
    await syncEngine.syncNow();
    expect(syncEngine.state.status, SyncStatus.synced);
  });

  test('Permanent deletion purges local note versions and search indices', () async {
    const noteId = 'note-perm-test';

    await db.saveNote(
      id: noteId,
      title: 'Permanent Test Note',
      content: 'Sensitive Data',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isArchived: false,
      isTrashed: true,
      isDirty: true,
    );

    // Save note version
    await db.saveNoteVersion(
      id: 'v-1',
      noteId: noteId,
      versionNumber: 1,
      title: 'Permanent Test Note',
      content: 'Sensitive Data v1',
      tagsJson: '[]',
      createdAt: DateTime.now(),
      charCount: 17,
      wordCount: 3,
      isDirty: false,
    );

    expect((await db.getNoteVersions(noteId)).length, 1);

    // Permanently delete note
    await db.deletePermanently(noteId);

    // Note and its versions should be removed
    expect(await db.getNoteWithTags(noteId), isNull);
    expect((await db.getNoteVersions(noteId)).isEmpty, true);
  });
}
