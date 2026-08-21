import 'package:drift/drift.dart';
import 'notes_table.dart';

@DataClassName('NoteVersionEntity')
class NoteVersionsTable extends Table {
  @override
  String get tableName => 'note_versions';

  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(NotesTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get versionNumber => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get charCount => integer().withDefault(const Constant(0))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  TextColumn get deltaSummary => text().nullable()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get baseRevision => integer().nullable()();
  IntColumn get localParentRevision => integer().nullable()();
  IntColumn get remoteParentRevision => integer().nullable()();
  TextColumn get mergeType => text().nullable()();
  TextColumn get resolutionSummary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
