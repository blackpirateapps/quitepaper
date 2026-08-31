import '../database/app_database.dart';
import '../search/search_index_projection.dart';
import 'quiet_paper_uri.dart';
import 'resource_resolver.dart';

/// Concrete local implementation of [NoteResolver] resolving `qp://note/<UUID>` against the SQLite database.
class LocalNoteResolver implements NoteResolver {
  const LocalNoteResolver(this._db);

  final AppDatabase _db;

  @override
  Future<ResourceResolution<ResolvedNoteInfo>> resolveNote(String noteId) async {
    final uri = QuietPaperUri.note(noteId);
    if (!QuietPaperUri.isValidUuid(noteId)) {
      return ResourceResolution.missing(uri, 'Invalid note identifier');
    }

    final noteWithTags = await _db.getNoteWithTags(noteId);
    if (noteWithTags == null) {
      return ResourceResolution.missing(uri, 'This note is no longer available.');
    }

    final note = noteWithTags.note;
    final isLocked = SearchIndexProjection.isPasswordProtected(note.content);

    return ResourceResolution.available(
      uri,
      ResolvedNoteInfo(
        noteId: note.id,
        title: note.title.trim().isNotEmpty ? note.title.trim() : 'Untitled',
        isArchived: note.isArchived,
        isTrashed: note.isTrashed,
        isLocked: isLocked,
      ),
    );
  }
}
