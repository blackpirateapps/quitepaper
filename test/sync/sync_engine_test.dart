import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quitepaper/core/attachments/attachment_models.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

/// In-memory mock sync API client simulating the Vercel backend
class InMemorySyncApiClient extends SyncApiClient {
  String _baseUrl = 'https://test.api';
  @override
  String get baseUrl => _baseUrl;
  @override
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  WrappedMasterKeyData? storedKey;
  final Map<String, NoteSyncPayload> serverNotes = {};
  final List<PullChangeItem> syncLog = [];
  final List<List<NoteSyncPayload>> pushBatches = [];
  final List<String?> pushIdempotencyKeys = [];
  final List<List<NoteVersionSyncPayload>> pushVersionBatches = [];
  int cursorCounter = 0;

  @override
  Future<Map<String, dynamic>> getAccount() async {
    return {'status': 'ok'};
  }

  @override
  Future<WrappedMasterKeyData?> getKeys() async {
    return storedKey;
  }

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
    pushBatches.add(List.from(changes));
    pushIdempotencyKeys.add(idempotencyKey);
    final results = <PushResultItem>[];
    final conflicts = <ConflictItem>[];

    for (final change in changes) {
      cursorCounter++;
      final revision = cursorCounter;
      serverNotes[change.id] = change;

      final changeItem = PullChangeItem(
        id: change.id,
        revision: revision,
        changeType: change.isDeleted ? 'delete' : 'upsert',
        createdAt: change.createdAt,
        updatedAt: change.updatedAt,
        archived: change.archived,
        trashed: change.trashed,
        pinned: change.pinned,
        folderId: change.folderId,
        sortOrder: change.sortOrder,
        contentCiphertext: change.contentCiphertext,
        contentNonce: change.contentNonce,
        contentVersion: change.contentVersion,
        encryptionKeyVersion: change.encryptionKeyVersion,
        deletedAt: change.deletedAt,
      );
      syncLog.add(changeItem);

      results.add(PushResultItem(
        id: change.id,
        revision: revision,
        status: 'applied',
        updatedAt: change.updatedAt,
      ));
    }

