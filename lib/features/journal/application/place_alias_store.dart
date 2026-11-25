import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/key_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/journal/application/place_grouping_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../../settings/application/settings_provider.dart';

/// Encrypted, crypto-blind persistence for the place-alias collection (§2.3).
///
/// Each alias (one `matchKey → {canonicalKey, displayName}` mapping) is one
/// synced row whose payload is sealed inside the ciphertext. The row id is a
/// deterministic keyed hash of the normalized match key, so every device
/// derives the SAME id (same-id reconciliation on pull) without leaking the
/// place name to the server. Reads/writes require an unlocked master key.
class PlaceAliasRepository {
  PlaceAliasRepository({
    required this.database,
    required this.cryptoService,
    required this.keyManager,
  });

  final AppDatabase database;
  final CryptoService cryptoService;
  final KeyManager keyManager;

  Uint8List? _key() {
    try {
      return keyManager.getMasterKey();
    } catch (_) {
      return null;
    }
  }

  bool get isUnlocked => _key() != null;

  /// Live stream of non-tombstoned rows; emits immediately then on any change
  /// (local write-through or remote pull), driving the store's state.
  Stream<List<PlaceAliasEntity>> watchRows() {
    return (database.select(database.placeAliasesTable)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  /// Decrypts [rows] into the presentation map keyed by normalized match key.
  /// Rows that fail to decrypt (wrong key, corrupt) are skipped, never fatal.
  Future<Map<String, PlaceAlias>> decodeRows(
    List<PlaceAliasEntity> rows,
  ) async {
    final key = _key();
    if (key == null) return const {};
    final map = <String, PlaceAlias>{};
    for (final r in rows) {
      if (r.contentCiphertext.isEmpty) continue;
      try {
        final envelope = EncryptedEnvelope(
          version: r.contentVersion,
          algorithm: 'xchacha20-poly1305',
          keyVersion: r.encryptionKeyVersion,
          nonce: r.contentNonce,
          ciphertext: r.contentCiphertext,
        );
        final pt = await cryptoService.decryptPlaceAliasPayload(
          envelope: envelope,
          masterKeyBytes: key,
          placeAliasId: r.id,
        );
        if (pt.matchKey.isNotEmpty) {
          map[pt.matchKey] = PlaceAlias(
            canonicalKey: pt.canonicalKey,
            displayName: pt.displayName,
          );
        }
      } catch (_) {
        // Undecryptable row → skip; never break the Places surface.
      }
    }
    return map;
  }

  /// Encrypts and write-through-upserts one alias row (marks it dirty).
  Future<void> put(String matchKey, PlaceAlias alias) async {
    final key = _key();
    if (key == null) {
      throw StateError('Unlock the vault to save place changes.');
    }
    final id = cryptoService.computePlaceAliasId(
      matchKey: matchKey,
      masterKeyBytes: key,
    );
    final envelope = await cryptoService.encryptPlaceAliasPayload(
      plaintext: PlaceAliasPlaintext(
        matchKey: matchKey,
        canonicalKey: alias.canonicalKey,
        displayName: alias.displayName,
      ),
      masterKeyBytes: key,
      placeAliasId: id,
    );
    await database.putLocalPlaceAlias(
      id: id,
      contentCiphertext: envelope.ciphertext,
      contentNonce: envelope.nonce,
      contentVersion: envelope.contentVersion,
      encryptionKeyVersion: envelope.keyVersion,
    );
  }

  /// Tombstones the row for [matchKey] so the removal propagates on sync.
  Future<void> remove(String matchKey) async {
    final key = _key();
    if (key == null) {
      throw StateError('Unlock the vault to save place changes.');
    }
    final id = cryptoService.computePlaceAliasId(
      matchKey: matchKey,
      masterKeyBytes: key,
    );
    await database.tombstoneLocalPlaceAlias(id);
  }

  Future<Map<String, PlaceAlias>> readAliases() async {
    return decodeRows(await database.getAllPlaceAliases());
  }

  /// Read, transform and commit a complete mutation atomically. Re-read here so
  /// queued actions include prior local writes and already-committed remote edits.
  Future<Map<String, PlaceAlias>> updateAliases(
    Map<String, PlaceAlias> Function(Map<String, PlaceAlias>) change,
  ) {
    return database.transaction(() async {
      if (!isUnlocked) {
        throw StateError('Unlock the vault to save place changes.');
      }
      final current = await readAliases();
      final next = change(Map<String, PlaceAlias>.of(current));
      for (final entry in next.entries) {
        final old = current[entry.key];
        if (old?.canonicalKey != entry.value.canonicalKey ||
            old?.displayName != entry.value.displayName) {
          await put(entry.key, entry.value);
        }
      }
      for (final key in current.keys.where((key) => !next.containsKey(key))) {
        await remove(key);
      }
      return next;
    });
  }

  /// One-time import of the legacy device-local SharedPreferences alias map
  /// into the DB (marking rows dirty so they sync). Guarded by a persistent
  /// flag so existing users' merges carry over exactly once.
  Future<void> migrateFromPrefs(Map<String, PlaceAlias> legacy) async {
    final done = await database.getSyncMetadata('place_alias_migrated');
    if (done == 'true') return;
    await database.transaction(() async {
      for (final entry in legacy.entries) {
        await put(entry.key, entry.value);
      }
      await database.setSyncMetadata('place_alias_migrated', 'true');
    });
  }
}

/// Reversible place-alias store. Mutations are serialized and only publish after
/// durable persistence succeeds; callers receive failures and can offer retry.
/// An unlocked repository uses encrypted, transactional rows; device-local use
/// awaits SharedPreferences. Live database snapshots converge remote changes.
class PlaceAliasStore extends StateNotifier<Map<String, PlaceAlias>> {
  PlaceAliasStore({
    PlaceAliasRepository? repository,
    SharedPreferences? prefs,
    void Function()? onMutation,
  }) : _repo = repository,
       _prefs = prefs,
       _syncTrigger = onMutation,
       super(repository == null ? _loadPrefs(prefs) : const {}) {
    _initialization = _init();
  }

  late final Future<void> _initialization;
  Future<void> _mutations = Future<void>.value();
  bool _isWriting = false;
  final PlaceAliasRepository? _repo;
  final SharedPreferences? _prefs;
  final void Function()? _syncTrigger;
  StreamSubscription<List<PlaceAliasEntity>>? _sub;
  int _snapshotVersion = 0;

  /// Legacy single SharedPreferences key holding the JSON-encoded alias map.
  static const String storageKey = 'journal_place_aliases';

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return; // legacy prefs-only path
    try {
      if (repo.isUnlocked) {
        await repo.migrateFromPrefs(_loadPrefs(_prefs));
      }
      if (!mounted) return;
      _sub = repo.watchRows().listen((rows) async {
        final version = ++_snapshotVersion;
        if (!repo.isUnlocked) return;
        try {
          final map = await repo.decodeRows(rows);
          if (mounted &&
              repo.isUnlocked &&
              !_isWriting &&
              version == _snapshotVersion) {
            state = map;
          }
        } catch (_) {
          // Keep the last readable snapshot; the next emission can recover.
        }
      });
      await _reload(repo);
    } catch (_) {
      // DB/crypto unavailable → stay with whatever (empty) state we have.
    }
  }

  Future<void> _reload(PlaceAliasRepository repo) async {
    if (!repo.isUnlocked) return;
    final version = ++_snapshotVersion;
    try {
      final map = await repo.readAliases();
      if (mounted &&
          repo.isUnlocked &&
          !_isWriting &&
          version == _snapshotVersion) {
        state = map;
      }
    } catch (_) {
      // Retain the last readable state; a mutation still reports write failures.
    }
  }

  @override
  void dispose() {
    ++_snapshotVersion;
    _sub?.cancel();
    super.dispose();
  }

  /// Folds [matchKeys] into one place: each key is pointed at [canonicalKey]
  /// with the shared [displayName]. The canonical key is also mapped to itself
  /// so entries that already produce it adopt the chosen display name.
  Future<void> merge(
    List<String> matchKeys, {
    required String canonicalKey,
    required String displayName,
  }) => _mutate((next) {
    final alias = PlaceAlias(
      canonicalKey: canonicalKey,
      displayName: displayName,
    );
    final keys = <String>{...matchKeys, canonicalKey};
    var expanded = true;
    while (expanded) {
      expanded = false;
      for (final entry in next.entries) {
        if (keys.contains(entry.value.canonicalKey) && keys.add(entry.key)) {
          expanded = true;
        }
      }
    }
    for (final key in keys) {
      next[key] = alias;
    }
    return next;
  });

  /// Renames every constituent of a merged place, including its self-map.
  Future<void> rename({
    required String canonicalKey,
    required String displayName,
  }) => _mutate((next) {
    final alias = PlaceAlias(
      canonicalKey: canonicalKey,
      displayName: displayName,
    );
    next.updateAll(
      (key, existing) =>
          existing.canonicalKey == canonicalKey ? alias : existing,
    );
    next[canonicalKey] = alias;
    return next;
  });

  /// Restores a single constituent to its own group.
  Future<void> unmerge(String matchKey) =>
      _mutate((next) => next..remove(matchKey));

  /// Fully reverses a merge, including the canonical self-map.
  Future<void> unmergeCanonical(String canonicalKey) => _mutate(
    (next) =>
        next..removeWhere((_, alias) => alias.canonicalKey == canonicalKey),
  );

  Future<void> _mutate(
    Map<String, PlaceAlias> Function(Map<String, PlaceAlias>) change,
  ) {
    final result = _mutations.then((_) async {
      await _initialization;
      if (!mounted) throw StateError('Place view was closed.');
      ++_snapshotVersion;
      _isWriting = true;
      final repo = _repo;
      try {
        final Map<String, PlaceAlias> next;
        if (repo != null) {
          next = await repo.updateAliases(change);
        } else {
          next = change(Map<String, PlaceAlias>.of(state));
          await _persistPrefs(next);
        }
        if (mounted) {
          ++_snapshotVersion;
          state = next;
        }
      } finally {
        _isWriting = false;
        // Reconcile any remote emission deferred while the transaction ran.
        if (mounted && repo != null) unawaited(_reload(repo));
      }
      if (repo != null) _syncTrigger?.call();
    });
    // Failed actions are reported to their callers without poisoning the queue.
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static Map<String, PlaceAlias> _loadPrefs(SharedPreferences? prefs) {
    if (prefs == null) return const {};
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final result = <String, PlaceAlias>{};
      decoded.forEach((key, value) {
        if (key is String && value is Map) {
          final canonical = value['canonicalKey'];
          final display = value['displayName'];
          if (canonical is String && display is String) {
            result[key] = PlaceAlias(
              canonicalKey: canonical,
              displayName: display,
            );
          }
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persistPrefs(Map<String, PlaceAlias> next) async {
    final prefs = _prefs;
    if (prefs == null) return; // in-memory only (e.g. tests without prefs)
    final map = <String, Map<String, String>>{
      for (final entry in next.entries)
        entry.key: {
          'canonicalKey': entry.value.canonicalKey,
          'displayName': entry.value.displayName,
        },
    };
    if (!await prefs.setString(storageKey, jsonEncode(map))) {
      throw StateError('Could not save place changes.');
    }
  }
}

/// Alias/merge store provider (§2.3). Builds the synced, encrypted repository
/// when the database, crypto service and an UNLOCKED key manager are all
/// available; otherwise falls back to a device-local SharedPreferences store.
/// Watches [isKeyManagerUnlockedProvider] so unlocking rebuilds onto the synced
/// path.
final placeAliasStoreProvider =
    StateNotifierProvider<PlaceAliasStore, Map<String, PlaceAlias>>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {
        // No prefs in this scope → in-memory only.
      }

      // Rebuild onto the synced path once the vault unlocks.
      var unlocked = false;
      try {
        unlocked = ref.watch(isKeyManagerUnlockedProvider);
      } catch (_) {}

      PlaceAliasRepository? repo;
      void Function()? onMutation;
      if (unlocked) {
        try {
          final db = ref.watch(databaseProvider);
          final crypto = ref.watch(cryptoServiceProvider);
          final km = ref.watch(keyManagerProvider);
          if (km.isUnlocked) {
            repo = PlaceAliasRepository(
              database: db,
              cryptoService: crypto,
              keyManager: km,
            );
            final SyncEngine engine = ref.read(syncEngineProvider);
            onMutation = engine.triggerSyncDebounced;
          }
        } catch (_) {
          repo = null;
        }
      }

      return PlaceAliasStore(
        repository: repo,
        prefs: prefs,
        onMutation: onMutation,
      );
    });
