import 'package:drift/drift.dart';

@DataClassName('DocumentOcrPageEntity')
class DocumentOcrPagesTable extends Table {
  @override
  String get tableName => 'document_ocr_pages';

  /// Document canonical UUID reference
  TextColumn get documentId => text()();

  /// 1-based page number
  IntColumn get pageNumber => integer()();

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
  Set<Column> get primaryKey => {documentId, pageNumber};
}
