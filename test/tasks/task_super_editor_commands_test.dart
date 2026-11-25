import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:super_editor/super_editor.dart';

class _Typography extends TypographySettingsNotifier {
  _Typography() : super(null) {
    state = const TypographySettings();
  }
}

void main() {
  String markdown(QuietSuperEditorController controller) =>
      serializeDocumentToMarkdown(
        controller.editor!.document,
        customNodeSerializers: const [QuietTaskNodeSerializer()],
      );
  Future<void> show(
    WidgetTester tester,
    QuietSuperEditorController controller,
    String source,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          typographySettingsProvider.overrideWith((ref) => _Typography()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuietSuperEditor(
              initialMarkdown: source,
              controller: controller,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Super Editor rename changes text and retains metadata, indent and native Undo',
    (tester) async {
      final controller = QuietSuperEditorController();
      const source =
          '- [ ] Parent\n  - [ ] **Original** <!-- qp-task:v1 id=03fe77cf-8000-4d05-ba80-d365fd69b17c due=2026-11-27 -->\n\nTail';
      await show(tester, controller, source);
      final nodes = controller.editor!.document.whereType<TaskNode>().toList();
      final id = nodes.last.id;
      controller.applyTaskContent(
        source,
        TaskDocument.rename(
          source,
          TaskDocument.extract(source).last,
          'Renamed',
        ),
      );
      await tester.pumpAndSettle();
      final renamed = controller.editor!.document.getNodeById(id)! as TaskNode;
      expect(renamed.text.toPlainText(), 'Renamed');
      expect(renamed.indent, 1);
      expect(
        TaskDocument.extract(
          markdown(controller),
        ).last.metadata!.due.toString(),
        '2026-11-27',
      );
      controller.undo();
      await tester.pumpAndSettle();
      expect(markdown(controller), contains('**Original**'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final source in [
    '- [ ] Legacy\n- [ ] Sibling\n\nTail',
    '- [ ] Parent\n  - [ ] Child\n    - [ ] Grandchild\n- [ ] Sibling\n\nTail',
    '- [ ] Only',
  ]) {
    testWidgets(
      'Super Editor delete and restore through undoable node requests: $source',
      (tester) async {
        final controller = QuietSuperEditorController();
        await show(tester, controller, source);
        final before = markdown(controller);
        final originalTasks = TaskDocument.extract(
          before,
        ).map((task) => task.text).toList();
        final tail = controller.editor!.document.last;
        final deleted = TaskDocument.delete(
          before,
          TaskDocument.extract(before).first,
        );
        controller.applyTaskContent(before, deleted);
        await tester.pumpAndSettle();
        expect(
          TaskDocument.extract(markdown(controller)).map((task) => task.text),
          TaskDocument.extract(deleted).map((task) => task.text),
        );
        if (source.contains('Tail')) {
          expect(controller.editor!.document.last.id, tail.id);
        }
        controller.applyTaskContent(markdown(controller), before);
        await tester.pumpAndSettle();
        expect(
          TaskDocument.extract(markdown(controller)).map((task) => task.text),
          originalTasks,
        );
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          TaskDocument.extract(markdown(controller)).map((task) => task.text),
          TaskDocument.extract(deleted).map((task) => task.text),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
}
