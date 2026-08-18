import 'package:drift/drift.dart';

@DataClassName('SyncQueueEntity')
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get operation => text()(); // 'upsert' | 'delete'
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
