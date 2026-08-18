import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

/// In-memory mock sync API client simulating the Vercel backend
class InMemorySyncApiClient implements SyncApiClient {
  WrappedMasterKeyData? storedKey;
  final Map<String, NoteSyncPayload> serverNotes = {};
  final List<PullChangeItem> syncLog = [];
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
}
