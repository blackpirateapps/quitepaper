import 'package:drift/drift.dart';
import 'notes_table.dart';
import 'tags_table.dart';

@DataClassName('NoteTagEntity')
class NoteTagsTable extends Table {
  @override
  String get tableName => 'note_tags';

  TextColumn get noteId => text().references(
        NotesTable,
        #id,
        onDelete: KeyAction.cascade,
      )();

  TextColumn get tagId => text().references(
        TagsTable,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
