import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/tag_parser.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/tag_model.dart';

/// Service managing first-class tag domain operations.
class TagService {
  TagService(this._repository);

  final NotesRepository _repository;

  Future<Tag> createTag(
    String name, {
    String? icon,
    String? color,
    bool isPinned = false,
  }) async {
    final entity = await _repository.createTag(
      name,
      icon: icon,
      color: color,
      isPinned: isPinned,
    );
    return Tag(
      id: entity.id,
      name: entity.name,
      icon: entity.icon,
      color: entity.color,
      isPinned: entity.isPinned,
      pinnedOrder: entity.pinnedOrder,
      createdAt: entity.createdAt ?? DateTime.now(),
      updatedAt: entity.updatedAt ?? DateTime.now(),
    );
  }

  Future<void> renameTag(String tagId, String newName) {
    return _repository.renameTag(tagId, newName);
  }

  Future<void> deleteTag(String tagId) {
    return _repository.deleteTag(tagId);
  }

  Future<void> mergeTags(String sourceTagId, String destinationTagId) {
    return _repository.mergeTags(sourceTagId, destinationTagId);
  }

  Future<void> pinTag(String tagId, bool isPinned) {
    return _repository.pinTag(tagId, isPinned);
  }

  Future<void> reorderPinnedTags(List<String> orderedTagIds) {
    return _repository.reorderPinnedTags(orderedTagIds);
  }

  Future<void> setTagIcon(String tagId, String? icon) {
    return _repository.setTagIcon(tagId, icon);
  }

  Future<void> setTagColor(String tagId, String? color) {
    return _repository.setTagColor(tagId, color);
  }
}

/// Provider for the TagService.
final tagServiceProvider = Provider<TagService>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return TagService(repo);
});

/// Stream of all tags mapped to domain Tag objects.
final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchTags().map((items) {
    return items.map((item) {
      return Tag(
        id: item.tag.id,
        name: item.tag.name,
        icon: item.tag.icon,
        color: item.tag.color,
        isPinned: item.tag.isPinned,
        pinnedOrder: item.tag.pinnedOrder,
        createdAt: item.tag.createdAt ?? DateTime.now(),
        updatedAt: item.tag.updatedAt ?? DateTime.now(),
        noteCount: item.noteCount,
      );
    }).toList();
  });
});

/// Pinned tags ordered deterministically by pinnedOrder.
final pinnedTagsProvider = Provider<List<Tag>>((ref) {
  final tagsAsync = ref.watch(allTagsProvider);
  final allTags = tagsAsync.valueOrNull ?? [];
  final pinned = allTags.where((t) => t.isPinned).toList();
  pinned.sort((a, b) {
    final orderComp = a.pinnedOrder.compareTo(b.pinnedOrder);
    if (orderComp != 0) return orderComp;
    return a.name.compareTo(b.name);
  });
  return pinned;
});

/// Selected filter in Tag Browser.
final tagFilterProvider = StateProvider<TagFilter>((ref) => TagFilter.all);

/// Selected sort in Tag Browser.
final tagSortProvider = StateProvider<TagSort>((ref) => TagSort.name);

/// Search query within Tag Browser.
final tagSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered, searched, and sorted list of tags for the Tag Browser.
final filteredBrowserTagsProvider = Provider<AsyncValue<List<Tag>>>((ref) {
  final tagsAsync = ref.watch(allTagsProvider);
  final filter = ref.watch(tagFilterProvider);
  final sort = ref.watch(tagSortProvider);
  final query = ref.watch(tagSearchQueryProvider).trim().toLowerCase();

  return tagsAsync.whenData((allTags) {
    var result = List<Tag>.from(allTags);

    // 1. Search Query Filter
    if (query.isNotEmpty) {
      final cleanQuery = TagParser.normalizeTag(query);
      result = result.where((tag) {
        final lowerName = tag.name.toLowerCase();
        return lowerName.contains(query) || lowerName.contains(cleanQuery);
      }).toList();
    }

    // 2. Category Filter
    switch (filter) {
      case TagFilter.all:
        break;
      case TagFilter.pinned:
        result = result.where((t) => t.isPinned).toList();
        break;
      case TagFilter.hasIcon:
        result = result.where((t) => t.icon != null && t.icon!.isNotEmpty).toList();
        break;
      case TagFilter.hasColor:
        result = result.where((t) => t.color != null && t.color!.isNotEmpty).toList();
        break;
      case TagFilter.hasNotes:
        result = result.where((t) => t.noteCount > 0).toList();
        break;
      case TagFilter.unused:
        result = result.where((t) => t.noteCount == 0).toList();
        break;
    }

    // 3. Sorting
    switch (sort) {
      case TagSort.name:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case TagSort.noteCount:
        result.sort((a, b) {
          final countComp = b.noteCount.compareTo(a.noteCount);
          if (countComp != 0) return countComp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case TagSort.recentlyUsed:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case TagSort.recentlyCreated:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TagSort.custom:
        result.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          final orderComp = a.pinnedOrder.compareTo(b.pinnedOrder);
          if (orderComp != 0) return orderComp;
          return a.name.compareTo(b.name);
        });
        break;
    }

    return result;
  });
});

/// Stream of active notes associated with a specific tag name.
final tagNotesStreamProvider = StreamProvider.family<List<Note>, String>((ref, tagName) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchNotes(isArchived: false, isTrashed: false, filterTag: tagName);
});

/// Tag entity by stable ID.
final tagByIdProvider = Provider.family<Tag?, String>((ref, tagId) {
  final allTags = ref.watch(allTagsProvider).valueOrNull ?? [];
  for (final t in allTags) {
    if (t.id == tagId) return t;
  }
  return null;
});
