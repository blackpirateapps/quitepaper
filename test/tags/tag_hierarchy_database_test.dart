import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';

void main() {
  group('Nested tag database operations', () {
    late AppDatabase db;
    final now = DateTime(2026, 1, 1);

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> saveNote(
      String id,
      String content, {
      String title = 'Note',
      bool isArchived = false,
      bool isTrashed = false,
    }) {
      return db.saveNote(
        id: id,
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
        isPinned: false,
        isArchived: isArchived,
        isTrashed: isTrashed,
        isDirty: true,
      );
    }

    test(
      'createTag creates missing ancestors and only metadata on the leaf',
      () async {
        final leaf = await db.createTag(
          'Work/Projects/Alpha',
          icon: 'code',
          color: 'teal',
          isPinned: true,
        );

        expect(leaf.name, equals('work/projects/alpha'));
        expect(leaf.icon, equals('code'));
        expect(leaf.color, equals('teal'));
        expect(leaf.isPinned, isTrue);
        expect(leaf.isDirty, isTrue);

        final root = await db.getTagByName('work');
        final middle = await db.getTagByName('work/projects');
        expect(root, isNotNull);
        expect(middle, isNotNull);
        expect(root!.isDirty, isTrue);
        expect(middle!.isDirty, isTrue);
        expect(root.icon, isNull);
        expect(root.color, isNull);
        expect(root.isPinned, isFalse);
        expect(middle.icon, isNull);
        expect(middle.color, isNull);
        expect(root.id, equals(TagParser.deterministicTagId('work')));
        expect(
          middle.id,
          equals(TagParser.deterministicTagId('work/projects')),
        );
      },
    );

    test('creating the same nested path twice reuses every ancestor', () async {
      final first = await db.createTag('work/projects');
      final second = await db.createTag('work/projects');

      expect(second.id, equals(first.id));
      final names = await db.getAllTagNames();
      expect(names.where((name) => name == 'work').length, equals(1));
      expect(names.where((name) => name == 'work/projects').length, equals(1));
    });

    test('a note with a nested tag is assigned only to the leaf', () async {
      await saveNote('note-1', 'Planning #work/projects/alpha today');

      final note = await db.getNoteWithTags('note-1');
      expect(note, isNotNull);
      expect(
        note!.tags.map((tag) => tag.name),
        equals(['work/projects/alpha']),
      );
      expect(note.note.content, equals('Planning #work/projects/alpha today'));

      // Ancestors exist as ordinary entities, but no extra hashtags were
      // inserted into the Markdown.
      expect(await db.getTagByName('work'), isNotNull);
      expect(await db.getTagByName('work/projects'), isNotNull);
    });

    test(
      'subtree filtering includes descendants and deduplicates notes',
      () async {
        await saveNote('n-parent', '#work');
        await saveNote('n-child', '#work/projects');
        await saveNote('n-grandchild', '#work/projects/alpha');
        await saveNote('n-both', '#work and #work/projects');
        await saveNote('n-workflow', '#workflow');

        final parentNotes = await db.watchNotes(filterTag: 'work').first;
        expect(
          parentNotes.map((item) => item.note.id).toSet(),
          equals({'n-parent', 'n-child', 'n-grandchild', 'n-both'}),
        );

        final childNotes = await db
            .watchNotes(filterTag: 'work/projects')
            .first;
        expect(
          childNotes.map((item) => item.note.id).toSet(),
          equals({'n-child', 'n-grandchild', 'n-both'}),
        );

        final leafNotes = await db
            .watchNotes(filterTag: '#Work/Projects/Alpha')
            .first;
        expect(
          leafNotes.map((item) => item.note.id).toSet(),
          equals({'n-grandchild'}),
        );
      },
    );

    test('subtree filtering does not match textual prefixes', () async {
      await saveNote('n-work', '#work');
      await saveNote('n-workflow', '#workflow');
      await saveNote('n-workshop', '#work-shop');

      final notes = await db.watchNotes(filterTag: 'work').first;
      expect(notes.map((item) => item.note.id), equals(['n-work']));
    });

    test(
      'subtree counts are distinct active notes and synthesize implicit ancestors',
      () async {
        await saveNote('n-parent', '#work');
        await saveNote('n-child-a', '#work/projects');
        await saveNote('n-child-b', '#work/projects');
        await saveNote('n-leaf', '#work/projects #work/projects/alpha');
        await saveNote('n-workflow', '#workflow');
        await saveNote('n-archived', '#work/projects', isArchived: true);
        await saveNote('n-trashed', '#work/projects', isTrashed: true);

        final counts = await db.watchAllTagsWithCount().first;
        final byName = {for (final item in counts) item.name: item};

        expect(byName['work']!.noteCount, equals(4));
        expect(byName['work']!.isImplicit, isFalse);
        expect(byName['work/projects']!.noteCount, equals(3));
        expect(byName['work/projects/alpha']!.noteCount, equals(1));
        expect(byName['workflow']!.noteCount, equals(1));

        // An unused explicit tag is still listed with a zero count.
        await db.createTag('unused');
        final withUnused = await db.watchAllTagsWithCount().first;
        expect(
          withUnused.firstWhere((item) => item.name == 'unused').noteCount,
          equals(0),
        );
      },
    );

    test(
      'implicit ancestors appear when only a legacy child row exists',
      () async {
        await db
            .into(db.tagsTable)
            .insert(
              TagsTableCompanion.insert(
                id: 'legacy-child',
                name: 'work/projects',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await db
            .into(db.notesTable)
            .insert(
              NotesTableCompanion.insert(
                id: 'legacy-note',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.noteTagsTable)
            .insert(
              NoteTagsTableCompanion.insert(
                noteId: 'legacy-note',
                tagId: 'legacy-child',
              ),
            );

        final counts = await db.watchAllTagsWithCount().first;
        final work = counts.firstWhere((item) => item.name == 'work');
        expect(work.isImplicit, isTrue);
        expect(work.noteCount, equals(1));
        expect(work.id, equals(TagParser.deterministicTagId('work')));

        final names = await db.getAllTagNames();
        expect(names, contains('work'));
        expect(names, contains('work/projects'));

        // Presentation synthesis must not persist ancestor rows.
        expect(await db.getTagByName('work'), isNull);
      },
    );

    test('getAllTagNames includes every ancestor path', () async {
      await db
          .into(db.tagsTable)
          .insert(
            TagsTableCompanion.insert(
              id: 'legacy-deep',
              name: 'a/b/c',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final names = await db.getAllTagNames();
      expect(names, containsAll(['a', 'a/b', 'a/b/c']));
    });

    test(
      'renaming a branch preserves IDs and metadata and rewrites Markdown segment-aware',
      () async {
        final work = await db.createTag(
          'work',
          icon: 'briefcase',
          color: 'blue',
          isPinned: true,
        );
        final projects = await db.createTag('work/projects', icon: 'code');
        final alpha = await db.createTag('work/projects/alpha');
        final workflow = await db.createTag('workflow');

        await saveNote(
          'n-rename',
          '---\ntags: [work, work/projects]\n---\n'
              'Body #work #work/projects #work/projects/alpha #workflow',
          title: 'About #work',
        );

        await db.renameTag(work.id, 'Job');

        expect(await db.getTagByName('work'), isNull);
        expect(await db.getTagByName('work/projects'), isNull);
        expect(await db.getTagByName('work/projects/alpha'), isNull);
        expect(await db.getTagByName('workflow'), isNotNull);

        final renamedWork = await db.getTagByName('job');
        final renamedProjects = await db.getTagByName('job/projects');
        final renamedAlpha = await db.getTagByName('job/projects/alpha');
        expect(renamedWork?.id, equals(work.id));
        expect(renamedProjects?.id, equals(projects.id));
        expect(renamedAlpha?.id, equals(alpha.id));
        expect(renamedWork?.icon, equals('briefcase'));
        expect(renamedWork?.color, equals('blue'));
        expect(renamedWork?.isPinned, isTrue);
        expect(renamedProjects?.icon, equals('code'));

        final note = await db.getNoteWithTags('n-rename');
        expect(note, isNotNull);
        expect(note!.note.title, equals('About #job'));
        expect(
          note.note.content,
          equals(
            '---\ntags: [job, job/projects]\n---\n'
            'Body #job #job/projects #job/projects/alpha #workflow',
          ),
        );
        expect(
          note.tags.map((tag) => tag.name).toSet(),
          equals({'job', 'job/projects', 'job/projects/alpha', 'workflow'}),
        );
        expect(workflow.name, equals('workflow'));
      },
    );

    test(
      'renaming a branch creates new ancestors outside the branch',
      () async {
        final work = await db.createTag('work/projects');

        await db.renameTag(work.id, 'archive/year/projects');

        expect(await db.getTagByName('archive'), isNotNull);
        expect(await db.getTagByName('archive/year'), isNotNull);
        expect(await db.getTagByName('archive/year/projects'), isNotNull);
        expect(await db.getTagByName('work'), isNull);
        expect(await db.getTagByName('work/projects'), isNull);
      },
    );

    test('renaming a branch removes every unused old ancestor', () async {
      final leaf = await db.createTag('a/b/c');

      await db.renameTag(leaf.id, 'x/y/c');

      expect(await db.getTagByName('a/b/c'), isNull);
      expect(await db.getTagByName('a/b'), isNull);
      expect(await db.getTagByName('a'), isNull);
      expect(await db.getTagByName('x/y/c'), isNotNull);
    });

    test('rename collision rolls back the whole local transaction', () async {
      final work = await db.createTag('work');
      await db.createTag('work/projects');
      await db.createTag('job/projects');
      await saveNote('n-collision', '#work');

      await expectLater(
        db.renameTag(work.id, 'job'),
        throwsA(isA<StateError>()),
      );

      expect(await db.getTagByName('work'), isNotNull);
      expect(await db.getTagByName('work/projects'), isNotNull);
      expect(await db.getTagByName('job/projects'), isNotNull);
      final note = await db.getNoteWithTags('n-collision');
      expect(note!.note.content, equals('#work'));
    });

    test('a branch cannot be moved inside itself', () async {
      final work = await db.createTag('work');

      await expectLater(
        db.renameTag(work.id, 'work/archive'),
        throwsA(isA<StateError>()),
      );
      expect(await db.getTagByName('work'), isNotNull);
      expect(await db.getTagByName('work/archive'), isNull);
    });

    test(
      'moveTag reparents a branch and can promote it to the top level',
      () async {
        final projects = await db.createTag('work/projects');
        await db.createTag('work/projects/alpha');
        await saveNote('n-move', '#work/projects/alpha');

        await db.moveTag(projects.id, 'archive');

        expect(await db.getTagByName('work/projects'), isNull);
        expect(
          (await db.getTagByName('archive/projects'))?.id,
          equals(projects.id),
        );
        expect(await db.getTagByName('archive/projects/alpha'), isNotNull);
        var note = await db.getNoteWithTags('n-move');
        expect(note!.note.content, equals('#archive/projects/alpha'));

        final archiveProjects = await db.getTagByName('archive/projects');
        await db.moveTag(archiveProjects!.id, '');

        expect(await db.getTagByName('archive/projects'), isNull);
        expect((await db.getTagByName('projects'))?.id, equals(projects.id));
        note = await db.getNoteWithTags('n-move');
        expect(note!.note.content, equals('#projects/alpha'));
      },
    );

    test('moveTag rejects collisions with an existing target path', () async {
      final work = await db.createTag('work');
      await db.createTag('job');
      await db.createTag('job/work');

      await expectLater(db.moveTag(work.id, 'job'), throwsA(isA<StateError>()));
      expect(await db.getTagByName('work'), isNotNull);
      expect(await db.getTagByName('job/work'), isNotNull);
    });

    test('deleting a branch removes descendants and keeps notes', () async {
      final work = await db.createTag('work');
      await db.createTag('work/projects');
      await db.createTag('work/projects/alpha');
      await db.createTag('workflow');
      await saveNote(
        'n-delete',
        'Keep #work #work/projects #work/projects/alpha #workflow',
      );

      await db.deleteTag(work.id);

      expect(await db.getTagByName('work'), isNull);
      expect(await db.getTagByName('work/projects'), isNull);
      expect(await db.getTagByName('work/projects/alpha'), isNull);
      expect(await db.getTagByName('workflow'), isNotNull);

      final note = await db.getNoteWithTags('n-delete');
      expect(note, isNotNull);
      expect(note!.note.content, equals('Keep #workflow'));
      expect(note.tags.map((tag) => tag.name), equals(['workflow']));
    });

    test(
      'moveChildrenUp promotes direct children and preserves their IDs',
      () async {
        final work = await db.createTag('work');
        final projects = await db.createTag('work/projects', icon: 'code');
        final alpha = await db.createTag('work/projects/alpha');
        final ideas = await db.createTag('work/ideas');
        await saveNote(
          'n-promote',
          '#work #work/projects #work/projects/alpha #work/ideas',
        );

        await db.deleteTag(work.id, mode: TagBranchDeleteMode.moveChildrenUp);

        expect(await db.getTagByName('work'), isNull);
        expect(await db.getTagByName('work/projects'), isNull);
        expect(await db.getTagByName('work/projects/alpha'), isNull);
        expect(await db.getTagByName('work/ideas'), isNull);

        final promoted = await db.getTagByName('projects');
        final promotedAlpha = await db.getTagByName('projects/alpha');
        final promotedIdeas = await db.getTagByName('ideas');
        expect(promoted?.id, equals(projects.id));
        expect(promoted?.icon, equals('code'));
        expect(promotedAlpha?.id, equals(alpha.id));
        expect(promotedIdeas?.id, equals(ideas.id));

        final note = await db.getNoteWithTags('n-promote');
        expect(note, isNotNull);
        expect(note!.note.content, equals('#projects #projects/alpha #ideas'));
        expect(
          note.tags.map((tag) => tag.name).toSet(),
          equals({'projects', 'projects/alpha', 'ideas'}),
        );
      },
    );

    test(
      'moveChildrenUp collision rolls back instead of losing children',
      () async {
        final work = await db.createTag('work');
        await db.createTag('work/projects');
        await db.createTag('projects');
        await saveNote('n-promote-conflict', '#work #work/projects');

        await expectLater(
          db.deleteTag(work.id, mode: TagBranchDeleteMode.moveChildrenUp),
          throwsA(isA<StateError>()),
        );

        expect(await db.getTagByName('work'), isNotNull);
        expect(await db.getTagByName('work/projects'), isNotNull);
        final note = await db.getNoteWithTags('n-promote-conflict');
        expect(note!.note.content, equals('#work #work/projects'));
      },
    );

    test(
      'merging a branch renames descendants into the destination branch',
      () async {
        final work = await db.createTag('work');
        final projects = await db.createTag('work/projects');
        final alpha = await db.createTag('work/projects/alpha');
        final archive = await db.createTag('archive');
        await saveNote('n-merge', '#work #work/projects #work/projects/alpha');

        await db.mergeTags(work.id, archive.id);

        expect(await db.getTagByName('work'), isNull);
        expect(await db.getTagByName('work/projects'), isNull);
        expect(await db.getTagByName('work/projects/alpha'), isNull);
        expect((await db.getTagByName('archive'))?.id, equals(archive.id));
        expect(
          (await db.getTagByName('archive/projects'))?.id,
          equals(projects.id),
        );
        expect(
          (await db.getTagByName('archive/projects/alpha'))?.id,
          equals(alpha.id),
        );

        final note = await db.getNoteWithTags('n-merge');
        expect(
          note!.note.content,
          equals('#archive #archive/projects #archive/projects/alpha'),
        );
        expect(
          note.tags.map((tag) => tag.name).toSet(),
          equals({'archive', 'archive/projects', 'archive/projects/alpha'}),
        );
      },
    );

    test(
      'merging reconciles conflicting descendant names and keeps note assignments',
      () async {
        final work = await db.createTag('work');
        await db.createTag('work/projects');
        final archive = await db.createTag('archive');
        final existingProjects = await db.createTag('archive/projects');
        await saveNote('n-merge-conflict', '#work #work/projects');

        await db.mergeTags(work.id, archive.id);

        expect(await db.getTagByName('work'), isNull);
        expect(await db.getTagByName('work/projects'), isNull);
        expect((await db.getTagByName('archive'))?.id, equals(archive.id));
        expect(
          (await db.getTagByName('archive/projects'))?.id,
          equals(existingProjects.id),
        );

        final note = await db.getNoteWithTags('n-merge-conflict');
        expect(note, isNotNull);
        expect(note!.note.content, equals('#archive #archive/projects'));
        expect(
          note.tags.map((tag) => tag.name).toSet(),
          equals({'archive', 'archive/projects'}),
        );
      },
    );

    test('a branch cannot be merged into its own descendant', () async {
      final work = await db.createTag('work');
      final child = await db.createTag('work/projects');

      await expectLater(
        db.mergeTags(work.id, child.id),
        throwsA(isA<StateError>()),
      );
      expect(await db.getTagByName('work'), isNotNull);
      expect(await db.getTagByName('work/projects'), isNotNull);
    });

    test(
      'orphan cleanup preserves ancestor rows but removes unused leaves',
      () async {
        await saveNote('n-live', '#work/projects');
        await saveNote('n-temp', '#temporary');

        await db.deletePermanently('n-temp', enqueueSync: false);

        expect(await db.getTagByName('temporary'), isNull);
        expect(await db.getTagByName('work'), isNotNull);
        expect(await db.getTagByName('work/projects'), isNotNull);
      },
    );
  });

  group('Tag hierarchy backfill migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'quitepaper_tag_backfill_',
      );
      dbFile = File('${tempDir.path}/legacy.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'backfills missing ancestors idempotently while preserving legacy rows',
      () async {
        const markerKey = 'tag_hierarchy_backfill_v1';
        final timestamp = DateTime(2025, 5, 1);

        var db = AppDatabase(NativeDatabase(dbFile));
        await db.customSelect('SELECT 1').get();
        expect(await db.getSyncMetadata(markerKey), equals('1'));

        await db
            .into(db.tagsTable)
            .insert(
              TagsTableCompanion.insert(
                id: 'legacy-child',
                name: 'work/projects',
                icon: const Value('briefcase'),
                color: const Value('blue'),
                isPinned: const Value(true),
                pinnedOrder: const Value(3),
                createdAt: Value(timestamp),
                updatedAt: Value(timestamp),
                isDirty: const Value(false),
                serverRevision: const Value(7),
              ),
            );
        await db
            .into(db.tagsTable)
            .insert(
              TagsTableCompanion.insert(
                id: 'legacy-malformed',
                name: 'a//b',
                createdAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
        await db
            .into(db.notesTable)
            .insert(
              NotesTableCompanion.insert(
                id: 'legacy-note',
                title: const Value('Legacy note'),
                content: const Value('Keep #work/projects'),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
        await db
            .into(db.noteTagsTable)
            .insert(
              NoteTagsTableCompanion.insert(
                noteId: 'legacy-note',
                tagId: 'legacy-child',
              ),
            );

        await db.customStatement(
          "DELETE FROM sync_metadata WHERE key = '$markerKey'",
        );
        await db.close();

        // Reopen: the beforeOpen hook runs the backfill.
        db = AppDatabase(NativeDatabase(dbFile));
        await db.customSelect('SELECT 1').get();

        final child = await db.getTagById('legacy-child');
        expect(child, isNotNull);
        expect(child!.name, equals('work/projects'));
        expect(child.icon, equals('briefcase'));
        expect(child.color, equals('blue'));
        expect(child.isPinned, isTrue);
        expect(child.pinnedOrder, equals(3));
        expect(child.isDirty, isFalse);
        expect(child.serverRevision, equals(7));

        final ancestor = await db.getTagByName('work');
        expect(ancestor, isNotNull);
        expect(ancestor!.id, equals(TagParser.deterministicTagId('work')));
        expect(ancestor.isDirty, isTrue);
        expect(ancestor.isDeleted, isFalse);
        expect(ancestor.icon, isNull);

        // Malformed legacy paths are left untouched and produce no ancestors.
        expect(await db.getTagById('legacy-malformed'), isNotNull);
        expect(await db.getTagByName('a'), isNull);
        expect(await db.getTagByName('a/b'), isNull);

        // Assignments and Markdown are unchanged.
        final note = await db.getNoteWithTags('legacy-note');
        expect(note, isNotNull);
        expect(note!.note.content, equals('Keep #work/projects'));
        expect(note.tags.map((tag) => tag.name), equals(['work/projects']));

        expect(await db.getSyncMetadata(markerKey), equals('1'));
        await db.close();

        // Reopen again: the marker makes the backfill a no-op.
        db = AppDatabase(NativeDatabase(dbFile));
        await db.customSelect('SELECT 1').get();
        final workRows = await (db.select(
          db.tagsTable,
        )..where((t) => t.name.equals('work'))).get();
        expect(workRows.length, equals(1));
        final names = await db.getAllTagNames();
        expect(
          names.where((name) => name == 'work/projects').length,
          equals(1),
        );
        await db.close();
      },
    );
  });
}
