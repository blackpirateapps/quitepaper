import 'package:drift/drift.dart';

@DataClassName('QuickCaptureDraftEntity')
class QuickCaptureDraftsTable extends Table {
  @override
  String get tableName => 'quick_capture_drafts';

  TextColumn get id => text()();
  TextColumn get targetNoteId => text()();
  TextColumn get content => text()();
  TextColumn get source => text().withDefault(const Constant('widget'))();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get titleHint => text().nullable()();
  IntColumn get cursorPosition => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
