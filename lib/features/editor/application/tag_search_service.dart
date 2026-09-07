import '../../../core/utils/tag_parser.dart';
import '../../tags/domain/tag_model.dart';

/// Candidate item representing a tag match for autocomplete suggestions.
class TagCandidateItem {
  const TagCandidateItem({
    required this.tag,
    required this.score,
  });

  final Tag tag;
  final int score;
}

/// Service that searches and ranks tag candidates for hashtag autocomplete.
class TagSearchService {
  const TagSearchService();

  /// Searches and ranks [existingTags] plus any inline tags found in [currentNoteContent]
  /// against [query].
  List<Tag> searchTags({
    required String query,
    required List<Tag> existingTags,
    String? currentNoteContent,
    int limit = 15,
  }) {
    final cleanQuery = TagParser.normalizeTag(query);
    if (cleanQuery.isEmpty) {
      return const [];
    }

    // Collect all tags keyed by lower-case name
    final tagMap = <String, Tag>{};
    for (final tag in existingTags) {
      final key = tag.name.toLowerCase();
      tagMap[key] = tag;
    }

    // Also include any inline tags found in current note content
    if (currentNoteContent != null && currentNoteContent.isNotEmpty) {
      final noteTags = TagParser.extractTags(currentNoteContent);
      final now = DateTime.now();
      for (final nt in noteTags) {
        final key = nt.toLowerCase();
        if (!tagMap.containsKey(key)) {
          tagMap[key] = Tag(
            id: 'inline_$key',
            name: nt,
            createdAt: now,
            updatedAt: now,
            noteCount: 1,
          );
        }
      }
    }

    final scored = <TagCandidateItem>[];

    for (final tag in tagMap.values) {
      final lowerName = tag.name.toLowerCase();
      int score = 0;

      if (lowerName == cleanQuery) {
        score = 1000;
      } else if (lowerName.startsWith(cleanQuery)) {
        score = 800;
      } else if (lowerName.contains(cleanQuery)) {
        score = 400;
      }

      if (score > 0) {
        scored.add(TagCandidateItem(tag: tag, score: score));
      }
    }

    // Sort by score DESC, isPinned DESC, noteCount DESC, name ASC
    scored.sort((a, b) {
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;

      if (a.tag.isPinned != b.tag.isPinned) {
        return a.tag.isPinned ? -1 : 1;
      }

      final countComp = b.tag.noteCount.compareTo(a.tag.noteCount);
      if (countComp != 0) return countComp;

      return a.tag.name.toLowerCase().compareTo(b.tag.name.toLowerCase());
    });

    final results = scored.take(limit).map((c) => c.tag).toList();
    return results;
  }
}
