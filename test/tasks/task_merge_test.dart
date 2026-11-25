import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/sync/conflict/markdown_merge_engine.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';

const id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
void main() {
  const engine = MarkdownMergeEngine();
  for (final rich in [false, true]) {
    test(
      'independent completion/date merge in ${rich ? 'rich JSON' : 'Markdown'}',
      () {
        const md =
            '- [ ] Send estimate <!-- qp-task:v1 id=$id due=2026-11-27 -->';
        final base = rich
            ? jsonEncode(const RichDocumentParser().parse(md).toJson())
            : md;
        final local = TaskDocument.setCompleted(
          base,
          TaskDocument.extract(base).single,
          true,
        );
        final remote = TaskDocument.setDate(
          base,
          TaskDocument.extract(base).single,
          TaskDate.tryParse('2026-11-28'),
        );
        final merged = engine.merge(base: base, local: local, remote: remote);
        expect(merged.isClean, isTrue);
        final task = TaskDocument.extract(merged.mergedValue).single;
        expect(task.completed, isTrue);
        expect(task.metadata!.due.toString(), '2026-11-28');
      },
    );
    test(
      'competing deadlines and deletion/edit retain recoverable conflicts ${rich ? 'rich' : 'source'}',
      () {
        const md =
            '- [ ] Send estimate <!-- qp-task:v1 id=$id due=2026-11-27 -->';
        final base = rich
            ? jsonEncode(const RichDocumentParser().parse(md).toJson())
            : md;
        final local = TaskDocument.setDate(
          base,
          TaskDocument.extract(base).single,
          TaskDate.tryParse('2026-11-28'),
        );
        final remote = TaskDocument.setDate(
          base,
          TaskDocument.extract(base).single,
          TaskDate.tryParse('2026-11-29'),
        );
        expect(
          engine.merge(base: base, local: local, remote: remote).isClean,
          isFalse,
        );
        expect(
          engine.merge(base: base, local: '', remote: remote).isClean,
          isFalse,
        );
      },
    );
  }
}
