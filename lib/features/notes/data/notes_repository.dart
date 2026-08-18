import '../../../core/database/app_database.dart';
import '../domain/note_model.dart';

abstract class NotesRepository {
  Stream<List<Note>> watchNotes({
    bool isArchived = false,
    bool isTrashed = false,
    bool? isPinned,
    String? filterTag,
    String? searchQuery,
  });
  Future<Note?> getNoteById(String id);
  Stream<Note?> watchNoteById(String id);
  Future<void> saveNote(Note note);
  Future<void> setPinned(String id, bool isPinned);
  Future<void> archiveNote(String id);
  Future<void> unarchiveNote(String id);
  Future<void> trashNote(String id);
  Future<void> restoreFromTrash(String id);
  Future<void> deletePermanently(String id);
  Future<void> emptyTrash();
  Future<void> archiveNotes(List<String> ids);
  Future<void> unarchiveNotes(List<String> ids);
  Future<void> trashNotes(List<String> ids);
  Future<void> restoreNotes(List<String> ids);
  Future<void> deletePermanentlyBatch(List<String> ids);
  Future<void> deleteNote(String id);
  Stream<List<TagWithCount>> watchTags();
  Future<List<String>> getAllTagNames();
  Stream<int> watchActiveNotesCount();
  Stream<int> watchPinnedNotesCount();
  Stream<int> watchArchivedNotesCount();
  Stream<int> watchTrashedNotesCount();
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
      isArchived: entity.note.isArchived,
      isTrashed: entity.note.isTrashed,
      deletedAt: entity.note.deletedAt,
      tags: entity.tagNames,
    );
  }

  @override
  Stream<List<Note>> watchNotes({
    bool isArchived = false,
    bool isTrashed = false,
    bool? isPinned,
    String? filterTag,
    String? searchQuery,
  }) {
    return _db
        .watchNotes(
          isArchived: isArchived,
          isTrashed: isTrashed,
          isPinned: isPinned,
          filterTag: filterTag,
          searchQuery: searchQuery,
        )
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
      isArchived: note.isArchived,
      isTrashed: note.isTrashed,
      deletedAt: note.deletedAt,
      tags: note.tags.isNotEmpty ? note.tags : null,
    );
  }

  @override
  Future<void> setPinned(String id, bool isPinned) async {
    await _db.setPinned(id, isPinned);
  }

  @override
  Future<void> archiveNote(String id) async {
    await _db.archiveNote(id);
  }

  @override
  Future<void> unarchiveNote(String id) async {
    await _db.unarchiveNote(id);
  }

  @override
  Future<void> trashNote(String id) async {
    await _db.trashNote(id);
  }

  @override
  Future<void> restoreFromTrash(String id) async {
    await _db.restoreFromTrash(id);
  }

  @override
  Future<void> deletePermanently(String id) async {
    await _db.deletePermanently(id);
  }

  @override
  Future<void> emptyTrash() async {
    await _db.emptyTrash();
  }

  @override
  Future<void> archiveNotes(List<String> ids) async {
    await _db.archiveNotes(ids);
  }

  @override
  Future<void> unarchiveNotes(List<String> ids) async {
    await _db.unarchiveNotes(ids);
  }

  @override
  Future<void> trashNotes(List<String> ids) async {
    await _db.trashNotes(ids);
  }

  @override
  Future<void> restoreNotes(List<String> ids) async {
    await _db.restoreNotes(ids);
  }

  @override
  Future<void> deletePermanentlyBatch(List<String> ids) async {
    await _db.deletePermanentlyBatch(ids);
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

  @override
  Stream<int> watchActiveNotesCount() {
    return _db.watchActiveNotesCount();
  }

  @override
  Stream<int> watchPinnedNotesCount() {
    return _db.watchPinnedNotesCount();
  }

  @override
  Stream<int> watchArchivedNotesCount() {
    return _db.watchArchivedNotesCount();
  }

  @override
  Stream<int> watchTrashedNotesCount() {
    return _db.watchTrashedNotesCount();
  }
}
