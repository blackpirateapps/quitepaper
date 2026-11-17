import '../../../core/database/app_database.dart';
import '../domain/note_model.dart';

/// Complete domain snapshot shared by full reads and batch-hydrated list pages.
Note mapNoteEntity(NoteEntity entity, {required List<String> tags}) => Note(
  id: entity.id,
  title: entity.title,
  content: entity.content,
  createdAt: entity.createdAt,
  updatedAt: entity.updatedAt,
  isPinned: entity.isPinned,
  isArchived: entity.isArchived,
  isTrashed: entity.isTrashed,
  deletedAt: entity.deletedAt,
  tags: tags,
  pinnedTags: decodePinnedTagsJson(entity.pinnedTags),
  journalDate: entity.journalDate,
  shareId: entity.shareId,
  shareUrl: entity.shareUrl,
);
