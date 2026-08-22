import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/conflict/conflict_resolver.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

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

class ConflictSimulatingSyncApiClient implements SyncApiClient {
  final Map<String, NoteSyncPayload> serverNotes = {};
  final List<PullChangeItem> syncLog = [];
  int cursorCounter = 0;

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async {
    final results = <PushResultItem>[];
    final conflicts = <ConflictItem>[];

    for (final change in changes) {
      final existing = serverNotes[change.id];
      final currentRev = existing?.baseRevision ?? 0;

      // Conflict condition: baseRevision does not match server head
      if (existing != null && change.baseRevision != null && change.baseRevision! < currentRev) {
        conflicts.add(ConflictItem(
          id: change.id,
          noteId: change.id,
          serverRevision: currentRev,
          baseRevision: change.baseRevision,
          code: 'SYNC_CONFLICT',
          message: 'Server has newer revision $currentRev',
          serverHead: ServerHeadSyncPayload(
            revision: currentRev,
            contentCiphertext: existing.contentCiphertext,
            contentNonce: existing.contentNonce,
            contentVersion: existing.contentVersion,
            encryptionKeyVersion: existing.encryptionKeyVersion,
            isDeleted: existing.isDeleted,
            deletedAt: existing.deletedAt,
            archived: existing.archived,
            trashed: existing.trashed,
            pinned: existing.pinned,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ),
        ));
        continue;
      }

      cursorCounter++;
      final newRev = cursorCounter;
      final serverCopy = NoteSyncPayload(
        id: change.id,
        createdAt: change.createdAt,
        updatedAt: change.updatedAt,
        archived: change.archived,
        trashed: change.trashed,
        pinned: change.pinned,
        contentCiphertext: change.contentCiphertext,
        contentNonce: change.contentNonce,
        contentVersion: change.contentVersion,
        encryptionKeyVersion: change.encryptionKeyVersion,
        baseRevision: newRev,
        isDeleted: change.isDeleted,
        deletedAt: change.deletedAt,
      );
      serverNotes[change.id] = serverCopy;

      syncLog.add(PullChangeItem(
        id: change.id,
        revision: newRev,
        changeType: change.isDeleted ? 'delete' : 'upsert',
        createdAt: change.createdAt,
        updatedAt: change.updatedAt,
        archived: change.archived,
        trashed: change.trashed,
        pinned: change.pinned,
        contentCiphertext: change.contentCiphertext,
        contentNonce: change.contentNonce,
        contentVersion: change.contentVersion,
        encryptionKeyVersion: change.encryptionKeyVersion,
        deletedAt: change.deletedAt,
      ));

      results.add(PushResultItem(
        id: change.id,
        revision: newRev,
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
  Future<PullChangeItem?> getHistoricalRevision({required String noteId, required int revision}) async {
    return syncLog.cast<PullChangeItem?>().firstWhere(
      (i) => i?.id == noteId && i?.revision == revision,
      orElse: () => null,
    );
  }

  @override
  Future<PullChangeItem?> getRemoteNote({required String noteId}) async {
    return syncLog.cast<PullChangeItem?>().lastWhere(
      (i) => i?.id == noteId,
      orElse: () => null,
    );
  }

  @override
  Future<WrappedMasterKeyData?> getKeys() async => null;

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async => keyData;

  @override
  Future<PushVersionSyncResponse> pushVersions({required List<NoteVersionSyncPayload> versions, String? deviceId}) async =>
      PushVersionSyncResponse(results: [], cursor: cursorCounter);

  @override
  Future<PullVersionSyncResponse> pullVersions({required int cursor, int limit = 100}) async =>
      PullVersionSyncResponse(changes: [], cursor: cursor, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase dbA;
  late AppDatabase dbB;
  late MockAuthService authA;
  late MockAuthService authB;
  late DefaultCryptoService crypto;
  late MockKeyManager keyManagerA;
  late MockKeyManager keyManagerB;
  late ConflictSimulatingSyncApiClient sharedApi;
  late SyncEngine engineA;
  late SyncEngine engineB;
  late Uint8List masterKey;

  setUp(() async {
    dbA = AppDatabase.memory();
    dbB = AppDatabase.memory();
    authA = MockAuthService();
    authB = MockAuthService();
    crypto = DefaultCryptoService();
    sharedApi = ConflictSimulatingSyncApiClient();

    masterKey = Uint8List.fromList(List.generate(32, (i) => i + 10));

    keyManagerA = MockKeyManager(masterKey: masterKey);
    keyManagerB = MockKeyManager(masterKey: masterKey);

    engineA = SyncEngine(
      database: dbA,
      cryptoService: crypto,
      keyManager: keyManagerA,
      authService: authA,
      apiClient: sharedApi,
      conflictResolver: ConflictResolver(database: dbA),
    );

    engineB = SyncEngine(
      database: dbB,
      cryptoService: crypto,
      keyManager: keyManagerB,
      authService: authB,
      apiClient: sharedApi,
      conflictResolver: ConflictResolver(database: dbB),
    );
  });

  tearDown(() async {
    engineA.dispose();
    engineB.dispose();
    await dbA.close();
    await dbB.close();
  });

  group('End-to-End Sync Collision & 3-Way Merge Scenarios', () {
    test('Automatically merges non-conflicting concurrent edits on two devices', () async {
      const noteId = '88888888-8888-8888-8888-888888888888';

      // 1. Device A creates note and syncs (Rev 1)
      await dbA.saveNote(
        id: noteId,
        title: 'Project Tasks',
        content: '- [ ] Task 1\n- [ ] Task 2',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
        tags: ['project'],
        isDirty: true,
      );
      await engineA.syncNow();

      // 2. Device B pulls note (Rev 1)
      await engineB.syncNow();
      final noteBInitial = await dbB.getNoteWithTags(noteId);
      expect(noteBInitial?.note.serverRevision, 1);

      // 3. Device A toggles Task 1 and adds tag 'urgent' -> pushes (Rev 2)
      await dbA.saveNote(
        id: noteId,
        title: 'Project Tasks',
        content: '- [x] Task 1\n- [ ] Task 2',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['project', 'urgent'],
        serverRevision: 1,
        isDirty: true,
      );
      await engineA.syncNow();

      // 4. Device B (still having baseRevision 1) toggles Task 2 and adds tag 'frontend' -> pushes
      await dbB.saveNote(
        id: noteId,
        title: 'Project Tasks',
        content: '- [ ] Task 1\n- [x] Task 2',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        tags: ['project', 'frontend'],
        serverRevision: 1,
        isDirty: true,
      );

      // Trigger sync on Device B: collision detected -> auto-merged cleanly!
      await engineB.syncNow();

      final noteBAfterMerge = await dbB.getNoteWithTags(noteId);
      expect(noteBAfterMerge, isNotNull);
      expect(noteBAfterMerge!.note.content, '- [x] Task 1\n- [x] Task 2');
      expect(noteBAfterMerge.tagNames.toSet(), {'frontend', 'project', 'urgent'});

      // Device B auto-merges and marks dirty with serverRevision: 2 for next push
      // Run syncNow to push authoritative merged revision (Rev 3)
      await engineB.syncNow();

      // Device A pulls the authoritative merged revision
      await engineA.syncNow();
      final noteAAuthoritative = await dbA.getNoteWithTags(noteId);
      expect(noteAAuthoritative!.note.content, '- [x] Task 1\n- [x] Task 2');
      expect(noteAAuthoritative.tagNames.toSet(), {'frontend', 'project', 'urgent'});
    });

    test('Detects genuine overlapping content conflict and isolates without blocking clean notes', () async {
      const conflictedNoteId = '99999999-9999-9999-9999-999999999999';
      const cleanNoteId = '77777777-7777-7777-7777-777777777777';

      // 1. Device A creates conflicted note and clean note
      await dbA.saveNote(
        id: conflictedNoteId,
        title: 'Budget',
        content: 'Total Budget: \$10,000',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
        isDirty: true,
      );
      await dbA.saveNote(
        id: cleanNoteId,
        title: 'Clean Note',
        content: 'Clean Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
        isDirty: true,
      );
      await engineA.syncNow();

      // 2. Device B pulls notes
      await engineB.syncNow();

      // 3. Device A edits Budget to $25,000 and syncs (Rev 3)
      await dbA.saveNote(
        id: conflictedNoteId,
        title: 'Budget',
        content: 'Total Budget: \$25,000',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        serverRevision: 1,
        isDirty: true,
      );
      await engineA.syncNow();

      // 4. Device B edits Budget to $50,000 AND edits Clean Note to 'Updated Clean Content'
      await dbB.saveNote(
        id: conflictedNoteId,
        title: 'Budget',
        content: 'Total Budget: \$50,000',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        serverRevision: 1,
        isDirty: true,
      );
      await dbB.saveNote(
        id: cleanNoteId,
        title: 'Clean Note',
        content: 'Updated Clean Content',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        isPinned: false,
        serverRevision: 2,
        isDirty: true,
      );

      // Sync on Device B: Budget conflicts, but Clean Note must apply cleanly!
      await engineB.syncNow();

      final pendingConflicts = await dbB.getPendingConflicts();
      expect(pendingConflicts.length, 1);
      expect(pendingConflicts.first.noteId, conflictedNoteId);
      expect(pendingConflicts.first.conflictType, 'content');

      // Verify Clean Note was NOT blocked and synced successfully
      final cleanNoteB = await dbB.getNoteWithTags(cleanNoteId);
      expect(cleanNoteB!.note.isDirty, isFalse);

      // Verify engine state reflects conflict
      expect(engineB.state.conflictsCount, 1);
      expect(engineB.state.status, SyncStatus.conflict);
    });
  });
}
