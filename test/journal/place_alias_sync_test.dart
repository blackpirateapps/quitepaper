import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/journal/application/place_grouping_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/features/journal/application/place_alias_store.dart';

/// In-memory stand-in for the backend's place-alias endpoints. Models the
/// server as a revision log with id-keyed upsert (MAX(revision)+1), mirroring
/// `syncService.pushPlaceAliases` / `pullPlaceAliases`.
class InMemoryPlaceAliasApi extends SyncApiClient {
  final Map<String, PlaceAliasSyncPayload> rows = {};
  final Map<String, int> revisions = {};
  int _rev = 0;

  @override
  Future<PushSyncResponse> pushPlaceAliases({
    required List<PlaceAliasSyncPayload> placeAliases,
    String? deviceId,
  }) async {
    final results = <PushResultItem>[];
    for (final p in placeAliases) {
      _rev++;
      rows[p.id] = p;
      revisions[p.id] = _rev;
      results.add(PushResultItem(
        id: p.id,
        revision: _rev,
        status: 'applied',
        updatedAt: DateTime.now(),
      ));
    }
    return PushSyncResponse(results: results, conflicts: [], cursor: _rev);
  }

  @override
  Future<PullPlaceAliasSyncResponse> pullPlaceAliases({
    required int cursor,
    int limit = 100,
  }) async {
    final entries = revisions.entries.where((e) => e.value > cursor).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final slice = entries.take(limit).toList();
    final changes = <PullPlaceAliasChangeItem>[];
    for (final e in slice) {
      final p = rows[e.key]!;
      changes.add(PullPlaceAliasChangeItem(
        id: p.id,
        revision: e.value,
        contentCiphertext: p.contentCiphertext,
        contentNonce: p.contentNonce,
        contentVersion: p.contentVersion,
        encryptionKeyVersion: p.encryptionKeyVersion,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        isDeleted: p.isDeleted,
        deletedAt: p.deletedAt,
      ));
    }
    final nextCursor =
        slice.isEmpty ? cursor : slice.last.value;
    return PullPlaceAliasSyncResponse(
      changes: changes,
      cursor: nextCursor,
      hasMore: entries.length > slice.length,
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
  Future<PullSyncResponse> pullChanges({required int cursor, int limit = 50}) async =>
      const PullSyncResponse(changes: [], cursor: 0, hasMore: false);

  @override
  Future<WrappedMasterKeyData?> getKeys() async => null;

  @override
  Future<PullVersionSyncResponse> pullVersions(
          {required int cursor, int limit = 100}) async =>
      const PullVersionSyncResponse(changes: [], cursor: 0, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  AuthUser? currentUser =
      const AuthUser(id: 'u1', email: 't@e.com', idToken: 'tok');
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'tok';
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

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late CryptoService crypto;
  late Uint8List masterKey;

  setUp(() {
    crypto = DefaultCryptoService();
    masterKey = Uint8List.fromList(List.generate(32, (i) => (i * 11) % 256));
  });

  // PLACEHOLDER_TESTS

  group('PlaceAlias crypto (§2.3)', () {
    test('encrypt/decrypt round-trips and is zero-knowledge', () async {
      const pt = PlaceAliasPlaintext(
        matchKey: 'calcutta',
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );
      final id =
          crypto.computePlaceAliasId(matchKey: 'calcutta', masterKeyBytes: masterKey);
      final env = await crypto.encryptPlaceAliasPayload(
        plaintext: pt,
        masterKeyBytes: masterKey,
        placeAliasId: id,
      );
      // Server never sees names: ciphertext/id contain no plaintext tokens.
      expect(env.ciphertext.contains('calcutta'), isFalse);
      expect(env.ciphertext.contains('kolkata'), isFalse);
      expect(env.ciphertext.contains('Kolkata'), isFalse);
      expect(id.contains('calcutta'), isFalse);

      final back = await crypto.decryptPlaceAliasPayload(
        envelope: env,
        masterKeyBytes: masterKey,
        placeAliasId: id,
      );
      expect(back, equals(pt));
    });

    test('id is deterministic per key and unguessable across keys', () {
      final a1 =
          crypto.computePlaceAliasId(matchKey: 'kolkata', masterKeyBytes: masterKey);
      final a2 =
          crypto.computePlaceAliasId(matchKey: 'kolkata', masterKeyBytes: masterKey);
      // Same device/key → identical id (same-id reconciliation on pull).
      expect(a1, equals(a2));
      expect(a1.length, equals(64)); // sha256 hex

      final otherKey =
          Uint8List.fromList(List.generate(32, (i) => (i * 13 + 1) % 256));
      final b =
          crypto.computePlaceAliasId(matchKey: 'kolkata', masterKeyBytes: otherKey);
      // Keyed → a different master key yields a different, unlinkable id.
      expect(a1, isNot(equals(b)));

      final c =
          crypto.computePlaceAliasId(matchKey: 'mumbai', masterKeyBytes: masterKey);
      expect(a1, isNot(equals(c)));
    });

    test('decrypt fails with the wrong key', () async {
      final id =
          crypto.computePlaceAliasId(matchKey: 'x', masterKeyBytes: masterKey);
      final env = await crypto.encryptPlaceAliasPayload(
        plaintext: const PlaceAliasPlaintext(
            matchKey: 'x', canonicalKey: 'y', displayName: 'Y'),
        masterKeyBytes: masterKey,
        placeAliasId: id,
      );
      final wrong =
          Uint8List.fromList(List.generate(32, (i) => (i + 3) % 256));
      expect(
        () => crypto.decryptPlaceAliasPayload(
            envelope: env, masterKeyBytes: wrong, placeAliasId: id),
        throwsA(anything),
      );
    });
  });

  group('PlaceAlias database ops', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('putLocalPlaceAlias marks dirty; markPlaceAliasSynced clears it', () async {
      await db.putLocalPlaceAlias(
          id: 'id-1', contentCiphertext: 'ct', contentNonce: 'nn');
      final dirty = await db.getDirtyPlaceAliases();
      expect(dirty.length, 1);
      expect(dirty.first.id, 'id-1');
      expect(dirty.first.isDirty, isTrue);

      await db.markPlaceAliasSynced(
          id: 'id-1', serverRevision: 7, syncedAt: DateTime.now());
      final after = await db.getDirtyPlaceAliases();
      expect(after, isEmpty);
      final all = await db.getAllPlaceAliases();
      expect(all.single.serverRevision, 7);
    });

    test('tombstone of a synced row propagates then is purged on confirm', () async {
      await db.putLocalPlaceAlias(
          id: 'id-2', contentCiphertext: 'ct', contentNonce: 'nn');
      await db.markPlaceAliasSynced(
          id: 'id-2', serverRevision: 1, syncedAt: DateTime.now());

      final wrote = await db.tombstoneLocalPlaceAlias('id-2');
      expect(wrote, isTrue);
      final dirty = await db.getDirtyPlaceAliases();
      expect(dirty.single.isDeleted, isTrue);
      // Not visible to the live (non-deleted) view.
      expect(await db.getAllPlaceAliases(), isEmpty);

      await db.markPlaceAliasSynced(
          id: 'id-2', serverRevision: 2, syncedAt: DateTime.now());
      final remaining = await db.getDirtyPlaceAliases();
      expect(remaining, isEmpty);
    });

    test('never-synced tombstone just drops the row', () async {
      await db.putLocalPlaceAlias(
          id: 'id-3', contentCiphertext: 'ct', contentNonce: 'nn');
      final wrote = await db.tombstoneLocalPlaceAlias('id-3');
      expect(wrote, isTrue);
      expect(await db.getDirtyPlaceAliases(), isEmpty);
      expect(await db.getAllPlaceAliases(), isEmpty);
    });

    test('upsertSyncedPlaceAlias is convergent and keeps newer local dirty edits',
        () async {
      final t1 = DateTime.now();
      await db.upsertSyncedPlaceAlias(
        id: 'id-4',
        contentCiphertext: 'remote',
        contentNonce: 'rn',
        createdAt: t1,
        updatedAt: t1,
        serverRevision: 1,
        isDeleted: false,
      );
      expect((await db.getAllPlaceAliases()).single.contentCiphertext, 'remote');

      // Reordered older remote change must not clobber a newer local dirty row.
      await db.putLocalPlaceAlias(
          id: 'id-4', contentCiphertext: 'local-new', contentNonce: 'ln');
      final older = t1.subtract(const Duration(minutes: 5));
      await db.upsertSyncedPlaceAlias(
        id: 'id-4',
        contentCiphertext: 'remote-old',
        contentNonce: 'ro',
        createdAt: older,
        updatedAt: older,
        serverRevision: 2,
        isDeleted: false,
      );
      expect((await db.getAllPlaceAliases()).single.contentCiphertext, 'local-new');
    });
  });

  group('Cross-device place-alias sync (engine)', () {
    late AppDatabase dbA;
    late AppDatabase dbB;
    late InMemoryPlaceAliasApi api;
    late SyncEngine engineA;
    late SyncEngine engineB;
    late PlaceAliasRepository repoA;
    late PlaceAliasRepository repoB;

    setUp(() {
      dbA = AppDatabase(NativeDatabase.memory());
      dbB = AppDatabase(NativeDatabase.memory());
      api = InMemoryPlaceAliasApi();
      engineA = SyncEngine(
        database: dbA,
        cryptoService: crypto,
        keyManager: FakeKeyManager(masterKey: masterKey),
        authService: FakeAuthService(),
        apiClient: api,
      );
      engineB = SyncEngine(
        database: dbB,
        cryptoService: crypto,
        keyManager: FakeKeyManager(masterKey: masterKey),
        authService: FakeAuthService(),
        apiClient: api,
      );
      repoA = PlaceAliasRepository(
        database: dbA,
        cryptoService: crypto,
        keyManager: FakeKeyManager(masterKey: masterKey),
      );
      repoB = PlaceAliasRepository(
        database: dbB,
        cryptoService: crypto,
        keyManager: FakeKeyManager(masterKey: masterKey),
      );
    });

    tearDown(() async {
      engineA.dispose();
      engineB.dispose();
      await dbA.close();
      await dbB.close();
    });

    test('a merge on A converges to B with identical ids', () async {
      const alias = PlaceAlias(canonicalKey: 'kolkata', displayName: 'Kolkata');
      await repoA.put('calcutta', alias);
      await repoA.put('kolkata', alias);

      await engineA.syncNow();
      await engineB.syncNow();

      final onB = await repoB.decodeRows(await dbB.getAllPlaceAliases());
      expect(onB['calcutta']?.canonicalKey, 'kolkata');
      expect(onB['calcutta']?.displayName, 'Kolkata');
      expect(onB['kolkata']?.canonicalKey, 'kolkata');

      // Deterministic id: the same alias has the same row id on both devices.
      final idA = crypto.computePlaceAliasId(
          matchKey: 'calcutta', masterKeyBytes: masterKey);
      expect((await dbA.getAllPlaceAliases()).any((r) => r.id == idA), isTrue);
      expect((await dbB.getAllPlaceAliases()).any((r) => r.id == idA), isTrue);
    });

    test('an unmerge tombstone on A removes the row on B', () async {
      const alias = PlaceAlias(canonicalKey: 'kolkata', displayName: 'Kolkata');
      await repoA.put('calcutta', alias);
      await engineA.syncNow();
      await engineB.syncNow();
      expect(
          (await repoB.decodeRows(await dbB.getAllPlaceAliases()))
              .containsKey('calcutta'),
          isTrue);

      // A unmerges calcutta → tombstone propagates.
      await repoA.remove('calcutta');
      await engineA.syncNow();
      await engineB.syncNow();

      expect(await dbB.getAllPlaceAliases(), isEmpty);
    });
  });

  group('PlaceAliasStore DB path', () {
    late AppDatabase db;
    late PlaceAliasRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = PlaceAliasRepository(
        database: db,
        cryptoService: crypto,
        keyManager: FakeKeyManager(masterKey: masterKey),
      );
    });
    tearDown(() async => db.close());

    test('merge writes dirty encrypted rows and reflects in state', () async {
      var synced = 0;
      final prov =
          StateNotifierProvider<PlaceAliasStore, Map<String, PlaceAlias>>(
              (ref) => PlaceAliasStore(repository: repo, onMutation: () => synced++));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(prov.notifier); // construct + init
      await _settle();

      container
          .read(prov.notifier)
          .merge(['calcutta'], canonicalKey: 'kolkata', displayName: 'Kolkata');
      await _settle();

      expect(container.read(prov)['calcutta']?.canonicalKey, 'kolkata');
      final dirty = await db.getDirtyPlaceAliases();
      expect(dirty.length, 2); // calcutta + kolkata self-map
      expect(dirty.every((r) => r.contentCiphertext.isNotEmpty), isTrue);
      expect(synced, greaterThan(0)); // sync was requested after the mutation
    });

    test('unmerge tombstones a synced row', () async {
      final prov =
          StateNotifierProvider<PlaceAliasStore, Map<String, PlaceAlias>>(
              (ref) => PlaceAliasStore(repository: repo));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(prov.notifier);
      await _settle();
      container
          .read(prov.notifier)
          .merge(['calcutta'], canonicalKey: 'kolkata', displayName: 'Kolkata');
      await _settle();
      // Pretend both rows reached the server.
      for (final r in await db.getDirtyPlaceAliases()) {
        await db.markPlaceAliasSynced(
            id: r.id, serverRevision: 1, syncedAt: DateTime.now());
      }

      container.read(prov.notifier).unmerge('calcutta');
      await _settle();

      expect(container.read(prov).containsKey('calcutta'), isFalse);
      final dirty = await db.getDirtyPlaceAliases();
      expect(dirty.length, 1);
      expect(dirty.single.isDeleted, isTrue);
    });

    test('one-time SharedPreferences → DB migration imports legacy merges',
        () async {
      final legacy = <String, PlaceAlias>{
        'calcutta':
            const PlaceAlias(canonicalKey: 'kolkata', displayName: 'Kolkata'),
        'kolkata':
            const PlaceAlias(canonicalKey: 'kolkata', displayName: 'Kolkata'),
      };
      await repo.migrateFromPrefs(legacy);

      final rows = await db.getDirtyPlaceAliases();
      expect(rows.length, 2);
      final decoded = await repo.decodeRows(await db.getAllPlaceAliases());
      expect(decoded['calcutta']?.displayName, 'Kolkata');

      // Running again is a no-op (flag guard), not a duplicate import.
      await repo.migrateFromPrefs(legacy);
      expect((await db.getAllPlaceAliases()).length, 2);
    });
  });
}

