import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';
import 'template_domain_test.dart' show fixture, richFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late DriftNotesRepository notes;
  late TemplateRepository repo;
  late TemplateService service;
  var created = 0;
  setUp(() {
    db = AppDatabase.memory();
    notes = DriftNotesRepository(db);
    repo = TemplateRepository(db);
    created = 0;
    service = TemplateService(
      repository: repo,
      notes: notes,
      onNoteCreated: () {
        created++;
      },
    );
  });
  tearDown(() => db.close());
  Note source({String content = richFixture}) => Note(
    id: 'source',
    title: 'Source',
    content: content,
    tags: ['work/plan'],
    isPinned: true,
    isArchived: true,
    shareId: 'private-share-token',
    createdAt: DateTime.utc(2020),
    updatedAt: DateTime.utc(2020),
  );

  test(
    'flushes unsaved edits, reads persisted snapshot, then leaves source unchanged',
    () async {
      final note = source();
      await notes.saveNote(note);
      final editor = EditorNotifier(initialNote: note, repository: notes);
      editor.updateContent('Newest body');
      final before = editor.state.note;
      final template = await service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Reusable',
        flush: editor.flushForTemplate,
      );
      expect(template.content, 'Newest body');
      expect(template.id, isNot(note.id));
      expect(template.defaultTags, ['work/plan']);
      expect(template.isFavorite, false);
      expect(
        (await notes.getNoteById(note.id))!.updatedAt.millisecondsSinceEpoch ~/
            1000,
        before.updatedAt.millisecondsSinceEpoch ~/ 1000,
      );
      expect(await notes.getVersions(note.id), isEmpty);
      expect(created, 0);
      final persisted = await notes.getNoteById(note.id);
      await service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Again',
        flush: editor.flushForTemplate,
      );
      expect(await notes.getNoteById(note.id), persisted);
      editor.dispose();
    },
  );
  test(
    'independent canonical rich snapshots instantiate through normal indexes/sync',
    () async {
      final body = jsonEncode(
        const RichDocumentParser().parse(richFixture).toJson(),
      );
      final note = source(content: body);
      await notes.saveNote(note);
      final template = await service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Snapshot',
        flush: () async {},
      );
      final a = await service.instantiate(template.id, activeTag: '#Work/Plan');
      final b = await service.instantiate(
        template.id,
        activeTag: '#Personal/Ideas',
      );
      expect(a.id, isNot(b.id));
      expect(a.id, isNot(note.id));
      expect(a.id, isNot(template.id));
      expect(a.content, body);
      expect(b.content, body);
      expect(a.title, 'Snapshot');
      expect(a.tags, ['work/plan']);
      expect(b.tags, ['work/plan', 'personal/ideas']);
      expect(a.createdAt.isAfter(note.createdAt), true);
      expect(
        a.isArchived ||
            a.isTrashed ||
            a.isPinned ||
            a.isPasswordProtected ||
            a.isShared ||
            a.isJournal,
        false,
      );
      final dirty = await db.getDirtyNotes();
      expect(dirty.map((n) => n.note.id), containsAll([a.id, b.id]));
      expect((await db.getNoteWithTags(a.id))!.note.serverRevision, 0);
      expect((await db.getNoteWithTags(a.id))!.note.syncedAt, isNull);
      expect(
        await db.select(db.syncQueueTable).get(),
        isEmpty,
      ); // ordinary dirty-row pathway
      expect(created, 2);
      await notes.saveNote(a.copyWith(content: 'Edited independently'));
      await notes.deletePermanently(note.id);
      expect((await repo.getUserTemplate(template.id))!.content, body);
      await service.delete(template.id);
      expect((await notes.getNoteById(a.id))!.content, 'Edited independently');
      expect((await notes.getNoteById(b.id))!.content, body);
    },
  );
  test(
    'template rows do not affect note list/search/count/tag membership/sync',
    () async {
      await repo.insertUserTemplate(fixture(tags: ['template-only-tag']));
      expect(await db.watchNotes().first, isEmpty);
      expect(await db.getDirtyNotes(), isEmpty);
      expect(await db.getAllTagNames(), isEmpty);
      await service.favorite(fixture().id, true);
      await service.rename(fixture().id, 'Renamed');
      expect(await db.select(db.syncQueueTable).get(), isEmpty);
      expect(await db.select(db.noteLinksTable).get(), isEmpty);
    },
  );
  test(
    'normal saved notes with title-only bodies remain after editor exit',
    () async {
      await notes.saveNote(source(content: ''));
      final template = await service.saveNoteAsTemplate(
        noteId: 'source',
        name: 'Title only',
        flush: () async {},
      );
      final note = await service.instantiate(template.id);
      final editor = EditorNotifier(initialNote: note, repository: notes);
      await editor.handleExitCleanup();
      editor.dispose();
      expect(await notes.getNoteById(note.id), isNotNull);
    },
  );
  test(
    'deleted selection and built-in mutation cannot create fallback notes',
    () async {
      await repo.insertUserTemplate(fixture());
      await service.delete(fixture().id);
      await expectLater(
        service.instantiate(fixture().id),
        throwsA(isA<TemplateException>()),
      );
      expect(await db.select(db.notesTable).get(), isEmpty);
      await expectLater(
        service.rename('builtin.daily_planner.v1', 'Changed'),
        throwsA(isA<TemplateException>()),
      );
      await expectLater(
        service.delete('builtin.daily_planner.v1'),
        throwsA(isA<TemplateException>()),
      );
      final note = await service.instantiate('builtin.daily_planner.v1');
      expect(note.title, 'Daily Planner');
    },
  );
  test(
    'protected, journal, trash, locked, read-only and missing notes blocked',
    () async {
      final ordinary = source();
      for (final note in [
        ordinary.copyWith(isTrashed: true),
        ordinary.copyWith(journalDate: '2026-11-18'),
        ordinary.copyWith(
          content: '<!-- quiet-paper-encrypted-note-v1: secret -->',
        ),
      ]) {
        await notes.saveNote(note);
        await expectLater(
          service.saveNoteAsTemplate(
            noteId: note.id,
            name: 'Blocked',
            flush: () async {},
          ),
          throwsA(isA<TemplateException>()),
        );
      }
      await notes.saveNote(ordinary);
      for (final locked in [true, false]) {
        await expectLater(
          service.saveNoteAsTemplate(
            noteId: ordinary.id,
            name: 'Blocked',
            flush: () async {
              fail('must not flush');
            },
            locked: locked,
            readOnly: !locked,
          ),
          throwsA(isA<TemplateException>()),
        );
      }
      await expectLater(
        service.saveNoteAsTemplate(
          noteId: 'missing',
          name: 'Missing',
          flush: () async {},
        ),
        throwsA(isA<TemplateException>()),
      );
      expect(await repo.getUserTemplates(), isEmpty);
    },
  );
  test(
    'a blank canonical rich document needs a meaningful source title',
    () async {
      final blank = jsonEncode(const RichDocumentParser().parse('').toJson());
      await notes.saveNote(
        source(content: blank).copyWith(title: '', tags: const []),
        preserveEmptyTags: true,
      );
      await expectLater(
        service.saveNoteAsTemplate(
          noteId: 'source',
          name: 'Blank',
          flush: () async {},
        ),
        throwsA(isA<TemplateException>()),
      );
      expect(await repo.getUserTemplates(), isEmpty);
    },
  );

  test('unsupported assets rejected without mutating source', () async {
    final note = source(content: 'Text\n![Image](qp://asset/asset-id)');
    await notes.saveNote(note);
    final before = await notes.getNoteById(note.id);
    await expectLater(
      service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Blocked',
        flush: () async {},
      ),
      throwsA(isA<TemplateException>()),
    );
    expect(await notes.getNoteById(note.id), before);
    expect(await repo.getUserTemplates(), isEmpty);
  });
  test('failed autosave cannot snapshot stale persisted contents', () async {
    final note = source();
    await notes.saveNote(note);
    final failing = _ControlledNotes(db)..failSave = true;
    final editor = EditorNotifier(initialNote: note, repository: failing)
      ..updateContent('Unsaved newest');
    await expectLater(
      service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Unsafe',
        flush: editor.flushForTemplate,
      ),
      throwsStateError,
    );
    expect(await repo.getUserTemplates(), isEmpty);
    expect((await notes.getNoteById(note.id))!.content, note.content);
    editor.dispose();
  });
  test(
    'flush awaits in-flight save and persists edits made during it',
    () async {
      final note = source();
      await notes.saveNote(note);
      final controlled = _ControlledNotes(db)..gate = Completer<void>();
      final editor = EditorNotifier(initialNote: note, repository: controlled)
        ..updateContent('First');
      final pending = editor.saveNow();
      editor.updateContent('Latest');
      final snapshot = service.saveNoteAsTemplate(
        noteId: note.id,
        name: 'Fresh',
        flush: editor.flushForTemplate,
      );
      controlled.gate!.complete();
      await pending;
      expect((await snapshot).content, 'Latest');
      editor.dispose();
    },
  );
  for (final newline in ['\n', '\r\n']) {
    for (final titleIndex in [0, 1, 3]) {
      for (final oldTitle in ['Old', '"Old # title"', "'Bob''s # title'"]) {
        test(
          'frontmatter round trip newline=${jsonEncode(newline)}, position=$titleIndex, value=$oldTitle',
          () async {
            final lines = [
              'author: Alice',
              '# retained comment',
              'custom: value',
            ];
            lines.insert(titleIndex, 'title: $oldTitle  # title comment');
            final body = [
              '---',
              ...lines,
              '---',
              'Body',
              'untouched ✓',
              '',
            ].join(newline);
            final note = source(content: body);
            await notes.saveNote(note);
            const title = 'New "quoted" title # ✓';
            final template = await service.saveNoteAsTemplate(
              noteId: note.id,
              name: title,
              flush: () async {},
            );
            final created = await service.instantiate(template.id);
            expect(
              created.content,
              body.replaceFirst(
                'title: $oldTitle',
                'title: ${jsonEncode(title)}',
              ),
            );
            expect(template.content, body);
            expect((await notes.getNoteById(note.id))!.content, body);
          },
        );
      }
    }
  }

  test(
    'creation failure never announces success or leaves a partial note',
    () async {
      final failing = _ControlledNotes(db)..failSave = true;
      final brokenService = TemplateService(
        repository: repo,
        notes: failing,
        onNoteCreated: () {
          created++;
        },
      );
      await expectLater(
        brokenService.instantiate('builtin.meeting_notes.v1'),
        throwsStateError,
      );
      expect(created, 0);
      expect(await db.select(db.notesTable).get(), isEmpty);
    },
  );
}

class _ControlledNotes extends DriftNotesRepository {
  _ControlledNotes(super.db);
  bool failSave = false;
  Completer<void>? gate;
  @override
  Future<void> saveNote(Note note, {bool preserveEmptyTags = false}) async {
    if (failSave) throw StateError('injected write failure');
    if (gate != null) await gate!.future;
    await super.saveNote(note, preserveEmptyTags: preserveEmptyTags);
  }
}
