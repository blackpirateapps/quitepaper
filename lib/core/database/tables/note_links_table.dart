import 'package:drift/drift.dart';
import 'notes_table.dart';

@DataClassName('NoteLinkEntity')
class NoteLinksTable extends Table {
  @override
  String get tableName => 'note_links';

  /// Unique UUID for the link relationship record.
  TextColumn get id => text()();

  /// Source note containing the link. Cascades deletion when source note is removed.
  TextColumn get sourceNoteId => text().references(
        NotesTable,
        #id,
        onDelete: KeyAction.cascade,
      )();

  /// Target note ID being referenced (UUID).
  TextColumn get targetNoteId => text()();

  /// Display text rendered inside the link `[displayText](qp://note/<UUID>)`.
  TextColumn get displayText => text()();

  /// UTF-16 character offset of the link in the source Markdown text.
  IntColumn get sourceOffset => integer()();

  /// Timestamp when the link record was first derived.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Timestamp when the link record was last updated.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
