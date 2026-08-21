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

  @override
  Set<Column> get primaryKey => {attachmentId, pageNumber};
}
