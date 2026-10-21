import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late TagService service;
  int mutationCallCount = 0;

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftNotesRepository(db);
    mutationCallCount = 0;
    service = TagService(
      repo,
      onTagMutation: () {
        mutationCallCount++;
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TagService onTagMutation trigger tests', () {
    test('createTag triggers onTagMutation', () async {
      await service.createTag('journal', icon: 'book', color: 'indigo');
      expect(mutationCallCount, equals(1));
    });

    test('renameTag triggers onTagMutation', () async {
      final tag = await service.createTag('old-name');
      mutationCallCount = 0;

      await service.renameTag(tag.id, 'new-name');
      expect(mutationCallCount, equals(1));
    });

    test('deleteTag triggers onTagMutation', () async {
      final tag = await service.createTag('to-delete');
      mutationCallCount = 0;

      await service.deleteTag(tag.id);
      expect(mutationCallCount, equals(1));
    });

    test('mergeTags triggers onTagMutation', () async {
      final tag1 = await service.createTag('source');
      final tag2 = await service.createTag('dest');
      mutationCallCount = 0;

      await service.mergeTags(tag1.id, tag2.id);
      expect(mutationCallCount, equals(1));
    });

    test('pinTag triggers onTagMutation', () async {
      final tag = await service.createTag('pinnable');
      mutationCallCount = 0;

      await service.pinTag(tag.id, true);
      expect(mutationCallCount, equals(1));
    });

    test('reorderPinnedTags triggers onTagMutation', () async {
      final tag1 = await service.createTag('p1', isPinned: true);
      final tag2 = await service.createTag('p2', isPinned: true);
      mutationCallCount = 0;

      await service.reorderPinnedTags([tag2.id, tag1.id]);
      expect(mutationCallCount, equals(1));
    });

    test('setTagIcon triggers onTagMutation', () async {
      final tag = await service.createTag('icon-test');
      mutationCallCount = 0;

      await service.setTagIcon(tag.id, 'sparkle');
      expect(mutationCallCount, equals(1));

      await service.setTagIcon(tag.id, null);
      expect(mutationCallCount, equals(2));
    });

    test('setTagColor triggers onTagMutation', () async {
      final tag = await service.createTag('color-test');
      mutationCallCount = 0;

      await service.setTagColor(tag.id, 'ruby');
      expect(mutationCallCount, equals(1));

      await service.setTagColor(tag.id, null);
      expect(mutationCallCount, equals(2));
    });
  });
}
