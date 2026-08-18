import '../../../core/database/app_database.dart';
import '../domain/note_model.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchNotes({String? filterTag, String? searchQuery});
  Future<Note?> getNoteById(String id);
  Stream<Note?> watchNoteById(String id);
  Future<void> saveNote(Note note);
  Future<void> setPinned(String id, bool isPinned);
  Future<void> deleteNote(String id);
  Stream<List<TagWithCount>> watchTags();
  Future<List<String>> getAllTagNames();
}

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(this._db);

  final AppDatabase _db;

  Note _mapToDomain(NoteWithTags entity) {
    return Note(
      id: entity.note.id,
      title: entity.note.title,
      content: entity.note.content,
      createdAt: entity.note.createdAt,
      updatedAt: entity.note.updatedAt,
      isPinned: entity.note.isPinned,
      tags: entity.tagNames,
    );
  }

  @override
  Stream<List<Note>> watchNotes({String? filterTag, String? searchQuery}) {
    return _db
        .watchNotes(filterTag: filterTag, searchQuery: searchQuery)
        .map((list) => list.map(_mapToDomain).toList());
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final result = await _db.getNoteWithTags(id);
    return result != null ? _mapToDomain(result) : null;
  }

  @override
  Stream<Note?> watchNoteById(String id) {
    return _db.watchNoteWithTags(id).map((res) => res != null ? _mapToDomain(res) : null);
  }

  @override
  Future<void> saveNote(Note note) async {
    await _db.saveNote(
      id: note.id,
      title: note.title,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      isPinned: note.isPinned,
      tags: note.tags.isNotEmpty ? note.tags : null,
    );
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    await _db.setPinned(id, isPinned);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _db.deleteNote(id);
  }

  @override
  Stream<List<TagWithCount>> watchTags() {
    return _db.watchAllTagsWithCount();
  }

  @override
  Future<List<String>> getAllTagNames() {
    return _db.getAllTagNames();
  }
}
