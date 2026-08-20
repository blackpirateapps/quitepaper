import 'package:drift/drift.dart';

@DataClassName('DocumentEntity')
class DocumentsTable extends Table {
  @override
  String get tableName => 'documents';

  /// Canonical UUID primary key
  TextColumn get id => text()();

  /// Associated note ID (can be null for unassigned documents)
  TextColumn get noteId => text().nullable()();

  /// Document title (display name, e.g. 'Scanned Document')
  TextColumn get title =>
      text().withDefault(const Constant('Scanned Document'))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Canonical MIME type (strictly 'application/pdf')
  TextColumn get mimeType =>
      text().withDefault(const Constant('application/pdf'))();

  /// Plaintext PDF byte size in bytes
  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// Total page count in PDF
  IntColumn get pageCount => integer().withDefault(const Constant(1))();

  /// Plaintext SHA-256 hash of canonical PDF bytes
  TextColumn get sha256 => text().withDefault(const Constant(''))();

  /// Key version used to encrypt this document
  IntColumn get encryptionKeyVersion =>
      integer().withDefault(const Constant(1))();

  /// Whether local changes need synchronization
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  /// Whether document is tombstoned/deleted
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Timestamp when deletion occurred
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Cloud revision assigned by control plane
  IntColumn get serverRevision =>
      integer().withDefault(const Constant(0))();

  /// Timestamp of last successful metadata sync
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Lifecycle state: 'local_only', 'upload_pending', 'uploading', 'uploaded', 'failed', 'synced'
  TextColumn get uploadState =>
      text().withDefault(const Constant('local_only'))();

  /// Cloudinary public ID
  TextColumn get cloudPublicId => text().nullable()();

  /// Cloudinary delivery URL
  TextColumn get cloudUrl => text().nullable()();

  /// Local app-private encrypted file path (.qpd)
  TextColumn get localPath => text().nullable()();

  /// Optional local path to cached first-page thumbnail
  TextColumn get thumbnailPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
