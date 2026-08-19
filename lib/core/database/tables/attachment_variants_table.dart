import 'package:drift/drift.dart';

@DataClassName('AttachmentVariantEntity')
class AttachmentVariantsTable extends Table {
  @override
  String get tableName => 'attachment_variants';

  /// UUID primary key for the variant
  TextColumn get id => text()();

  /// Foreign key referencing parent attachment
  TextColumn get attachmentId => text()();

  /// Variant type: 'original', 'preview', 'thumbnail'
  TextColumn get variantType => text()();

  /// Plaintext byte size
  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// Pixel width
  IntColumn get width => integer().nullable()();

  /// Pixel height
  IntColumn get height => integer().nullable()();

  /// Local encrypted file path
  TextColumn get localPath => text().nullable()();

  /// Cloudinary public ID for variant
  TextColumn get cloudPublicId => text().nullable()();

  /// Cloudinary URL for variant
  TextColumn get cloudUrl => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
