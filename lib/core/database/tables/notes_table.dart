import 'package:drift/drift.dart';

@DataClassName('NoteEntity')
class NotesTable extends Table {
  @override
  String get tableName => 'notes';

  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isTrashed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get journalDate => text().nullable()();
  TextColumn get shareId => text().nullable()();
  TextColumn get shareUrl => text().nullable()();

  /// Tags this note is pinned WITHIN, as a JSON array of normalized tag names.
  /// Null/empty means "not pinned in any tag". Distinct from [isPinned], which
  /// is the global pin (pinned everywhere). Per-tag pins ride inside the
  /// encrypted note content on sync, so the server never sees them.
  TextColumn get pinnedTags => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
