import 'dart:convert';
import '../../../core/crypto/key_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ocr/ocr_crypto.dart';
import '../domain/note_model.dart';
import '../domain/note_version_model.dart';
import '../domain/notes_query.dart';
import 'notes_query_executor.dart';

abstract class NotesRepository {
  Future<NotesQueryResult> executeNotesQuery(NotesQuery query);
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
  Future<TagEntity?> getTagById(String id);
  Future<TagEntity?> getTagByName(String name);
  Future<TagEntity> createTag(String name, {String? icon, String? color, bool isPinned = false});
  Future<void> renameTag(String tagId, String newName);
  Future<void> deleteTag(String tagId);
  Future<void> mergeTags(String sourceTagId, String destinationTagId);
  Future<void> pinTag(String tagId, bool isPinned);
  Future<void> reorderPinnedTags(List<String> orderedTagIds);
  Future<void> setTagIcon(String tagId, String? icon);
  Future<void> setTagColor(String tagId, String? color);
  Stream<int> watchActiveNotesCount();
  Stream<int> watchPinnedNotesCount();
  Stream<int> watchArchivedNotesCount();
  Stream<int> watchTrashedNotesCount();
  Future<void> saveVersion(NoteVersion version);
  Future<List<NoteVersion>> getVersions(String noteId, {int limit = 50});
  Stream<List<NoteVersion>> watchVersions(String noteId, {int limit = 50});
  Future<NoteVersion?> getLatestVersion(String noteId);
  Future<int> getNextVersionNumber(String noteId);
  Future<void> pruneVersions(String noteId, {int maxKeep = 50});
}

class DriftNotesRepository implements NotesRepository {
  DriftNotesRepository(
    this._db, [
    this._keyManager,
    this._ocrCrypto,
  ]);

  final AppDatabase _db;
  final KeyManager? _keyManager;
  final OcrCrypto? _ocrCrypto;
  late final NotesQueryExecutor _queryExecutor = NotesQueryExecutor(_db);

  @override
  Future<NotesQueryResult> executeNotesQuery(NotesQuery query) {
    return _queryExecutor.execute(query);
  }

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
    if (searchQuery == null ||
        searchQuery.trim().isEmpty ||
        _keyManager == null ||
        !_keyManager.isUnlocked) {
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

    return Stream.fromFuture(_getNoteIdsMatchingOcr(searchQuery.trim()))
        .asyncExpand((ocrNoteIds) {
      return _db
          .watchNotes(
            isArchived: isArchived,
            isTrashed: isTrashed,
            isPinned: isPinned,
            filterTag: filterTag,
            searchQuery: searchQuery,
            matchingNoteIds: ocrNoteIds,
          )
          .map((list) => list.map(_mapToDomain).toList());
    });
  }

  Future<List<String>> _getNoteIdsMatchingOcr(String query) async {
    if (_keyManager == null || !_keyManager.isUnlocked) return const [];
    final clean = query.toLowerCase();
    if (clean.isEmpty) return const [];

    try {
      final masterKey = _keyManager.getMasterKey();
      final crypto = _ocrCrypto ?? OcrCrypto();
      final matchingNoteIds = <String>{};

      // 1. Check Document OCR pages (PDFs)
      final docOcrPages = await _db.getAllDocumentOcrPages();
      for (final page in docOcrPages) {
        try {
          final encryptedBytes = base64Decode(page.encryptedPayload);
          final ocrDoc = await crypto.decryptOcrDocument(
            encryptedEnvelopeBytes: encryptedBytes,
            masterKeyBytes: masterKey,
            documentId: page.documentId,
          );
          for (final p in ocrDoc.pages) {
            if (p.plainText.toLowerCase().contains(clean)) {
              final doc = await _db.getDocument(page.documentId);
              if (doc?.noteId != null && doc!.noteId!.isNotEmpty) {
                matchingNoteIds.add(doc.noteId!);
              }
              break;
            }
          }
        } catch (_) {}
      }

      // 2. Check Attachment OCR pages (Images)
      final attOcrPages = await _db.getAllAttachmentOcrPages();
      for (final page in attOcrPages) {
        try {
          final encryptedBytes = base64Decode(page.encryptedPayload);
          final ocrDoc = await crypto.decryptOcrDocument(
            encryptedEnvelopeBytes: encryptedBytes,
            masterKeyBytes: masterKey,
            documentId: page.attachmentId,
          );
          for (final p in ocrDoc.pages) {
            if (p.plainText.toLowerCase().contains(clean)) {
              final att = await _db.getAttachment(page.attachmentId);
              if (att?.noteId != null && att!.noteId!.isNotEmpty) {
                matchingNoteIds.add(att.noteId!);
              }
              break;
            }
          }
        } catch (_) {}
      }

      return matchingNoteIds.toList();
    } catch (_) {
      return const [];
    }
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
      tags: note.tags,
    );

