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

    test('empty query returns all existing tags ranked by pinned, note count, and name', () {
      final results = service.searchTags(query: '', existingTags: allTags);
      expect(results.length, 4);
      expect(results[0].name, 'work'); // Pinned
      expect(results[1].name, 'pineapple'); // noteCount 10
      expect(results[2].name, 'apple'); // noteCount 5
      expect(results[3].name, 'application'); // noteCount 1
    });

    test('invalid punctuation query returns empty list', () {
      final results = service.searchTags(query: '???', existingTags: allTags);
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

    test('offers a create candidate for a missing valid nested path', () {
      final results = service.searchTags(
        query: '#Work/Projects/Alpha',
        existingTags: allTags,
      );

      expect(results, hasLength(1));
      expect(results.single.name, equals('work/projects/alpha'));
      expect(results.single.isNew, isTrue);
    });

    test('existing nested tags win over the synthetic create candidate', () {
      final nested = Tag(
        id: 'nested',
        name: 'work/projects',
        createdAt: now,
        updatedAt: now,
        noteCount: 3,
      );
      final results = service.searchTags(
        query: 'work/projects',
        existingTags: [...allTags, nested],
      );

      expect(results.first.name, equals('work/projects'));
      expect(results.first.isNew, isFalse);
      expect(results.where((tag) => tag.isNew), isEmpty);
    });

    test('flat unknown queries keep the legacy no-create behavior', () {
      final results = service.searchTags(
        query: 'brand-new-flat-tag',
        existingTags: allTags,
      );

      expect(results, isEmpty);
    });

    test('invalid nested path shapes do not offer a create candidate', () {
      for (final query in ['work//projects', 'work/', '/work', '123/projects', 'work/-projects']) {
        final results = service.searchTags(query: query, existingTags: allTags);
        expect(results.where((tag) => tag.isNew), isEmpty, reason: query);
      }
    });

    test('offers a create candidate for valid nested path with numeric segment', () {
      final results = service.searchTags(query: 'journal/2026', existingTags: allTags);
      expect(results.where((tag) => tag.isNew), isNotEmpty);
      expect(results.firstWhere((tag) => tag.isNew).name, equals('journal/2026'));
    });

    test('nested path queries match existing descendants', () {
      final parent = Tag(
        id: 'nested-parent',
        name: 'work/projects',
        createdAt: now,
        updatedAt: now,
        noteCount: 2,
      );
      final nested = Tag(
        id: 'nested-child',
        name: 'work/projects/alpha',
        createdAt: now,
        updatedAt: now,
        noteCount: 1,
      );
      final results = service.searchTags(
        query: 'work/projects',
        existingTags: [...allTags, parent, nested],
      );

      expect(results.map((tag) => tag.name), contains('work/projects/alpha'));
      expect(results.first.name, equals('work/projects'));
      expect(results.first.isNew, isFalse);
    });
  });
}
