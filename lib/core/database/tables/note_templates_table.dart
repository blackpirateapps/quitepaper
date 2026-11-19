import 'package:drift/drift.dart';

@DataClassName('NoteTemplateEntity')
class NoteTemplatesTable extends Table {
  @override
  String get tableName => 'note_templates';
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get content => text()();
  TextColumn get storageFormat => text()();
  TextColumn get defaultTagsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TemplateFavoriteEntity')
class TemplateFavoritesTable extends Table {
  @override
  String get tableName => 'template_favorites';
  // No FK: the bundled catalog deliberately has no database rows.
  TextColumn get templateId => text()();
  @override
  Set<Column> get primaryKey => {templateId};
}