    return PushSyncResponse(
      results: results,
      conflicts: conflicts,
      cursor: cursorCounter,
    );
  }

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  }) async {
    final matching = syncLog.where((item) => item.revision > cursor).toList();
    final toReturn = matching.take(limit).toList();
    final maxRev = toReturn.isEmpty ? cursor : toReturn.last.revision;

    return PullSyncResponse(
      changes: toReturn,
      cursor: maxRev,
      hasMore: matching.length > limit,
    );
  }

  @override
  Future<int> getCursor() async {
    return cursorCounter;
  }

  @override
  Future<CloudinaryUploadAuth> getAttachmentUploadAuth({
    required String attachmentId,
    String? noteId,
    String mimeType = 'image/png',
    int byteSize = 0,
    String sha256 = '',
    String variant = 'original',
  }) async {
    return CloudinaryUploadAuth(
      uploadUrl: 'https://api.cloudinary.com/v1_1/test/raw/upload',
      cloudName: 'test',
      apiKey: 'test-key',
      signature: 'sig',
      timestamp: 12345,
      publicId: 'user_$attachmentId',
    );
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
    return {'success': true};
  }

  final Map<String, AttachmentSyncPayload> serverAttachments = {};

  @override
  Future<AttachmentSyncPayload?> getAttachmentMetadata(String attachmentId) async {
    return serverAttachments[attachmentId];
  }

  @override
  Future<CloudinaryUploadAuth> getDocumentUploadAuth({
    required String documentId,
    String? noteId,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  }) async {
    return CloudinaryUploadAuth(
      uploadUrl: 'https://api.cloudinary.com/v1_1/test/raw/upload',
      cloudName: 'test',
      apiKey: 'test-key',
      signature: 'sig',
      timestamp: 12345,
      publicId: 'user_doc_$documentId',
    );
  }

  @override
  Future<Map<String, dynamic>> confirmDocumentUpload({
    required String documentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  }) async {
    return {'success': true};
  }

  final Map<String, DocumentSyncPayload> serverDocuments = {};

  @override
  Future<DocumentSyncPayload?> getDocumentMetadata(String documentId) async {
    return serverDocuments[documentId];
  }

  final List<PullVersionChangeItem> versionSyncLog = [];

  @override
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  }) async {
    pushVersionBatches.add(List.from(versions));
    final results = <PushResultItem>[];
    for (final v in versions) {
      cursorCounter++;
      final rev = cursorCounter;
      versionSyncLog.add(PullVersionChangeItem(
        id: v.id,
        noteId: v.noteId,
        versionNumber: v.versionNumber,
        contentCiphertext: v.contentCiphertext,
        contentNonce: v.contentNonce,
        charCount: v.charCount,
        wordCount: v.wordCount,
        deltaSummary: v.deltaSummary,
        revision: rev,
        createdAt: v.createdAt,
      ));
      results.add(PushResultItem(
        id: v.id,
        revision: rev,
        status: 'applied',
        updatedAt: DateTime.now(),
      ));
    }
    return PushVersionSyncResponse(results: results, cursor: cursorCounter);
  }

  @override
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  }) async {
    final matching = versionSyncLog.where((v) => v.revision > cursor).toList();
    final toReturn = matching.take(limit).toList();
    final maxRev = toReturn.isEmpty ? cursor : toReturn.last.revision;
    return PullVersionSyncResponse(
      changes: toReturn,
      cursor: maxRev,
      hasMore: matching.length > limit,
    );
  }

  @override
  Future<PullChangeItem?> getHistoricalRevision({
    required String noteId,
    required int revision,
  }) async {
    return syncLog.cast<PullChangeItem?>().firstWhere(
      (item) => item?.id == noteId && item?.revision == revision,
      orElse: () => null,
    );
  }

  @override
  Future<PullChangeItem?> getRemoteNote({
    required String noteId,
  }) async {
    final note = serverNotes[noteId];
    if (note == null) return null;
    return syncLog.cast<PullChangeItem?>().lastWhere(
      (item) => item?.id == noteId,
      orElse: () => null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase dbA;
  late AppDatabase dbB;
  late MockAuthService authA;
  late MockAuthService authB;
  late DefaultCryptoService crypto;
  late SecureKeyManager keyManagerA;
  late SecureKeyManager keyManagerB;
  late InMemorySyncApiClient sharedApi;
  late SyncEngine engineA;
  late SyncEngine engineB;

  const testKdf = KdfParameters(memory: 1024, iterations: 1, parallelism: 1);

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dbA = AppDatabase.memory();
    dbB = AppDatabase.memory();
    authA = MockAuthService();
    authB = MockAuthService();
    crypto = DefaultCryptoService();
    keyManagerA = SecureKeyManager(cryptoService: crypto);
    keyManagerB = SecureKeyManager(cryptoService: crypto);
    sharedApi = InMemorySyncApiClient();

    engineA = SyncEngine(
      database: dbA,
      cryptoService: crypto,
      keyManager: keyManagerA,
      authService: authA,
      apiClient: sharedApi,
    );

    engineB = SyncEngine(
      database: dbB,
      cryptoService: crypto,
      keyManager: keyManagerB,
      authService: authB,
      apiClient: sharedApi,
    );
  });

  tearDown(() async {
    engineA.dispose();
    engineB.dispose();
    await dbA.close();
    await dbB.close();
  });

  test('Multi-Device E2E Flow: Device A creates note -> Device B recovers and decrypts', () async {
    const userEmail = 'alice@quietpaper.test';
    const fbPassword = 'AccountPassword123';
    const encPassword = 'QuietPaperEncryptionPassword-!@#';

    // 1. Device A: Sign up & setup keys
    await authA.signUpWithEmailAndPassword(userEmail, fbPassword);
    final recoveryKey = crypto.generateRecoveryKey();
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: encPassword,
      recoveryKey: recoveryKey,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    // 2. Device A: Create note
    final now = DateTime.now();
    await dbA.saveNote(
      id: 'note-quantum-1',
      title: 'Secret Project',
      content: 'This is private editorial content.',
      createdAt: now,
      updatedAt: now,
      isPinned: true,
      tags: ['private', 'project'],
      isDirty: true,
    );

    // 3. Device A: Push sync
    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);

    // Assert server has ONLY encrypted ciphertext
    expect(sharedApi.serverNotes.containsKey('note-quantum-1'), true);
    final serverPayload = sharedApi.serverNotes['note-quantum-1']!;
    expect(serverPayload.contentCiphertext.isNotEmpty, true);
    expect(serverPayload.contentCiphertext.contains('Secret Project'), false);
    expect(serverPayload.contentCiphertext.contains('private editorial'), false);

    // 4. Device B: Fresh install sign in
    await authB.signInWithEmailAndPassword(userEmail, fbPassword);
    final remoteKey = await sharedApi.getKeys();
    expect(remoteKey, isNotNull);

    // Unlock key on Device B with Quiet Paper encryption password
    await keyManagerB.unlockWithPassword(
      password: encPassword,
      remoteWrappedKey: remoteKey,
    );
    expect(keyManagerB.isUnlocked, true);

    // 5. Device B: Pull sync
    await engineB.syncNow();
    expect(engineB.state.status, SyncStatus.synced);

    // 6. Verify note on Device B
    final pulledNote = await dbB.getNoteWithTags('note-quantum-1');
    expect(pulledNote, isNotNull);
    expect(pulledNote!.note.title, 'Secret Project');
    expect(pulledNote.note.content, 'This is private editorial content.');
    expect(pulledNote.note.isPinned, true);
    expect(pulledNote.tagNames, containsAll(['private', 'project']));
  });

  test('Local Search is completely offline and does not hit network', () async {
    final now = DateTime.now();
    await dbA.saveNote(
      id: 'note-search-1',
      title: 'Project Apollo',
      content: 'Secret moon landing details.',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      tags: ['apollo', 'mission'],
    );

    // Search query directly through local DB
    final searchResults = await dbA.watchNotes(searchQuery: 'Apollo').first;
    expect(searchResults.length, 1);
    expect(searchResults.first.note.title, 'Project Apollo');

    final contentResults = await dbA.watchNotes(searchQuery: 'moon landing').first;
    expect(contentResults.length, 1);
    expect(contentResults.first.note.title, 'Project Apollo');

    final tagResults = await dbA.watchNotes(searchQuery: '#mission').first;
    expect(tagResults.length, 1);
  });

  test('Password change re-wraps master key and keeps note ciphertexts untouched', () async {
    const encPassword1 = 'original-password-1';
    const encPassword2 = 'new-password-2';

    await authA.signUpWithEmailAndPassword('bob@test.local', 'password');
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: encPassword1,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    final now = DateTime.now();
    await dbA.saveNote(
      id: 'note-persist-1',
      title: 'Persistent note',
      content: 'Ciphertext will not change.',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      isDirty: true,
    );
    await engineA.syncNow();

    final initialCiphertext = sharedApi.serverNotes['note-persist-1']!.contentCiphertext;

    // Change encryption password
    final newWrappedKey = await keyManagerA.changePassword(
      newPassword: encPassword2,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(newWrappedKey);

    // Note ciphertext on server remains identical!
    expect(sharedApi.serverNotes['note-persist-1']!.contentCiphertext, equals(initialCiphertext));

    // Unlock fresh Device B with new password and verify decryption
    await authB.signInWithEmailAndPassword('bob@test.local', 'password');
    await keyManagerB.unlockWithPassword(
      password: encPassword2,
      remoteWrappedKey: newWrappedKey,
    );
    await engineB.syncNow();

    final noteOnB = await dbB.getNoteWithTags('note-persist-1');
    expect(noteOnB!.note.title, 'Persistent note');
    expect(noteOnB.note.content, 'Ciphertext will not change.');
  });

  test('Note deletion sync: pushes deletion tombstone and pulls without re-enqueuing', () async {
    const userEmail = 'dan@test.local';
    const password = 'password';

    // Device A sets up
    await authA.signUpWithEmailAndPassword(userEmail, password);
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: password,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    // Device A creates note
    final now = DateTime.now();
    await dbA.saveNote(
      id: 'note-delete-test',
      title: 'To Be Deleted',
      content: 'Goodbye',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      isDirty: true,
    );
    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);

    // Device B sets up and pulls note
    await authB.signInWithEmailAndPassword(userEmail, password);
    await keyManagerB.unlockWithPassword(
      password: password,
      remoteWrappedKey: wrappedKey,
    );
    await engineB.syncNow();
    expect(await dbB.getNoteWithTags('note-delete-test'), isNotNull);

    // Device A permanently deletes note
    await dbA.deletePermanently('note-delete-test');
    final pendingA = await dbA.getPendingSyncQueue();
    expect(pendingA.length, 1);
    expect(pendingA.first.operation, 'delete');

    // Device A pushes delete
    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);
    expect((await dbA.getPendingSyncQueue()).isEmpty, true);

    // Device B pulls delete
    await engineB.syncNow();
    expect(await dbB.getNoteWithTags('note-delete-test'), isNull);

    // Verify Device B did NOT re-enqueue deletion into its sync queue
    final pendingB = await dbB.getPendingSyncQueue();
    expect(pendingB.isEmpty, true);
  });

  test('Batching: pushes >100 dirty notes in batches of <= 100 with unique idempotency keys', () async {
    const userEmail = 'batch@test.local';
    const password = 'password';

    await authA.signUpWithEmailAndPassword(userEmail, password);
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: password,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    // Create 150 dirty notes
    final now = DateTime.now();
    for (var i = 1; i <= 150; i++) {
      await dbA.saveNote(
        id: 'note-batch-$i',
        title: 'Batch Note $i',
        content: 'Content of batch note $i',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        isDirty: true,
      );
    }

    final dirtyNotes = await dbA.getDirtyNotes();
    expect(dirtyNotes.length, 150);

    // Reset batches recorded so far
    sharedApi.pushBatches.clear();
    sharedApi.pushIdempotencyKeys.clear();

    // Sync
    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);

    // Verify chunked into 2 batches (100 + 50)
    expect(sharedApi.pushBatches.length, 2);
    expect(sharedApi.pushBatches[0].length, 100);
    expect(sharedApi.pushBatches[1].length, 50);

    // Verify each batch has a distinct non-empty idempotency key
    expect(sharedApi.pushIdempotencyKeys.length, 2);
    expect(sharedApi.pushIdempotencyKeys[0], isNotNull);
    expect(sharedApi.pushIdempotencyKeys[1], isNotNull);
    expect(sharedApi.pushIdempotencyKeys[0] != sharedApi.pushIdempotencyKeys[1], true);

    // Verify all 150 notes exist on server and locally marked not dirty
    expect(sharedApi.serverNotes.length, 150);
    expect((await dbA.getDirtyNotes()).isEmpty, true);
  });

  test('Batching: pushes >100 note versions in batches of <= 100', () async {
    const userEmail = 'batch-versions@test.local';
    const password = 'password';

    await authA.signUpWithEmailAndPassword(userEmail, password);
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: password,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    final now = DateTime.now();
    await dbA.saveNote(
      id: 'note-versioned-1',
      title: 'Parent Note',
      content: 'Parent Content',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      isDirty: false,
    );

    // Create 120 dirty note versions
    for (var i = 1; i <= 120; i++) {
      await dbA.saveNoteVersion(
        id: 'version-batch-$i',
        noteId: 'note-versioned-1',
        versionNumber: i,
        title: 'Version $i',
        content: 'Content $i',
        tagsJson: '[]',
        createdAt: now,
        isDirty: true,
      );
    }

    expect((await dbA.getDirtyNoteVersions()).length, 120);

    // Reset recorded version batches
    sharedApi.pushVersionBatches.clear();

    // Sync
    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);

    // Verify chunked into 2 batches (100 + 20)
    expect(sharedApi.pushVersionBatches.length, 2);
    expect(sharedApi.pushVersionBatches[0].length, 100);
    expect(sharedApi.pushVersionBatches[1].length, 20);
    expect((await dbA.getDirtyNoteVersions()).isEmpty, true);
  });

  test('HttpSyncApiClient extracts structured error messages on API failure', () async {
    final client = FakeHttpClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'Array must contain at most 100 element(s)',
          }
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final auth = MockAuthService();
    await auth.signUpWithEmailAndPassword('err@test.local', 'password');

    final apiClient = HttpSyncApiClient(
      authService: auth,
      baseUrl: 'https://test.api',
      httpClient: client,
    );

    expect(
      () => apiClient.pushChanges(changes: []),
      throwsA(predicate((e) =>
          e is Exception &&
          e.toString().contains('Push sync failed: Array must contain at most 100 element(s)'))),
    );
  });
}
