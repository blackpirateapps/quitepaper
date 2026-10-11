import 'package:drift/drift.dart';

/// Local store for the journal Places merge/rename/unmerge map (§2.3), modeled
/// as a per-alias synced, encrypted, crypto-blind collection (cloned from the
/// tag collection pattern).
///
/// Unlike the local `tags` table (which keeps plaintext name/icon/color),
/// place-alias rows store ONLY ciphertext locally: the `{matchKey,
/// canonicalKey, displayName}` payload lives inside [contentCiphertext] /
/// [contentNonce]. The row [id] is a deterministic, opaque keyed hash of the
/// normalized match key (`HMAC-SHA256(masterKey, "placealias:"+matchKey)`), so
/// every device derives the SAME id for the same alias without ever leaking the
/// place name to the server.
@DataClassName('PlaceAliasEntity')
class PlaceAliasesTable extends Table {
  @override
  String get tableName => 'place_aliases';

  /// Deterministic opaque id = HMAC-SHA256(masterKey, "placealias:"+matchKey).
  TextColumn get id => text()();

  /// Encrypted `{matchKey, canonicalKey, displayName}` payload (base64).
  TextColumn get contentCiphertext => text().withDefault(const Constant(''))();

  /// XChaCha20 nonce for [contentCiphertext] (base64).
  TextColumn get contentNonce => text().withDefault(const Constant(''))();

  IntColumn get contentVersion => integer().withDefault(const Constant(1))();
  IntColumn get encryptionKeyVersion =>
      integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  // Sync bookkeeping (identical shape to tags_table.dart).
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
