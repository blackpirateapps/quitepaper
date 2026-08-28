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
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

class MockInMemorySyncApiClient extends SyncApiClient {
  String _baseUrl = 'https://test.api';
  @override
  String get baseUrl => _baseUrl;
  @override
  void setBaseUrl(String url) => _baseUrl = url;

  WrappedMasterKeyData? storedKey;
  final Map<String, NoteSyncPayload> serverNotes = {};
  final List<PullChangeItem> syncLog = [];
  final List<PullVersionChangeItem> versionSyncLog = [];
  int cursorCounter = 0;

  @override
  Future<Map<String, dynamic>> getAccount() async => {'status': 'ok'};

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
    for (final change in changes) {
      cursorCounter++;
      final rev = cursorCounter;
      serverNotes[change.id] = change;

      syncLog.add(PullChangeItem(
        id: change.id,
        revision: rev,
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
      ));

      results.add(PushResultItem(
        id: change.id,
        revision: rev,
        status: 'applied',
        updatedAt: change.updatedAt,
      ));
    }
    return PushSyncResponse(results: results, conflicts: [], cursor: cursorCounter);
  }

  @override
  Future<PullSyncResponse> pullChanges({required int cursor, int limit = 100}) async {
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
  Future<int> getCursor() async => cursorCounter;

  @override
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  }) async {
    final results = <PushResultItem>[];
    for (final v in versions) {
      cursorCounter++;
      versionSyncLog.add(PullVersionChangeItem(
        id: v.id,
        noteId: v.noteId,
        versionNumber: v.versionNumber,
        contentCiphertext: v.contentCiphertext,
        contentNonce: v.contentNonce,
        charCount: v.charCount,
        wordCount: v.wordCount,
        deltaSummary: v.deltaSummary,
        revision: cursorCounter,
        createdAt: v.createdAt,
      ));
      results.add(PushResultItem(
        id: v.id,
        revision: cursorCounter,
        status: 'applied',
        updatedAt: DateTime.now(),
      ));
    }
    return PushVersionSyncResponse(results: results, cursor: cursorCounter);
  }

  @override
  Future<PullVersionSyncResponse> pullVersions({required int cursor, int limit = 100}) async {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  late MockInMemorySyncApiClient sharedApi;
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
    sharedApi = MockInMemorySyncApiClient();

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

  test('Fresh Device Login: Pulled note content is durable and not reverted to empty', () async {
    const userEmail = 'user@quietpaper.test';
    const password = 'EncryptionPassword123!';

    // 1. Device A sets up keys & creates rich note
    await authA.signUpWithEmailAndPassword(userEmail, 'AccountPass123');
    final wrappedKey = await keyManagerA.setupNewKeys(
      password: password,
      kdfParameters: testKdf,
    );
    await sharedApi.putKeys(wrappedKey);

    const noteId = 'artemis-note-100';
    const noteTitle = 'Project Artemis';
    const noteBody = '## Roadmap\n1. Design architecture\n2. Implement E2EE sync';

    final now = DateTime.now();
    await dbA.saveNote(
      id: noteId,
      title: noteTitle,
      content: noteBody,
      createdAt: now,
      updatedAt: now,
      isPinned: true,
      tags: ['artemis', 'roadmap'],
      isDirty: true,
    );

    await engineA.syncNow();
    expect(engineA.state.status, SyncStatus.synced);

    // 2. Device B: Fresh login & sync
    await authB.signInWithEmailAndPassword(userEmail, 'AccountPass123');
    final remoteKey = await sharedApi.getKeys();
    expect(remoteKey, isNotNull);

    await keyManagerB.unlockWithPassword(
      password: password,
      remoteWrappedKey: remoteKey,
    );

    // Initial state on Device B is empty
    expect(await dbB.getNoteWithTags(noteId), isNull);

    // Perform sync on Device B
    await engineB.syncNow();
    expect(engineB.state.status, SyncStatus.synced);

    // 3. Verify note on Device B in SQLite
    final pulledNote = await dbB.getNoteWithTags(noteId);
    expect(pulledNote, isNotNull);
    expect(pulledNote!.note.title, noteTitle);
    expect(pulledNote.note.content, noteBody);
    expect(pulledNote.note.isDirty, false);

    // Verify preview snippet
    final domainNote = Note(
      id: pulledNote.note.id,
      title: pulledNote.note.title,
      content: pulledNote.note.content,
      createdAt: pulledNote.note.createdAt,
      updatedAt: pulledNote.note.updatedAt,
      tags: pulledNote.tagNames,
    );
    expect(domainNote.hasCustomTitle, isTrue);
    expect(domainNote.previewSnippet, isNotEmpty);
    expect(domainNote.previewSnippet, contains('Roadmap'));

    // 4. Instantiate EditorNotifier and ensure saveNow() does not overwrite content when not dirty
    final repoB = DriftNotesRepository(dbB, keyManagerB);
    final notifier = EditorNotifier(initialNote: domainNote, repository: repoB);
    await notifier.saveNow();

    // Verify content in DB remained intact after saveNow
    final noteAfterSaveNow = await dbB.getNoteWithTags(noteId);
    expect(noteAfterSaveNow!.note.content, noteBody);
    expect(noteAfterSaveNow.note.isDirty, false);
  });
}
