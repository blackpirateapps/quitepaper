import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/place_alias_store.dart';

class _KeyManager implements KeyManager {
  bool unlocked = true;
  @override
  Uint8List getMasterKey() {
    if (!unlocked) throw StateError('locked');
    return Uint8List.fromList(List.generate(32, (i) => i));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late PlaceAliasRepository repository;
  late PlaceAliasStore store;
  late _KeyManager keyManager;
  var syncs = 0;
  setUp(() async {
    db = AppDatabase.memory();
    keyManager = _KeyManager();
    repository = PlaceAliasRepository(
      database: db,
      cryptoService: DefaultCryptoService(),
      keyManager: keyManager,
    );
    syncs = 0;
    store = PlaceAliasStore(repository: repository, onMutation: () => syncs++);
    await pumpEventQueue();
  });
  tearDown(() async {
    store.dispose();
    await pumpEventQueue();
    await db.close();
  });

  test(
    'failed rename reports failure, retains saved state and supports retry/reopen',
    () async {
      await store.rename(canonicalKey: 'city', displayName: 'Old name');
      await db.customStatement(
        "CREATE TRIGGER fail_alias BEFORE INSERT ON place_aliases BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END",
      );
      await expectLater(
        store.rename(canonicalKey: 'city', displayName: 'Home'),
        throwsA(anything),
      );
      expect(store.state['city']!.displayName, 'Old name');
      expect((await repository.readAliases())['city']!.displayName, 'Old name');
      expect(syncs, 1);
      await db.customStatement('DROP TRIGGER fail_alias');
      await store.rename(canonicalKey: 'city', displayName: 'Home');
      expect(syncs, 2);
      store.dispose();
      store = PlaceAliasStore(repository: repository);
      await pumpEventQueue();
      expect(store.state['city']!.displayName, 'Home');
    },
  );

  test('a failed multi-row merge rolls back every row before retry', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_alias BEFORE INSERT ON place_aliases WHEN (SELECT COUNT(*) FROM place_aliases) >= 1 BEGIN SELECT RAISE(ABORT, 'second row failed'); END",
    );
    await expectLater(
      store.merge(['alpha', 'beta'], canonicalKey: 'trip', displayName: 'Trip'),
      throwsA(anything),
    );
    expect(await db.getAllPlaceAliases(), isEmpty);
    expect(store.state, isEmpty);
    expect(syncs, 0);
    await db.customStatement('DROP TRIGGER fail_alias');
    await store.merge(
      ['alpha', 'beta'],
      canonicalKey: 'trip',
      displayName: 'Trip',
    );
    expect((await repository.readAliases()).keys.toSet(), {
      'alpha',
      'beta',
      'trip',
    });
  });

  test('a failed multi-row unmerge is atomic and retryable', () async {
    await store.merge(
      ['alpha', 'beta'],
      canonicalKey: 'trip',
      displayName: 'Trip',
    );
    await db.customStatement(
      "CREATE TRIGGER fail_alias BEFORE DELETE ON place_aliases WHEN (SELECT COUNT(*) FROM place_aliases) < 3 BEGIN SELECT RAISE(ABORT, 'second deletion failed'); END",
    );
    await expectLater(store.unmergeCanonical('trip'), throwsA(anything));
    expect(await repository.readAliases(), hasLength(3));
    expect(store.state, hasLength(3));
    await db.customStatement('DROP TRIGGER fail_alias');
    await store.unmergeCanonical('trip');
    expect(await repository.readAliases(), isEmpty);
    expect(store.state, isEmpty);
  });

  test('queued changes use the latest committed constituents', () async {
    final first = store.merge(
      ['alpha', 'beta'],
      canonicalKey: 'trip',
      displayName: 'Trip',
    );
    final second = store.merge(
      ['trip', 'gamma'],
      canonicalKey: 'journey',
      displayName: 'Journey',
    );
    final third = store.rename(canonicalKey: 'journey', displayName: 'Home');
    await Future.wait([first, second, third]);
    final saved = await repository.readAliases();
    expect(saved, hasLength(5));
    expect(saved.values.every((alias) => alias.displayName == 'Home'), isTrue);
    expect(
      store.state.values.every((alias) => alias.displayName == 'Home'),
      isTrue,
    );
  });

  test('locking the vault cannot silently accept an unsaved change', () async {
    await store.rename(canonicalKey: 'city', displayName: 'Saved');
    keyManager.unlocked = false;
    await expectLater(
      store.rename(canonicalKey: 'city', displayName: 'Unsaved'),
      throwsStateError,
    );
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'Saved');
    keyManager.unlocked = true;
    await store.rename(canonicalKey: 'city', displayName: 'Recovered');
    expect((await repository.readAliases())['city']!.displayName, 'Recovered');
  });
}
