import 'package:drift/drift.dart';

@DataClassName('AttachmentEntity')
class AttachmentsTable extends Table {
  @override
  String get tableName => 'attachments';

  /// Canonical UUID primary key
  TextColumn get id => text()();

  /// Associated note ID (can be null for detached/unassigned attachments)
  TextColumn get noteId => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// MIME type (e.g. 'image/png', 'image/jpeg', 'image/webp')
  TextColumn get mimeType =>
      text().withDefault(const Constant('image/png'))();

  /// Plaintext byte size in bytes
  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// Image pixel width
  IntColumn get width => integer().nullable()();

  /// Image pixel height
  IntColumn get height => integer().nullable()();

  /// Plaintext SHA-256 hash
  TextColumn get sha256 => text().withDefault(const Constant(''))();

  /// Key version used to encrypt this attachment
  IntColumn get encryptionKeyVersion =>
      integer().withDefault(const Constant(1))();

  /// Whether local changes need synchronization
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  /// Whether attachment is tombstoned/deleted
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

  /// Local app-private encrypted file path
  TextColumn get localPath => text().nullable()();

  /// OCR processing state: 'not_requested', 'queued', 'processing', 'available', 'failed'
  TextColumn get ocrState =>
      text().withDefault(const Constant('not_requested'))();

  /// OCR language code: e.g. 'en'
  TextColumn get ocrLanguage =>
      text().withDefault(const Constant('en'))();

  @override
  Set<Column> get primaryKey => {id};
}
