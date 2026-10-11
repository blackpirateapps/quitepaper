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
          map[pt.matchKey] =
              PlaceAlias(canonicalKey: pt.canonicalKey, displayName: pt.displayName);
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
    if (key == null) return;
    final id =
        cryptoService.computePlaceAliasId(matchKey: matchKey, masterKeyBytes: key);
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
    if (key == null) return;
    final id =
        cryptoService.computePlaceAliasId(matchKey: matchKey, masterKeyBytes: key);
    await database.tombstoneLocalPlaceAlias(id);
  }

  /// One-time import of the legacy device-local SharedPreferences alias map
  /// into the DB (marking rows dirty so they sync). Guarded by a persistent
  /// flag so existing users' merges carry over exactly once.
  Future<void> migrateFromPrefs(Map<String, PlaceAlias> legacy) async {
    final done = await database.getSyncMetadata('place_alias_migrated');
    if (done == 'true') return;
    for (final entry in legacy.entries) {
      await put(entry.key, entry.value);
    }
    await database.setSyncMetadata('place_alias_migrated', 'true');
  }
}

// PLACEHOLDER_STORE

/// Reversible merge/alias store for the Places surface (§2.3).
///
/// Exposes the SAME `Map<String, PlaceAlias>` state shape and the SAME four
/// mutation signatures as before, so [PlaceGroupingService] and the Places UI
/// are untouched. Internally it now persists to the synced, encrypted
/// `place_aliases` collection (see [PlaceAliasRepository]) when the vault is
/// unlocked, and falls back to the legacy device-local SharedPreferences store
/// otherwise (graceful degradation; no data loss while locked).
///
/// Mutations update the in-memory map synchronously (so the UI reacts
/// instantly), then write through to the DB (marking rows dirty) and request a
/// debounced sync so merges propagate across devices promptly. A live DB watch
/// keeps the map convergent with remote pulls.
class PlaceAliasStore extends StateNotifier<Map<String, PlaceAlias>> {
  PlaceAliasStore({
    PlaceAliasRepository? repository,
    SharedPreferences? prefs,
    void Function()? onMutation,
  })  : _repo = repository,
        _prefs = prefs,
        _syncTrigger = onMutation,
        super(repository == null ? _loadPrefs(prefs) : const {}) {
    _init();
  }

  final PlaceAliasRepository? _repo;
  final SharedPreferences? _prefs;
  final void Function()? _syncTrigger;
  StreamSubscription<List<PlaceAliasEntity>>? _sub;

  /// Legacy single SharedPreferences key holding the JSON-encoded alias map.
  static const String storageKey = 'journal_place_aliases';

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return; // legacy prefs-only path
    try {
      if (repo.isUnlocked) {
        await repo.migrateFromPrefs(_loadPrefs(_prefs));
      }
      _sub = repo.watchRows().listen((rows) async {
        if (!repo.isUnlocked) return;
        final map = await repo.decodeRows(rows);
        if (mounted) state = map;
      });
    } catch (_) {
      // DB/crypto unavailable → stay with whatever (empty) state we have.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Folds [matchKeys] into one place: each key is pointed at [canonicalKey]
  /// with the shared [displayName]. The canonical key is also mapped to itself
  /// so entries that already produce it adopt the chosen display name.
  void merge(
    List<String> matchKeys, {
    required String canonicalKey,
    required String displayName,
  }) {
    final alias = PlaceAlias(canonicalKey: canonicalKey, displayName: displayName);
    final next = Map<String, PlaceAlias>.of(state);
    final keys = <String>{...matchKeys, canonicalKey};
    for (final key in keys) {
      next[key] = alias;
    }
    state = next;
    _persist(() async {
      for (final key in keys) {
        await _repo!.put(key, alias);
      }
    });
  }

  /// Renames a merged place: updates [displayName] for every entry that points
  /// at [canonicalKey], and ensures the canonical key maps to itself.
  void rename({
    required String canonicalKey,
    required String displayName,
  }) {
    final alias = PlaceAlias(canonicalKey: canonicalKey, displayName: displayName);
    final affected = <String>{canonicalKey};
    final next = Map<String, PlaceAlias>.of(state);
    next.updateAll((key, existing) {
      if (existing.canonicalKey == canonicalKey) {
        affected.add(key);
        return alias;
      }
      return existing;
    });
    next[canonicalKey] = alias;
    state = next;
    _persist(() async {
      for (final key in affected) {
        await _repo!.put(key, alias);
      }
    });
  }

  /// Removes the alias entry for [matchKey], restoring it to its own group
  /// (reversible unmerge). No-op when the key is not aliased. Creates a
  /// tombstone so the removal propagates to other devices.
  void unmerge(String matchKey) {
    if (!state.containsKey(matchKey)) return;
    state = Map<String, PlaceAlias>.of(state)..remove(matchKey);
    _persist(() async {
      await _repo!.remove(matchKey);
    });
  }

  /// Fully reverses a merge: removes every alias entry pointing at
  /// [canonicalKey] (including the canonical self-map). Tombstones each removed
  /// row so the unmerge propagates. No-op when nothing maps to [canonicalKey].
  void unmergeCanonical(String canonicalKey) {
    final toRemove = <String>[
      for (final e in state.entries)
        if (e.value.canonicalKey == canonicalKey) e.key,
    ];
    if (toRemove.isEmpty) return;
    state = Map<String, PlaceAlias>.of(state)
      ..removeWhere((_, alias) => alias.canonicalKey == canonicalKey);
    _persist(() async {
      for (final key in toRemove) {
        await _repo!.remove(key);
      }
    });
  }

  /// Routes a mutation's persistence: DB write-through + sync trigger when a
  /// repository is available (unlocked vault), else the legacy prefs write.
  void _persist(Future<void> Function() dbOp) {
    final repo = _repo;
    if (repo != null && repo.isUnlocked) {
      unawaited(() async {
        try {
          await dbOp();
        } catch (_) {
          // Swallow write errors; the row stays as-is and retries next cycle.
        }
        _syncTrigger?.call();
      }());
    } else {
      _persistPrefs();
    }
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
            result[key] =
                PlaceAlias(canonicalKey: canonical, displayName: display);
          }
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  void _persistPrefs() {
    final prefs = _prefs;
    if (prefs == null) return; // in-memory only (e.g. tests without prefs)
    final map = <String, Map<String, String>>{
      for (final entry in state.entries)
        entry.key: {
          'canonicalKey': entry.value.canonicalKey,
          'displayName': entry.value.displayName,
        },
    };
    unawaited(prefs.setString(storageKey, jsonEncode(map)));
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

  return PlaceAliasStore(repository: repo, prefs: prefs, onMutation: onMutation);
});

