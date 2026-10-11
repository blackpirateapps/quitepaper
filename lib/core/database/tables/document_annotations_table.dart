import 'package:drift/drift.dart';

/// Encrypted, per-page annotation sidecar for a document (spec §4.2).
///
/// Mirrors `document_ocr_pages`: one row holds all annotations for a single
/// page as a base64 `QPAN` envelope. Non-destructive — the original PDF bytes
/// are never touched. `revision` / `isDirty` drive crypto-blind sync (§9).
@DataClassName('DocumentAnnotationEntity')
class DocumentAnnotationsTable extends Table {
  @override
  String get tableName => 'document_annotations';

  /// Document canonical UUID reference.
  TextColumn get documentId => text()();

  /// 1-based page number (matches the OCR page table convention).
  IntColumn get pageNumber => integer()();

  /// Base64-encoded encrypted binary annotation envelope (QPAN).
  TextColumn get encryptedPayload => text()();

  /// Count of non-deleted annotations on the page (for badges, no decrypt).
  IntColumn get annotationCount => integer().withDefault(const Constant(0))();

  /// Server revision for optimistic sync; 0 until first synced.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Whether local changes await push to the backend.
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  /// Last local mutation timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {documentId, pageNumber};
}
