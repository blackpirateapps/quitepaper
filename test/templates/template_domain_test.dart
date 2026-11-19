import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/templates/domain/note_template.dart';
import 'package:quitepaper/features/templates/data/built_in_templates.dart';
import 'package:quitepaper/features/templates/application/template_content.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';

NoteTemplate fixture({
  String name = 'Template',
  String content = 'Body',
  TemplateStorageFormat format = TemplateStorageFormat.markdown,
  List<String> tags = const [],
}) => NoteTemplate(
  id: '126d9d76-6348-4e29-bf9a-92807b31967f',
  displayName: name,
  content: content,
  storageFormat: format,
  defaultTags: tags,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const richFixture = r'''# Headline

## Details

**Bold** and *italic* with $x + y$.

- [x] Done
  - [ ] Nested
- Plain

1. Ordered
2. Another

| One | Two |
| --- | --- |
| A | B |

```dart
final x = 1;
```

$$
x^2 + y^2
$$

---

> Quote

[Website](https://example.com) and [[126d9d76-6348-4e29-bf9a-92807b31967f|Note]]
''';

void main() {
  test(
    'eight stable immutable built-ins in specified order, without favorites/tags',
    () {
      expect(builtInTemplates.map((t) => t.id), [
        'builtin.daily_planner.v1',
        'builtin.meeting_notes.v1',
        'builtin.study_notes.v1',
        'builtin.reading_notes.v1',
        'builtin.project_brief.v1',
        'builtin.bug_report.v1',
        'builtin.weekly_review.v1',
        'builtin.decision_log.v1',
      ]);
      for (final t in builtInTemplates) {
        expect(t.isBuiltIn, true);
        expect(t.isFavorite, false);
        expect(t.defaultTags, isEmpty);
        expect(t.content, isNot(contains('{{')));
        validateTemplateContent(t);
      }
      expect(() => builtInTemplates.clear(), throwsUnsupportedError);
    },
  );
  test('names trim, support Unicode graphemes, and allow duplicate names', () {
    expect(
      fixture(name: '  বাংলা 👨‍👩‍👧‍👦  ').displayName,
      'বাংলা 👨‍👩‍👧‍👦',
    );
    expect(fixture(name: '👨‍👩‍👧‍👦' * 80).displayName, '👨‍👩‍👧‍👦' * 80);
    expect(fixture().displayName, fixture().displayName);
    expect(fixture().createdAt.isUtc, true);
    expect(() => fixture(name: 'x' * 81), throwsA(isA<TemplateException>()));
    for (final name in [
      '',
      '  ',
      'line\nbreak',
      'bad\tname',
      'bad\x00',
      'bad\u0085',
      'line\u2028break',
    ]) {
      expect(() => fixture(name: name), throwsA(isA<TemplateException>()));
    }
  });
  test(
    'tags are normalized snapshots with nested paths, without mutable aliases',
    () {
      final tags = ['#Work/Plan', 'work/plan', ' Misc '];
      final t = fixture(tags: tags);
      expect(t.defaultTags, ['work/plan', 'misc']);
      tags.clear();
      expect(t.defaultTags.length, 2);
      expect(() => t.defaultTags.clear(), throwsUnsupportedError);
    },
  );
  test(
    'rich canonical bytes preserve all supported structures and round trip',
    () {
      final doc = const RichDocumentParser().parse(richFixture);
      final content = jsonEncode(doc.toJson());
      final t = fixture(
        content: content,
        format: TemplateStorageFormat.richAst,
      );
      validateTemplateContent(t);
      expect(instantiateTemplateContent(t), content);
      expect(
        RichDocument.fromJson(jsonDecode(t.content)).toJson(),
        doc.toJson(),
      );
      expect(fixture(content: richFixture).content, richFixture);
    },
  );
  test('invalid formats and tolerant-parser fallbacks are blocked', () {
    final json = fixture().toJson()..['storageFormat'] = 'html';
    expect(
      () => NoteTemplate.fromJson(json),
      throwsA(isA<TemplateException>()),
    );
    for (final content in [
      r'{"$schema":"quietpaper:rich_document:v2","blocks":[]}',
      r'{"$schema":"quietpaper:rich_document:v1","blocks":[{"type":"future_block"}]}',
      r'{"$schema":"quietpaper:rich_document:v1","blocks":oops}',
    ]) {
      expect(
        () => validateTemplateContent(
          fixture(content: content, format: TemplateStorageFormat.richAst),
        ),
        throwsA(isA<TemplateException>()),
      );
    }
    expect(
      () => validateTemplateContent(
        fixture(content: 'Markdown', format: TemplateStorageFormat.richAst),
      ),
      throwsA(isA<TemplateException>()),
    );
  });
  for (final body in [
    '![Image](https://example.com/p.png)',
    '![ref][pic]\n\n[pic]: https://example.com/p.png',
    '[Asset](qp://asset/id)',
    '[Attachment](qp://attachment/id)',
    '[Document](qp://document/id)',
    '<audio src="https://example.com/a.mp3"></audio>',
    '<img src="a.png">',
    '[File](file:///private/a.pdf)',
    '[Local](content://provider/a)',
    '[Site](https://example.com)\n<!-- qp-link-preview: {"img":"local-thumbnail"} -->',
  ]) {
    test('blocks unsupported media $body', () {
      expect(
        () => validateTemplateContent(fixture(content: body)),
        throwsA(isA<TemplateException>()),
      );
    });
  }
  test('structured images, attachments and cached previews are blocked', () {
    for (final block in [
      {'type': 'image', 'url': 'https://example.com/image'},
      {'type': 'attachment', 'uri': 'qp://asset/id'},
      {
        'type': 'link_preview',
        'url': 'https://example.com',
        'thumbnailAssetId': 'local-id',
      },
    ]) {
      final content = jsonEncode({
        r'$schema': RichDocument.schemaId,
        'blocks': [block],
      });
      expect(
        () => validateTemplateContent(
          fixture(content: content, format: TemplateStorageFormat.richAst),
        ),
        throwsA(isA<TemplateException>()),
      );
    }
    validateTemplateContent(
      fixture(
        content: '[Note](qp://note/126d9d76-6348-4e29-bf9a-92807b31967f)',
      ),
    );
  });
  test(
    'ordinary text labels and normal links are not mistaken for asset URIs',
    () {
      validateTemplateContent(
        fixture(
          content:
              'Profile: A person\nContent: Text\n[Link](https://example.com/report.pdf)',
        ),
      );
    },
  );

  test('frontmatter title normalization only updates instantiated copy', () {
    const body =
        '---\ntitle: Old\ndate: 2020-01-02\nauthor: Author\ncustom: true\n---\n\nBody';
    for (final name in [
      'New',
      'Plan: Today #1',
      'বাংলা',
      'He said "hi"',
      r'Path\name',
      'true',
      '[List]',
    ]) {
      final template = fixture(name: name, content: body);
      final instantiated = instantiateTemplateContent(template);
      expect(FrontmatterEditorHelper.parse(instantiated).title, name);
      expect(
        instantiated,
        contains('date: 2020-01-02\nauthor: Author\ncustom: true'),
      );
      expect(template.content, body);
    }
  });
  test(
    'search trims and matches names only, favorites appear once in section order',
    () {
      final user = fixture(name: 'Zed', content: 'Meeting');
      final sections = templateSections([
        ...builtInTemplates.map(
          (t) => t.withFavorite(t.id == builtInTemplates[1].id),
        ),
        user,
      ], '');
      expect(sections.map((s) => s.title), [
        'Favorites',
        'My Templates',
        'Built-in Templates',
      ]);
      expect(sections.expand((s) => s.templates).length, 9);
      expect(
        templateSections([
          ...builtInTemplates,
          user,
        ], '  mEeTing ').single.templates.single.displayName,
        'Meeting Notes',
      );
      expect(templateSections([user], 'Meeting'), isEmpty);
    },
  );
  test('row previews extract bounded text without parsing the full AST', () {
    final valid = jsonEncode(
      const RichDocumentParser().parse('Hello **world**').toJson(),
    );
    expect(
      templateListSnippet(
        fixture(content: valid, format: TemplateStorageFormat.richAst),
      ),
      contains('Hello'),
    );
    // The row excerpt remains bounded and available even for a malformed tail.
    expect(
      templateListSnippet(
        fixture(
          content: valid.substring(0, valid.length - 2),
          format: TemplateStorageFormat.richAst,
        ),
      ),
      contains('Hello'),
    );
  });

  test('1,000 catalog entries sort/search without deserializing bodies', () {
    final templates = List.generate(
      1000,
      (i) => fixture(
        name: 'Template $i',
        content: 'not parsed as json',
        format: TemplateStorageFormat.richAst,
      ),
    );
    expect(templateSections(templates, '').single.templates.length, 1000);
    expect(
      templateSections(templates, 'Template 999').single.templates.length,
      1,
    );
  });
}
