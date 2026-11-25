import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';

const id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
void main() {
  test('date-only validation and calendar arithmetic', () {
    expect(
      TaskDate.tryParse('2024-02-29')!.addDays(1).toString(),
      '2024-03-01',
    );
    for (final s in [
      '2026-02-29',
      '2026-13-01',
      '0000-01-01',
      '2026-1-01',
      '2026-04-31',
      '2026-11-25T00:00Z',
    ]) {
      expect(TaskDate.tryParse(s), isNull);
    }
    expect(
      TaskDate.local(DateTime(2026, 3, 8)).addDays(7).toString(),
      '2026-03-15',
    );
  });
  test('strict reserved metadata leaves malformed and inline code literal', () {
    for (final s in [
      'text <!-- qp-task:v2 id=$id -->',
      'text <!-- qp-task:v1 id=$id due=2026-02-29 -->',
      'text <!-- qp-task:v1 id=$id other=x -->',
      '`text <!-- qp-task:v1 id=$id -->',
      'text \\<!-- qp-task:v1 id=$id -->',
    ]) {
      expect(TaskMetadata.parseTerminal(s).metadata, isNull);
    }
    expect(
      TaskMetadata.parseTerminal(
        'text <!-- qp-task:v1 id=$id -->',
      ).metadata!.id,
      id,
    );
  });
  test(
    'quoted ordered nested tasks exclude frontmatter fences escapes and HTML',
    () {
      const source =
          '---\nexample: - [ ] no\n---\n# Work\n1. [ ] **First**\n  - [x] Nested\n> 2) [ ] Quoted\n\\- [ ] escaped\n````md\n- [ ] literal\n```\n- [ ] still literal\n````\n<!--\n- [ ] hidden\n-->\n';
      final tasks = TaskDocument.extract(source);
      expect(tasks.map((t) => t.text), ['First', 'Nested', 'Quoted']);
      expect(tasks.map((t) => t.heading), everyElement('Work'));
    },
  );
  test('CRLF target mutation preserves all unaffected bytes and descendants', () {
    const source =
        '---\r\ntitle: Keep\r\n---\r\n* [ ] Parent\r\n  + [x] child\r\n    continuation ![a](qp://asset/x)\r\n';
    final tasks = TaskDocument.extract(source);
    final toggled = TaskDocument.setCompleted(source, tasks.first, true);
    expect(toggled, source.replaceFirst('* [ ]', '* [x]'));
    final dated = TaskDocument.setDate(
      source,
      tasks.first,
      TaskDate.tryParse('2026-11-27'),
      newId: id,
    );
    expect(
      dated,
      source.replaceFirst(
        'Parent',
        'Parent <!-- qp-task:v1 id=$id due=2026-11-27 -->',
      ),
    );
    final clear = TaskDocument.setDate(
      dated,
      TaskDocument.extract(dated).first,
      null,
    );
    expect(TaskDocument.extract(clear).first.metadata!.id, id);
    expect(TaskDocument.extract(clear).first.metadata!.due, isNull);
  });
  test(
    'legacy locators reject any newer content; durable ids follow reorder',
    () {
      const source = '- [ ] same\n- [ ] same';
      expect(
        () => TaskDocument.resolve(
          '$source\ntext',
          expectedVersion: TaskDocument.version(source),
          ordinal: 0,
        ),
        throwsA(isA<StaleTask>()),
      );
      const dated = '- [ ] same <!-- qp-task:v1 id=$id -->';
      expect(
        TaskDocument.resolve(
          '- [ ] other\n$dated',
          expectedVersion: 'old',
          ordinal: 0,
          taskId: id,
        ).ordinal,
        1,
      );
      expect(
        () => TaskDocument.resolve(
          '$dated\n$dated',
          expectedVersion: 'old',
          ordinal: 0,
          taskId: id,
        ),
        throwsA(isA<StaleTask>()),
      );
    },
  );
  test('rich round-trip hides metadata and preserves unrelated raw nodes', () {
    const source = '- [ ] **Write** <!-- qp-task:v1 id=$id due=2026-11-27 -->';
    final doc = const RichDocumentParser().parse(source);
    expect(doc.plainText, 'Write');
    expect(const RichDocumentSerializer().serialize(doc), source);
    final data = doc.toJson();
    (data['blocks'] as List).add({
      'type': 'paragraph',
      'id': 'keep',
      'spans': [
        {'text': 'unchanged'},
      ],
      'future': 17,
    });
    final rich = jsonEncode(data);
    final changed =
        jsonDecode(
              TaskDocument.setCompleted(
                rich,
                TaskDocument.extract(rich).first,
                true,
              ),
            )
            as Map;
    expect((changed['blocks'] as List).last, (data['blocks'] as List).last);
    expect(
      TaskDocument.extract(jsonEncode(changed)).single.metadata!.due.toString(),
      '2026-11-27',
    );
    expect(
      RichDocument.fromJson(
        changed.cast<String, dynamic>(),
      ).blocks.first.plainText,
      'Write',
    );
  });
  test(
    'capture is single literal task, retries once, copies rekey dates and templates clear dates',
    () {
      final source = TaskDocument.append(
        'Existing\r\n',
        'Buy [milk] **today** 😀',
        id,
        TaskDate.tryParse('2026-11-27'),
      );
      expect(TaskDocument.extract(source), hasLength(1));
      expect(
        TaskDocument.append(
          source,
          'Buy [milk] **today** 😀',
          id,
          TaskDate.tryParse('2026-11-27'),
        ),
        source,
      );
      expect(
        () => TaskDocument.append(source, 'one\ntwo', id, null),
        throwsA(isA<StaleTask>()),
      );
      final copy = TaskDocument.extract(
        TaskDocument.rekey(source),
      ).single.metadata!;
      expect(copy.id, isNot(id));
      expect(copy.due.toString(), '2026-11-27');
      final template = TaskDocument.extract(
        TaskDocument.rekey(source, clearDates: true),
      ).single.metadata!;
      expect(template.id, isNot(id));
      expect(template.due, isNull);
      expect(TaskDocument.visibleMarkdown(source), isNot(contains(id)));
    },
  );
}
