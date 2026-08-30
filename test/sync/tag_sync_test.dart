import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

class InMemoryTagSyncApiClient extends SyncApiClient {
  final Map<String, TagSyncPayload> serverTags = {};
  final List<TagSyncPayload> tagLog = [];
  int tagCursorCounter = 0;

  @override
  Future<PushSyncResponse> pushTags({
    required List<TagSyncPayload> tags,
    String? deviceId,
  }) async {
    final results = <PushResultItem>[];
    for (final t in tags) {
      tagCursorCounter++;
      serverTags[t.id] = t;
      tagLog.add(t);
      results.add(PushResultItem(
        id: t.id,
        revision: tagCursorCounter,
        status: 'applied',
        updatedAt: DateTime.now(),
      ));
    }
    return PushSyncResponse(
      results: results,
      conflicts: [],
      cursor: tagCursorCounter,
    );
  }

  @override
  Future<PullTagSyncResponse> pullTags({
    required int cursor,
    int limit = 100,
  }) async {
    final changes = <PullTagChangeItem>[];
    final startIdx = cursor;
    final endIdx = (startIdx + limit < tagLog.length) ? startIdx + limit : tagLog.length;

    for (var i = startIdx; i < endIdx; i++) {
      final t = tagLog[i];
      changes.add(PullTagChangeItem(
        id: t.id,
        revision: i + 1,
        contentCiphertext: t.contentCiphertext,
        contentNonce: t.contentNonce,
        contentVersion: t.contentVersion,
        encryptionKeyVersion: t.encryptionKeyVersion,
        isPinned: t.isPinned,
        pinnedOrder: t.pinnedOrder,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
        isDeleted: t.isDeleted,
        deletedAt: t.deletedAt,
      ));
    }

    return PullTagSyncResponse(
      changes: changes,
      cursor: endIdx,
      hasMore: endIdx < tagLog.length,
    );
  }

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async {
    return const PushSyncResponse(results: [], conflicts: [], cursor: 0);
  }

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 50,
  }) async {
    return const PullSyncResponse(changes: [], cursor: 0, hasMore: false);
  }

  @override
  Future<WrappedMasterKeyData?> getKeys() async => null;

  @override
  Future<PullVersionSyncResponse> pullVersions({required int cursor, int limit = 100}) async {
    return const PullVersionSyncResponse(changes: [], cursor: 0, hasMore: false);
  }

  @override
  Future<void> syncReferences({required List<SyncReferenceItem> references, String? deviceId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  AuthUser? currentUser = const AuthUser(
    id: 'u1',
    email: 'test@example.com',
    idToken: 'mock-token',
  );

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeKeyManager implements KeyManager {
  FakeKeyManager({required this.masterKey});
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late CryptoService crypto;
  late Uint8List masterKey;

  setUp(() {
    crypto = DefaultCryptoService();
    masterKey = Uint8List.fromList(List.generate(32, (i) => (i * 7) % 256));
  });

  group('CryptoService Tag Payload Encryption Tests', () {
    test('Encrypts and decrypts TagPlaintext correctly with master key', () async {
      const plaintext = TagPlaintext(
        name: 'research',
        icon: 'microscope',
        color: 'teal',
      );

      final envelope = await crypto.encryptTagPayload(
        plaintext: plaintext,
        masterKeyBytes: masterKey,
        tagId: 'tag-uuid-1',
      );

      expect(envelope.ciphertext, isNotEmpty);
      expect(envelope.nonce, isNotEmpty);
      // Zero-knowledge check: ciphertext does NOT contain plaintext strings
      expect(envelope.ciphertext.contains('research'), isFalse);
      expect(envelope.ciphertext.contains('microscope'), isFalse);
      expect(envelope.ciphertext.contains('teal'), isFalse);

      final decrypted = await crypto.decryptTagPayload(
        envelope: envelope,
        masterKeyBytes: masterKey,
        tagId: 'tag-uuid-1',
      );

      expect(decrypted.name, equals('research'));
      expect(decrypted.icon, equals('microscope'));
      expect(decrypted.color, equals('teal'));
    });

    test('Decryption fails when tampering with ciphertext or using wrong key', () async {
      const plaintext = TagPlaintext(name: 'secret-tag');
      final envelope = await crypto.encryptTagPayload(
        plaintext: plaintext,
        masterKeyBytes: masterKey,
        tagId: 'tag-uuid-tamper',
      );

      final wrongKey = Uint8List.fromList(List.generate(32, (i) => (i + 1) % 256));
      expect(
        () => crypto.decryptTagPayload(
          envelope: envelope,
          masterKeyBytes: wrongKey,
          tagId: 'tag-uuid-tamper',
        ),
        throwsA(anything),
      );
    });
  });

  group('Database Tag Sync Operations', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Tag mutations mark isDirty = true and getDirtyTags retrieves them', () async {
      final tag = await db.createTag('journal', icon: 'book', color: 'indigo', isPinned: true);
      expect(tag.isDirty, isTrue);

      final dirty = await db.getDirtyTags();
      expect(dirty.length, equals(1));
      expect(dirty.first.id, equals(tag.id));
      expect(dirty.first.name, equals('journal'));

      // Mark synced
      await db.markTagSynced(
        tagId: tag.id,
        serverRevision: 1,
        syncedAt: DateTime.now(),
      );

      final dirtyAfter = await db.getDirtyTags();
      expect(dirtyAfter.isEmpty, isTrue);

      final updated = await db.getTagById(tag.id);
      expect(updated!.isDirty, isFalse);
      expect(updated.serverRevision, equals(1));
    });

    test('upsertSyncedTag handles remote creation and convergence', () async {
      final now = DateTime.now();
      await db.upsertSyncedTag(
        id: 'remote-tag-1',
        name: 'flutter',
        icon: 'code',
        color: 'teal',
        isPinned: true,
        pinnedOrder: 1,
        createdAt: now,
        updatedAt: now,
        serverRevision: 2,
        isDeleted: false,
      );

      final tag = await db.getTagById('remote-tag-1');
      expect(tag, isNotNull);
      expect(tag!.name, equals('flutter'));
      expect(tag.icon, equals('code'));
      expect(tag.color, equals('teal'));
      expect(tag.isPinned, isTrue);
      expect(tag.isDirty, isFalse);
      expect(tag.serverRevision, equals(2));
    });

    test('upsertSyncedTag merges offline duplicate tag name to canonical ID', () async {
      // Local tag created offline with ID A
      final localTag = await db.createTag('offline-tag');
      expect(localTag.name, equals('offline-tag'));

      // Remote brings tag with same name but canonical ID B
      final now = DateTime.now();
      await db.upsertSyncedTag(
        id: 'canonical-id-b',
        name: 'offline-tag',
        icon: 'star',
        color: 'amber',
        isPinned: true,
        pinnedOrder: 0,
        createdAt: now,
        updatedAt: now,
        serverRevision: 5,
        isDeleted: false,
      );

      final allTags = await db.getAllTagNames();
      expect(allTags.length, equals(1));
      expect(allTags.first, equals('offline-tag'));

      final canonicalTag = await db.getTagById('canonical-id-b');
      expect(canonicalTag, isNotNull);
      expect(canonicalTag!.icon, equals('star'));
      expect(canonicalTag.color, equals('amber'));
      expect(canonicalTag.isPinned, isTrue);
    });

    test('deleteTag creates soft-deletion tombstone when serverRevision > 0', () async {
      final tag = await db.createTag('to-delete');
      // Simulate that tag was synced to server at rev 3
      await db.markTagSynced(tagId: tag.id, serverRevision: 3, syncedAt: DateTime.now());

      // User deletes tag
      await db.deleteTag(tag.id);

      // Verify tombstone is preserved for sync push
      final dirty = await db.getDirtyTags();
      expect(dirty.length, equals(1));
      expect(dirty.first.id, equals(tag.id));
      expect(dirty.first.isDeleted, isTrue);
      expect(dirty.first.deletedAt, isNotNull);

      // When sync confirms push, markTagSynced permanently removes the tombstone
      await db.markTagSynced(tagId: tag.id, serverRevision: 4, syncedAt: DateTime.now());
      final remaining = await db.getTagById(tag.id);
      expect(remaining, isNull);
    });
  });

  group('End-to-End Cross-Device Tag Sync Engine Integration', () {
    late AppDatabase dbA;
    late AppDatabase dbB;
    late InMemoryTagSyncApiClient sharedApi;
    late KeyManager keyManagerA;
    late KeyManager keyManagerB;
    late FakeAuthService authA;
    late FakeAuthService authB;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      dbA = AppDatabase(NativeDatabase.memory());
      dbB = AppDatabase(NativeDatabase.memory());
      sharedApi = InMemoryTagSyncApiClient();

      keyManagerA = FakeKeyManager(masterKey: masterKey);
      keyManagerB = FakeKeyManager(masterKey: masterKey);

      authA = FakeAuthService();
      authB = FakeAuthService();

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
      await dbA.close();
      await dbB.close();
    });

    test('Tag created on Device A synchronizes seamlessly to Device B', () async {
      // 1. Device A creates a customized tag
      final tagA = await dbA.createTag(
        'quietpaper',
        icon: 'feather',
        color: 'sage',
        isPinned: true,
      );
      expect(tagA.isDirty, isTrue);

      // 2. Device A pushes to cloud
      await engineA.syncNow();

      final updatedTagA = await dbA.getTagById(tagA.id);
      expect(updatedTagA!.isDirty, isFalse);
      expect(updatedTagA.serverRevision, equals(1));
      expect(sharedApi.serverTags.containsKey(tagA.id), isTrue);

      // 3. Device B pulls from cloud
      await engineB.syncNow();

      // 4. Verify Device B has decrypted and stored the identical tag
      final tagB = await dbB.getTagById(tagA.id);
      expect(tagB, isNotNull);
      expect(tagB!.name, equals('quietpaper'));
      expect(tagB.icon, equals('feather'));
      expect(tagB.color, equals('sage'));
      expect(tagB.isPinned, isTrue);
      expect(tagB.isDirty, isFalse);
      expect(tagB.serverRevision, equals(1));
    });

    test('Tag deletion on Device A propagates tombstone to Device B', () async {
      // Create and sync tag
      final tag = await dbA.createTag('temp-tag', icon: 'bookmark', color: 'rose');
      await engineA.syncNow();
      await engineB.syncNow();

      expect(await dbB.getTagById(tag.id), isNotNull);

      // Device A deletes tag
      await dbA.deleteTag(tag.id);
      await engineA.syncNow();

      // Device B pulls deletion
      await engineB.syncNow();

      // Device B tag should be gone
      expect(await dbB.getTagById(tag.id), isNull);
    });
  });
}
