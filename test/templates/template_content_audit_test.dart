import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_inline.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/templates/application/template_content.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';
import 'template_domain_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final body in [
    'Read [private](qp&#58;//asset/private-id) inline.',
    '[private][resource]\n\n[resource]: qp&#58;//document/private-id',
    '[private](%71%70%3A%2F%2Fasset%2Fprivate-id)',
    '[private](content&#58;//provider/private-id)',
    '[private](file&#58;///private/file)',
    '| Link |\n| --- |\n| [private](qp&#58;//asset/private-id) |',
  ]) {
    test('rejects decoded Markdown resource $body', () {
      expect(
        () => validateTemplateContent(fixture(content: body)),
        throwsA(isA<TemplateException>()),
      );
    });
  }

  for (final body in [
    'Read [private](qp://asset/private-id) inline.',
    '# Heading [private](qp://document/private-id)',
    '> Quote [private](qp://asset/private-id)',
    '- List [private](qp://asset/private-id)',
    '| Link |\n| --- |\n| [private](qp://asset/private-id) |',
  ]) {
    test('rejects Unicode-escaped AST destination in $body', () {
      final content = jsonEncode(
        const RichDocumentParser().parse(body).toJson(),
      ).replaceAll('qp://', r'\u0071p:\u002f\u002f');
      expect(jsonDecode(content).toString(), contains('qp://'));
      expect(
        () => validateTemplateContent(
          fixture(content: content, format: TemplateStorageFormat.richAst),
        ),
        throwsA(isA<TemplateException>()),
      );
    });
  }

  const literals = [
    '```text\nqp://asset/example\n<img src="example">\n```',
    '~~~html\n<img src="example">\n~~~',
    '    [file](qp://document/example)\n    <img src="example">',
    'Use `qp://asset/example`, `[file](file:///example)` and `<img src="x">`.',
    r'\<img src="example"> and \[file](qp://asset/example)',
    '&lt;img src="example"&gt; and qp://asset/example are examples.',
    '```html\n<!-- qp-link-preview: {"img":"private-thumbnail"} -->\n```',
  ];
  for (final body in literals) {
    test(
      'literal resource examples remain valid in Markdown and rich AST: $body',
      () {
        final markdown = fixture(content: body);
        validateTemplateContent(markdown);
        expect(instantiateTemplateContent(markdown), body);
        final rich = jsonEncode(
          RichDocument(
            blocks: [
              CodeBlock(id: 'code', code: body),
              ParagraphBlock(
                id: 'text',
                spans: [RichInlineSpan(text: body)],
              ),
            ],
          ).toJson(),
        );
        validateTemplateContent(
          fixture(content: rich, format: TemplateStorageFormat.richAst),
        );
      },
    );
  }

  for (final body in [
    '<a href="qp&#58;//asset/private-id">private</a>',
    '<img src="https://example.com/a.png">',
    '<!-- qp-link-preview: {"img":"private-thumbnail"} -->',
    '[private](qp://asset/private-id)',
  ]) {
    test('equivalent live resources remain blocked: $body', () {
      expect(
        () => validateTemplateContent(fixture(content: body)),
        throwsA(isA<TemplateException>()),
      );
    });
  }

  test('literal technical snapshot saves and instantiates verbatim', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final notes = DriftNotesRepository(db);
    final repository = TemplateRepository(db);
    final service = TemplateService(repository: repository, notes: notes);
    final body = literals.join('\n\n');
    final note = Note(
      id: 'technical',
      title: 'Technical',
      content: body,
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2020),
    );
    await notes.saveNote(note);
    final template = await service.saveNoteAsTemplate(
      noteId: note.id,
      name: 'Technical',
      flush: () async {},
    );
    expect(template.content, body);
    expect((await service.instantiate(template.id)).content, body);
  });

  test(
    'encoded private links cannot save or instantiate through the service',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final notes = DriftNotesRepository(db);
      final repository = TemplateRepository(db);
      final service = TemplateService(repository: repository, notes: notes);
      final bodies = [
        'Read [private](qp&#58;//asset/private-id) inline.',
        jsonEncode(
          const RichDocumentParser()
              .parse('Read [private](qp://asset/private-id) inline.')
              .toJson(),
        ).replaceAll('qp://', r'\u0071p:\u002f\u002f'),
      ];
      for (final body in bodies) {
        final note = Note(
          id: 'source',
          title: 'Source',
          content: body,
          createdAt: DateTime.utc(2020),
          updatedAt: DateTime.utc(2020),
        );
        await notes.saveNote(note);
        await expectLater(
          service.saveNoteAsTemplate(
            noteId: note.id,
            name: 'Blocked',
            flush: () async {},
          ),
          throwsA(isA<TemplateException>()),
        );
        final unsafe = fixture(
          content: body,
          format: detectTemplateFormat(body),
        );
        await repository.insertUserTemplate(unsafe);
        await expectLater(
          service.instantiate(unsafe.id),
          throwsA(isA<TemplateException>()),
        );
        await repository.deleteUserTemplate(unsafe.id);
        expect((await notes.getNoteById(note.id))!.content, body);
      }
      expect(await repository.getUserTemplates(), isEmpty);
      expect((await db.select(db.notesTable).get()).length, 1);
    },
  );
}
