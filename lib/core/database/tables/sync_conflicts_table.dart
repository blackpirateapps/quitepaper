import 'package:drift/drift.dart';
import 'notes_table.dart';

@DataClassName('SyncConflictEntity')
class SyncConflictsTable extends Table {
  @override
  String get tableName => 'sync_conflicts';

  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(NotesTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get baseRevision => integer().withDefault(const Constant(0))();
  IntColumn get localRevision => integer().withDefault(const Constant(0))();
  IntColumn get remoteRevision => integer().withDefault(const Constant(0))();
  TextColumn get conflictType => text().withDefault(const Constant('content'))();
  TextColumn get state => text().withDefault(const Constant('detected'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  IntColumn get resolutionRevision => integer().nullable()();
  TextColumn get resolutionType => text().nullable()();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
