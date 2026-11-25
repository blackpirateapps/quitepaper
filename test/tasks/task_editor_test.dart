import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_text_input_formatter.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_parser.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:super_editor/super_editor.dart';

const id = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
void main() {
  for (final prefix in ['- ', '1. ', '> - ', '  - ']) {
    test('Visual and Super Editor metadata round trip $prefix', () {
      final source =
          '$prefix[ ] **Estimate** <!-- qp-task:v1 id=$id due=2026-11-27 -->';
      final controller = RichDocumentController(initialMarkdown: source);
      expect(
        TaskDocument.extract(controller.toJsonString()).single.metadata!.id,
        id,
      );
      expect(controller.toMarkdown(), source);
      final doc = deserializeQuietMathDocument(source);
      expect(doc.whereType<TaskNode>().single.text.toPlainText(), 'Estimate');
      expect(
        serializeDocumentToMarkdown(
          doc,
          customNodeSerializers: [const QuietTaskNodeSerializer()],
        ).trimRight(),
        source,
      );
      controller.dispose();
    });
  }
  test(
    'Visual Enter and IME split retain first metadata, continuation has no date or identity',
    () {
      final c = RichDocumentController(
        initialMarkdown:
            '- [ ] FirstSecond <!-- qp-task:v1 id=$id due=2026-11-27 -->',
      );
      final first = c.document.blocks.first;
      c.updateSelection(
        RichDocumentSelection.collapsed(
          RichDocumentPosition(blockIndex: 0, blockId: first.id, offset: 5),
        ),
      );
      c.handleEnter();
      final tasks = TaskDocument.extract(c.toJsonString());
      expect(tasks.first.metadata!.id, id);
      expect(tasks.last.metadata, isNull);
      c.undo();
      expect(TaskDocument.extract(c.toJsonString()), hasLength(1));
      c.updateChecklistInput(
        0,
        const RichDocumentParser()
            .parse('First\nSecond')
            .blocks
            .expand((b) => b.spans)
            .toList(),
        caretOffset: 3,
      );
      c.dispose();
    },
  );
  test(
    'platform multiline continuation clears inherited metadata on later rows',
    () {
      final c = RichDocumentController(
        initialMarkdown:
            '- [ ] First <!-- qp-task:v1 id=$id due=2026-11-27 -->',
      );
      final spans =
          (const RichDocumentParser().parse('First').blocks.first
                  as ParagraphBlock)
              .spans;
      c.updateChecklistInput(0, [
        spans.first.copyWith(text: 'First\nSecond'),
      ], caretOffset: 8);
      expect(
        TaskDocument.extract(c.toJsonString()).map((t) => t.metadata?.id),
        [id, null],
      );
      c.undo();
      expect(TaskDocument.extract(c.toJsonString()).single.metadata!.id, id);
      c.dispose();
    },
  );
  test('Source Enter before metadata keeps date on original line', () {
    const source =
        '- [ ] FirstSecond <!-- qp-task:v1 id=$id due=2026-11-27 -->';
    const offset = 11;
    final old = TextEditingValue(
      text: source,
      selection: const TextSelection.collapsed(offset: offset),
    );
    final next = TextEditingValue(
      text: source.replaceRange(offset, offset, '\n'),
      selection: const TextSelection.collapsed(offset: offset + 1),
    );
    final result = const MarkdownTextInputFormatter().formatEditUpdate(
      old,
      next,
    );
    final tasks = TaskDocument.extract(result.text);
    expect(tasks, hasLength(2));
    expect(tasks.first.metadata!.id, id);
    expect(tasks.last.metadata, isNull);
  });
  test('unknown rich task metadata survives ordinary field copy', () {
    final source = jsonEncode({
      '\$schema': 'quietpaper:rich_document:v1',
      'blocks': [
        {
          'type': 'checklist_item',
          'id': 'node',
          'spans': [
            {'text': 'Task'},
          ],
          'task': {'v': 2, 'future': true},
        },
      ],
    });
    final c = RichDocumentController(initialMarkdown: source);
    c.toggleChecklistItemChecked(0);
    expect(jsonDecode(c.toJsonString())['blocks'][0]['task'], {
      'v': 2,
      'future': true,
    });
    c.dispose();
  });
}
