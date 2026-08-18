import 'package:drift/drift.dart';

@DataClassName('SyncMetadataEntity')
class SyncMetadataTable extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
