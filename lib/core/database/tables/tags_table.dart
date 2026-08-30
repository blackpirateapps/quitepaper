import 'package:drift/drift.dart';

@DataClassName('TagEntity')
class TagsTable extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get pinnedOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
