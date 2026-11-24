import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/journal/application/place_grouping_service.dart';
import 'package:quitepaper/features/journal/application/place_alias_store.dart';

class _KeyManager implements KeyManager {
  @override
  Uint8List getMasterKey() => Uint8List(32);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedRepository extends PlaceAliasRepository {
  _DelayedRepository(AppDatabase db)
      : super(database: db, cryptoService: DefaultCryptoService(), keyManager: _KeyManager());
  final rows = StreamController<List<PlaceAliasEntity>>.broadcast();
  final decodes = <Completer<Map<String, PlaceAlias>>>[];
  @override
  Future<void> migrateFromPrefs(Map<String, PlaceAlias> legacy) async {}
  @override
  Stream<List<PlaceAliasEntity>> watchRows() => rows.stream;
  @override
  Future<void> put(String matchKey, PlaceAlias alias) async {}
  @override
  Future<Map<String, PlaceAlias>> decodeRows(List<PlaceAliasEntity> rows) {
    final result = Completer<Map<String, PlaceAlias>>();
    decodes.add(result);
    return result.future;
  }
}

Map<String, PlaceAlias> _named(String name) => {
  'city': PlaceAlias(canonicalKey: 'city', displayName: name),
};

void main() {
  late AppDatabase db;
  late _DelayedRepository repository;
  late PlaceAliasStore store;
  setUp(() async {
    db = AppDatabase.memory();
    repository = _DelayedRepository(db);
    store = PlaceAliasStore(repository: repository);
    await pumpEventQueue();
  });
  tearDown(() async {
    if (store.mounted) store.dispose();
    await repository.rows.close();
    await db.close();
  });

  Future<void> emit() async {
    repository.rows.add([]);
    await pumpEventQueue();
  }

  test('older decode cannot overwrite a newer completed snapshot', () async {
    await emit();
    await emit();
    repository.decodes[1].complete(_named('New name'));
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'New name');
    repository.decodes[0].complete(_named('Old name'));
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'New name');
  });

  test('a pending decode cannot undo a local rename', () async {
    await emit();
    store.rename(canonicalKey: 'city', displayName: 'Home');
    repository.decodes[0].complete(_named('Old name'));
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'Home');
  });

  test('decode failure retains state and later snapshots recover', () async {
    await emit();
    repository.decodes[0].complete(_named('Readable'));
    await pumpEventQueue();
    await emit();
    repository.decodes[1].completeError(StateError('decode failed'));
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'Readable');
    await emit();
    repository.decodes[2].complete(_named('Recovered'));
    await pumpEventQueue();
    expect(store.state['city']!.displayName, 'Recovered');
  });

  test('decoding after disposal does not publish state', () async {
    await emit();
    store.dispose();
    repository.decodes[0].complete(_named('Late'));
    await pumpEventQueue();
  });
}
