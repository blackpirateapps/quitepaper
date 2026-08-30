import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Tag Operations', () {
    test('createTag creates a first-class tag with metadata and stable ID', () async {
      final tag = await db.createTag(
        'flutter',
        icon: 'code',
        color: 'coral',
        isPinned: true,
      );

      expect(tag.id, isNotEmpty);
      expect(tag.name, equals('flutter'));
      expect(tag.icon, equals('code'));
      expect(tag.color, equals('coral'));
      expect(tag.isPinned, isTrue);
      expect(tag.createdAt, isNotNull);
      expect(tag.updatedAt, isNotNull);

      // Stable identity: fetching again by name or ID returns the same tag entity
      final byId = await db.getTagById(tag.id);
      expect(byId?.id, equals(tag.id));
      expect(byId?.name, equals('flutter'));

      final byName = await db.getTagByName('flutter');
      expect(byName?.id, equals(tag.id));
    });

    test('createTag normalizes tag name and deduplicates', () async {
      final tag1 = await db.createTag('#Dart_Lang');
      final tag2 = await db.createTag('dart_lang');

      expect(tag1.id, equals(tag2.id));
      expect(tag1.name, equals('dart_lang'));
    });

    test('renameTag updates tag name and propagates to all affected note Markdown', () async {
      final tag = await db.createTag('programming');

      // Create note 1 with #programming in title and body
      await db.saveNote(
        id: 'note-1',
        title: 'Title with #programming',
        content: 'Learning #programming is fun.\nAlso tags: [programming]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: true,
      );

      // Create note 2 with unrelated tags
      await db.saveNote(
        id: 'note-2',
        title: 'Cooking recipe',
        content: 'Baking bread #food',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: true,
      );

      // Execute rename
      await db.renameTag(tag.id, 'development');

      // 1. Tag entity name is updated, ID is unchanged
      final updatedTag = await db.getTagById(tag.id);
      expect(updatedTag?.name, equals('development'));
      expect(updatedTag?.id, equals(tag.id));

      // 2. Note 1 markdown is updated
      final note1 = await db.getNoteWithTags('note-1');
      expect(note1?.note.title, equals('Title with #development'));
      expect(note1?.note.content.contains('#development'), isTrue);
      expect(note1?.note.content.contains('#programming'), isFalse);

      // 3. Note 2 markdown is completely untouched
      final note2 = await db.getNoteWithTags('note-2');
      expect(note2?.note.content, equals('Baking bread #food'));
    });

    test('deleteTag removes tag from notes without deleting the notes themselves', () async {
      final tag = await db.createTag('temporary');

      await db.saveNote(
        id: 'note-temp',
        title: 'Temporary Note',
        content: 'This note has #temporary tag in content.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: true,
      );

      // Delete the tag
      await db.deleteTag(tag.id);

      // Tag entity is deleted
      final deletedTag = await db.getTagById(tag.id);
      expect(deletedTag, isNull);

      // Note STILL exists, but #temporary has been stripped
      final note = await db.getNoteWithTags('note-temp');
      expect(note, isNotNull);
      expect(note?.note.content.contains('#temporary'), isFalse);
    });

    test('mergeTags merges source tag into destination tag across notes', () async {
      final source = await db.createTag('flutter-dev');
      final dest = await db.createTag('flutter');

      await db.saveNote(
        id: 'note-dev',
        title: 'Dev note',
        content: 'Tips for #flutter-dev',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: true,
      );

      await db.mergeTags(source.id, dest.id);

      // Source tag entity is deleted
      expect(await db.getTagById(source.id), isNull);
      // Destination tag entity survives
      expect(await db.getTagById(dest.id), isNotNull);

      // Note content now contains destination tag
      final note = await db.getNoteWithTags('note-dev');
      expect(note?.note.content, equals('Tips for #flutter'));
    });

    test('pinTag and reorderPinnedTags updates pinned status and order', () async {
      final t1 = await db.createTag('tag1');
      final t2 = await db.createTag('tag2');
      final t3 = await db.createTag('tag3');

      await db.pinTag(t1.id, true);
      await db.pinTag(t2.id, true);
      await db.pinTag(t3.id, true);

      expect((await db.getTagById(t1.id))?.isPinned, isTrue);

      // Reorder pinned tags: t3, t1, t2
      await db.reorderPinnedTags([t3.id, t1.id, t2.id]);

      expect((await db.getTagById(t3.id))?.pinnedOrder, equals(0));
      expect((await db.getTagById(t1.id))?.pinnedOrder, equals(1));
      expect((await db.getTagById(t2.id))?.pinnedOrder, equals(2));

      // Unpin t1
      await db.pinTag(t1.id, false);
      expect((await db.getTagById(t1.id))?.isPinned, isFalse);
    });

    test('watchAllTagsWithCount includes unused tags with count 0 and active note counts', () async {
      await db.createTag('unused-tag');
      await db.createTag('active-tag');

      await db.saveNote(
        id: 'note-active',
        title: 'Active note',
        content: '#active-tag note body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: true,
      );

      final tagsWithCount = await db.watchAllTagsWithCount().first;
      final unusedItem = tagsWithCount.firstWhere((t) => t.name == 'unused-tag');
      final activeItem = tagsWithCount.firstWhere((t) => t.name == 'active-tag');

      expect(unusedItem.noteCount, equals(0));
      expect(activeItem.noteCount, equals(1));
    });
  });
}
