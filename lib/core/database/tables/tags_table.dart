import 'package:drift/drift.dart';

@DataClassName('TagEntity')
class TagsTable extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}