    // Sync any renamed document titles referenced inside the note's markdown body
    await _syncDocumentTitlesFromMarkdown(note.id, note.content);
  }

  Future<void> _syncDocumentTitlesFromMarkdown(String noteId, String content) async {
    if (!content.contains('qp://document/')) return;

    final matches = RegExp(
      r'\[([^\]\n]+)\]\(qp:\/\/document\/([^)\s?]+)',
    ).allMatches(content);

    for (final match in matches) {
      final docTitle = match.group(1)?.trim();
      final docId = match.group(2);
      if (docTitle != null && docTitle.isNotEmpty && docId != null) {
        final existingDoc = await _db.getDocument(docId);
        if (existingDoc != null && existingDoc.title != docTitle) {
          await _db.updateDocumentTitle(docId, docTitle);
        }
      }
    }
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
  Future<TagEntity?> getTagById(String id) {
    return _db.getTagById(id);
  }

  @override
  Future<TagEntity?> getTagByName(String name) {
    return _db.getTagByName(name);
  }

  @override
  Future<TagEntity> createTag(String name, {String? icon, String? color, bool isPinned = false}) {
    return _db.createTag(name, icon: icon, color: color, isPinned: isPinned);
  }

  @override
  Future<void> renameTag(String tagId, String newName) {
    return _db.renameTag(tagId, newName);
  }

  @override
  Future<void> deleteTag(String tagId) {
    return _db.deleteTag(tagId);
  }

  @override
  Future<void> mergeTags(String sourceTagId, String destinationTagId) {
    return _db.mergeTags(sourceTagId, destinationTagId);
  }

  @override
  Future<void> pinTag(String tagId, bool isPinned) {
    return _db.pinTag(tagId, isPinned);
  }

  @override
  Future<void> reorderPinnedTags(List<String> orderedTagIds) {
    return _db.reorderPinnedTags(orderedTagIds);
  }

  @override
  Future<void> setTagIcon(String tagId, String? icon) {
    return _db.setTagIcon(tagId, icon);
  }

  @override
  Future<void> setTagColor(String tagId, String? color) {
    return _db.setTagColor(tagId, color);
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

  NoteVersion _mapVersionToDomain(NoteVersionEntity entity) {
    List<String> tags = [];
    try {
      final decoded = jsonDecode(entity.tagsJson);
      if (decoded is List) {
        tags = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return NoteVersion(
      id: entity.id,
      noteId: entity.noteId,
      versionNumber: entity.versionNumber,
      title: entity.title,
      content: entity.content,
      tags: tags,
      createdAt: entity.createdAt,
      charCount: entity.charCount,
      wordCount: entity.wordCount,
      deltaSummary: entity.deltaSummary,
      serverRevision: entity.serverRevision,
      isDirty: entity.isDirty,
      syncedAt: entity.syncedAt,
    );
  }

  @override
  Future<void> saveVersion(NoteVersion version) async {
    await _db.saveNoteVersion(
      id: version.id,
      noteId: version.noteId,
      versionNumber: version.versionNumber,
      title: version.title,
      content: version.content,
      tagsJson: jsonEncode(version.tags),
      createdAt: version.createdAt,
      charCount: version.charCount,
      wordCount: version.wordCount,
      deltaSummary: version.deltaSummary,
      serverRevision: version.serverRevision,
      isDirty: version.isDirty,
      syncedAt: version.syncedAt,
    );
  }

  @override
  Future<List<NoteVersion>> getVersions(String noteId, {int limit = 50}) async {
    final list = await _db.getNoteVersions(noteId, limit: limit);
    return list.map(_mapVersionToDomain).toList();
  }

  @override
  Stream<List<NoteVersion>> watchVersions(String noteId, {int limit = 50}) {
    return _db
        .watchNoteVersions(noteId, limit: limit)
        .map((list) => list.map(_mapVersionToDomain).toList());
  }

  @override
  Future<NoteVersion?> getLatestVersion(String noteId) async {
    final entity = await _db.getLatestNoteVersion(noteId);
    return entity != null ? _mapVersionToDomain(entity) : null;
  }

  @override
  Future<int> getNextVersionNumber(String noteId) {
    return _db.getNextVersionNumber(noteId);
  }

  @override
  Future<void> pruneVersions(String noteId, {int maxKeep = 50}) {
    return _db.pruneOldNoteVersions(noteId, maxKeep: maxKeep);
  }
}
