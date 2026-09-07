import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/tag_search_service.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';

void main() {
  group('TagSearchService Tests', () {
    const service = TagSearchService();
    final now = DateTime.now();

    final tagApple = Tag(
      id: '1',
      name: 'apple',
      createdAt: now,
      updatedAt: now,
      noteCount: 5,
    );
    final tagApplication = Tag(
      id: '2',
      name: 'application',
      createdAt: now,
      updatedAt: now,
      noteCount: 1,
    );
    final tagPineapple = Tag(
      id: '3',
      name: 'pineapple',
      createdAt: now,
      updatedAt: now,
      noteCount: 10,
    );
    final tagWork = Tag(
      id: '4',
      name: 'work',
      isPinned: true,
      createdAt: now,
      updatedAt: now,
      noteCount: 2,
    );

    final allTags = [tagApple, tagApplication, tagPineapple, tagWork];

    test('exact match scores higher than prefix and substring', () {
      final results = service.searchTags(query: 'apple', existingTags: allTags);
      expect(results.length, 2);
      expect(results[0].name, 'apple'); // Exact match
      expect(results[1].name, 'pineapple'); // Substring match
    });

    test('prefix match ranks ahead of substring match', () {
      final results = service.searchTags(query: 'app', existingTags: allTags);
      expect(results.length, 3);
      // Both apple and application start with app
      expect(results[0].name, 'apple'); // Higher noteCount
      expect(results[1].name, 'application');
      expect(results[2].name, 'pineapple'); // Substring match
    });

    test('empty or invalid query returns empty list', () {
      final results = service.searchTags(query: '', existingTags: allTags);
      expect(results, isEmpty);
    });

    test('incorporates inline tags from note content', () {
      final results = service.searchTags(
        query: 'cook',
        existingTags: allTags,
        currentNoteContent: 'Some recipe with #cooking and #food',
      );
      expect(results.length, 1);
      expect(results[0].name, 'cooking');
    });
  });
}
