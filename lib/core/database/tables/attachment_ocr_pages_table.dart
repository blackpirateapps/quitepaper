import 'package:drift/drift.dart';

@DataClassName('AttachmentOcrPageEntity')
class AttachmentOcrPagesTable extends Table {
  @override
  String get tableName => 'attachment_ocr_pages';

  /// Attachment canonical UUID reference
  TextColumn get attachmentId => text()();

  /// 1-based page number (defaults to 1 for images)
  IntColumn get pageNumber => integer().withDefault(const Constant(1))();

  /// Base64-encoded encrypted binary OCR envelope (QPOC)
  TextColumn get encryptedPayload => text()();

  /// OCR schema version (e.g. 1)
  IntColumn get ocrSchemaVersion =>
      integer().withDefault(const Constant(1))();

  /// Engine name used for recognition
  TextColumn get ocrEngine =>
      text().withDefault(const Constant('quietpaper_ocr_v1'))();

  /// Engine version used for recognition
  TextColumn get ocrEngineVersion =>
      text().withDefault(const Constant('1.0.0'))();

  /// Language code used during recognition (e.g. 'en')
  TextColumn get language =>
      text().withDefault(const Constant('en'))();

  /// Processing completion timestamp
  DateTimeColumn get processedAt => dateTime()();

  /// Server revision for optimistic sync; 0 until first synced
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Base revision for conflict detection on push
  IntColumn get baseRevision => integer().withDefault(const Constant(0))();

  /// Whether local changes await push to backend
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  /// Whether this OCR page is deleted
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Last local mutation timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {attachmentId, pageNumber};
}
