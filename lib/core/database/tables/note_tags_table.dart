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

  /// Denormalized cache: whether this note is pinned within this specific tag.
  /// Authoritative source is `notes.pinnedTags`; this column is rebuilt from it
  /// on every save and kept in sync by `setPinnedInTag`, so tag-scoped pins can
  /// be filtered/ordered with an indexable join instead of parsing JSON.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
