import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_parser.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/smart_task_controller.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

class _MockTypographyNotifier extends TypographySettingsNotifier {
  _MockTypographyNotifier(TypographySettings settings) : super(null) {
    state = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required String markdown,
    ValueChanged<String>? onChanged,
    QuietSuperEditorController? controller,
    FocusNode? focusNode,
    TypographySettings typography = const TypographySettings(),
  }) {
    return ProviderScope(
      overrides: [
        typographySettingsProvider.overrideWith(
          (ref) => _MockTypographyNotifier(typography),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
        home: Scaffold(
          body: QuietSuperEditor(
            initialMarkdown: markdown,
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  for (final spaces in [2, 4]) {
    test('CL-08 nested task parse/serialize preserves states at $spaces spaces', () {
      final indent = ' ' * spaces;
      final source = '- [ ] **Parent**\n$indent- [ ] Child\n$indent$indent- [x] Grandchild\n- [ ] Sibling';
      final doc = deserializeQuietMathDocument(source);
      final tasks = List.generate(doc.nodeCount, doc.getNodeAt).cast<TaskNode>();
      expect(tasks.map((t) => t.text.toPlainText()), ['Parent', 'Child', 'Grandchild', 'Sibling']);
      expect(tasks.map((t) => t.indent), [0, spaces ~/ 2, spaces, 0]);
      expect(tasks.map((t) => t.isComplete), [false, false, true, false]);
      expect(tasks.first.text.hasAttributionAt(0, attribution: boldAttribution), isTrue);
      expect(serializeDocumentToMarkdown(doc, customNodeSerializers: [const QuietTaskNodeSerializer()]).trimRight(), source);
    });
  }

  testWidgets('CL-08 nested task edits save every task and completion state', (tester) async {
    final controller = QuietSuperEditorController();
    String? saved;
    await tester.pumpWidget(buildTestWidget(
      markdown: '- [ ] Parent\n  - [ ] Child\n    - [x] Grandchild\n- [ ] Sibling',
      controller: controller, onChanged: (value) => saved = value,
    ));
    await tester.pumpAndSettle();
    final task = controller.editor!.document.getNodeAt(3)! as TaskNode;
    controller.editor!.execute([ChangeSelectionRequest(
      DocumentSelection.collapsed(position: DocumentPosition(
        nodeId: task.id, nodePosition: const TextNodePosition(offset: 7),
      )), SelectionChangeType.placeCaret, SelectionReason.userInteraction,
    )]);
    controller.insertSnippet('x');
    await tester.pumpAndSettle();
    expect(saved, contains('- [ ] Parent\n  - [ ] Child\n    - [x] Grandchild\n- [ ] Siblingx'));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  group('SmartTaskController Unit Tests', () {
    test('findTaskBlocks finds isolated contiguous task blocks', () {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(id: '0', text: AttributedText('Section 1')),
          TaskNode(id: '1', text: AttributedText('T1'), isComplete: false),
          TaskNode(id: '2', text: AttributedText('T2'), isComplete: true),
          ParagraphNode(id: '3', text: AttributedText('Section 2')),
          TaskNode(id: '4', text: AttributedText('T3'), isComplete: false),
        ],
      );

      final blocks = SmartTaskController.findTaskBlocks(doc);
      expect(blocks.length, equals(2));

      expect(blocks[0].startIndex, equals(1));
      expect(blocks[0].endIndex, equals(2));
      expect(blocks[0].tasks.length, equals(2));
      expect(blocks[0].hasCollapsibleCompleted, isFalse);

      expect(blocks[1].startIndex, equals(4));
      expect(blocks[1].endIndex, equals(4));
      expect(blocks[1].tasks.length, equals(1));
    });

    test(
      'calculateDestinationIndex when checking moves item to bottom of contiguous block',
      () {
        final doc = MutableDocument(
          nodes: [
            ParagraphNode(id: '0', text: AttributedText('Header')),
            TaskNode(
              id: '1',
              text: AttributedText('Task A'),
              isComplete: false,
            ),
            TaskNode(
              id: '2',
              text: AttributedText('Task B'),
              isComplete: false,
            ),
            TaskNode(
              id: '3',
              text: AttributedText('Task C'),
              isComplete: false,
            ),
            ParagraphNode(id: '4', text: AttributedText('Footer')),
          ],
        );

        // Checking Task A (index 1) should move it to index 3 (bottom of block)
        final destA = SmartTaskController.calculateDestinationIndex(
          document: doc,
          nodeId: '1',
          isComplete: true,
        );
        expect(destA, equals(3));

        // Task C is already at bottom (index 3), so destination is null (no move needed)
        final destC = SmartTaskController.calculateDestinationIndex(
          document: doc,
          nodeId: '3',
          isComplete: true,
        );
        expect(destC, isNull);
      },
    );

    test(
      'calculateDestinationIndex when unchecking moves item to bottom of active items',
      () {
        final doc = MutableDocument(
          nodes: [
            TaskNode(
              id: '1',
              text: AttributedText('Active 1'),
              isComplete: false,
            ),
            TaskNode(id: '2', text: AttributedText('Done 1'), isComplete: true),
            TaskNode(id: '3', text: AttributedText('Done 2'), isComplete: true),
          ],
        );

        // Unchecking Done 2 (index 2) should move it after Active 1 (index 1)
        final destDone2 = SmartTaskController.calculateDestinationIndex(
          document: doc,
          nodeId: '3',
          isComplete: false,
        );
        expect(destDone2, equals(1));

        // Done 1 is already at index 1 (immediately after Active 1), so no move needed
        final destDone1 = SmartTaskController.calculateDestinationIndex(
          document: doc,
          nodeId: '2',
          isComplete: false,
        );
        expect(destDone1, isNull);
      },
    );

    test(
      'toggling an imported interleaved block restores stable active/completed groups',
      () {
        final doc = MutableDocument(
          nodes: [
            ParagraphNode(id: 'before', text: AttributedText('Before')),
            TaskNode(
              id: 'doneA',
              text: AttributedText('Done A'),
              isComplete: true,
            ),
            TaskNode(
              id: 'activeB',
              text: AttributedText('Active B'),
              isComplete: false,
            ),
            TaskNode(
              id: 'doneC',
              text: AttributedText('Done C'),
              isComplete: true,
            ),
            TaskNode(
              id: 'activeD',
              text: AttributedText('Active D'),
              isComplete: false,
            ),
            ParagraphNode(id: 'after', text: AttributedText('After')),
          ],
        );
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(
          document: doc,
          composer: composer,
          isHistoryEnabled: true,
        );
        final controller = SmartTaskController();
        controller.toggleTaskCompletion(
          editor: editor,
          nodeId: 'doneA',
          isComplete: false,
        );
        expect(
          SmartTaskController.findTaskBlocks(
            doc,
          ).single.tasks.map((task) => task.id),
          ['activeB', 'activeD', 'doneA', 'doneC'],
        );
        expect(doc.first.id, 'before');
        expect(doc.last.id, 'after');
        editor.undo();
        expect(
          SmartTaskController.findTaskBlocks(
            doc,
          ).single.tasks.map((task) => task.id),
          ['doneA', 'activeB', 'doneC', 'activeD'],
        );
        editor.dispose();
        composer.dispose();
        controller.dispose();
      },
    );

    test('nested checklists retain parent/child order and indentation', () {
      final doc = MutableDocument(
        nodes: [
          TaskNode(
            id: 'parent',
            text: AttributedText('Parent'),
            isComplete: false,
          ),
          for (int i = 0; i < 4; i++)
            TaskNode(
              id: 'child$i',
              text: AttributedText('Child $i'),
              isComplete: true,
              indent: 1,
            ),
        ],
      );
      final controller = SmartTaskController();
      expect(
        SmartTaskController.calculateDestinationIndex(
          document: doc,
          nodeId: 'parent',
          isComplete: true,
        ),
        isNull,
      );
      expect(
        SmartTaskController.findTaskBlocks(doc).single.hasCollapsibleCompleted,
        isFalse,
      );
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(
        document: doc,
        composer: composer,
      );
      controller.toggleTaskCompletion(
        editor: editor,
        nodeId: 'parent',
        isComplete: true,
      );
      expect(doc.first.id, 'parent');
      final markdown = serializeDocumentToMarkdown(
        doc,
        customNodeSerializers: const [QuietTaskNodeSerializer()],
      );
      expect(markdown, contains('  - [x] Child 0'));
      editor.dispose();
      composer.dispose();
      controller.dispose();
    });

    test(
      'deleting down to three completed tasks resets expansion before rechecking',
      () {
        final doc = MutableDocument(
          nodes: [
            for (int i = 0; i < 5; i++)
              TaskNode(
                id: '$i',
                text: AttributedText('Task $i'),
                isComplete: i < 4,
              ),
          ],
        );
        final controller = SmartTaskController();
        controller.toggleBlockExpansion(
          SmartTaskController.findTaskBlocks(doc).single,
        );
        doc.deleteNodeAt(0);
        controller.reconcile(doc);
        final composer = MutableDocumentComposer();
        final editor = createDefaultDocumentEditor(
          document: doc,
          composer: composer,
        );
        controller.toggleTaskCompletion(
          editor: editor,
          nodeId: '4',
          isComplete: true,
        );
        expect(
          controller.isBlockExpanded(
            SmartTaskController.findTaskBlocks(doc).single,
          ),
          isFalse,
        );
        editor.dispose();
        composer.dispose();
        controller.dispose();
      },
    );

    test(
      'isBlockExpanded auto-collapses when completed count > 3 and toggles',
      () {
        final doc = MutableDocument(
          nodes: [
            TaskNode(id: '1', text: AttributedText('D1'), isComplete: true),
            TaskNode(id: '2', text: AttributedText('D2'), isComplete: true),
            TaskNode(id: '3', text: AttributedText('D3'), isComplete: true),
            TaskNode(id: '4', text: AttributedText('D4'), isComplete: true),
          ],
        );

        final controller = SmartTaskController();
        final block = SmartTaskController.findBlockForNode(doc, '1')!;

        expect(block.completedCount, equals(4));
        expect(block.hasCollapsibleCompleted, isTrue);

        // Collapsed by default
        expect(controller.isBlockExpanded(block), isFalse);

        // Expand
        controller.toggleBlockExpansion(block);
        expect(controller.isBlockExpanded(block), isTrue);

        // Collapse
        controller.toggleBlockExpansion(block);
        expect(controller.isBlockExpanded(block), isFalse);
      },
    );
  });

  group('QuietTaskComponent Visual & Alignment Tests', () {
    testWidgets(
      'empty task displays "New task..." placeholder matching text styling',
      (tester) async {
        const markdown = '- [ ] \n- [ ] Task with text';

        await tester.pumpWidget(buildTestWidget(markdown: markdown));
        await tester.pumpAndSettle();

        // "New task..." placeholder appears for the empty item
        expect(find.text('New task...'), findsOneWidget);
        // Non-empty item text appears
        expect(find.text('Task with text', findRichText: true), findsOneWidget);
      },
    );

    testWidgets(
      'checkbox has optical top padding centered with first line of text',
      (tester) async {
        const markdown = '- [ ] Align test';

        await tester.pumpWidget(
          buildTestWidget(
            markdown: markdown,
            typography: const TypographySettings(
              fontSize: 18.0,
              lineHeight: 1.6,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final quietTaskFinder = find.byType(QuietTaskComponent);
        expect(quietTaskFinder, findsOneWidget);

        // Locate the gesture detector around the checkbox icon
        final checkboxGesture = find
            .descendant(
              of: quietTaskFinder,
              matching: find.byType(GestureDetector),
            )
            .first;

        final paddingWidget = tester.widget<Padding>(
          find
              .ancestor(of: checkboxGesture, matching: find.byType(Padding))
              .first,
        );

        final insets = paddingWidget.padding as EdgeInsets;
        // Formula: ((18.0 * 1.6) - 20.0) / 2 = (28.8 - 20) / 2 = 4.4
        expect(insets.top, closeTo(4.4, 0.05));
      },
    );
  });

  group('Smart Todolist Interactive Journey Tests in SuperEditor', () {
    testWidgets(
      'checking an item moves it to the bottom of the checklist block',
      (tester) async {
        const initialMd = '''- [ ] First task
- [ ] Second task
- [ ] Third task
''';
        String currentMd = initialMd;

        await tester.pumpWidget(
          buildTestWidget(
            markdown: initialMd,
            onChanged: (val) => currentMd = val,
          ),
        );
        await tester.pumpAndSettle();

        // Tap checkbox for 'First task'
        final checkboxes = find.byIcon(PhosphorIconsRegular.square);
        expect(checkboxes, findsNWidgets(3));

        await tester.tap(checkboxes.at(0));
        await tester.pumpAndSettle();

        // First task should now be complete and moved to bottom
        expect(
          currentMd,
          contains('- [ ] Second task\n- [ ] Third task\n- [x] First task'),
        );
      },
    );

    testWidgets(
      'unchecking an item moves it back up to the bottom of active items',
      (tester) async {
        const initialMd = '''- [ ] Active task
- [x] Done task 1
- [x] Done task 2
''';
        String currentMd = initialMd;

        await tester.pumpWidget(
          buildTestWidget(
            markdown: initialMd,
            onChanged: (val) => currentMd = val,
          ),
        );
        await tester.pumpAndSettle();

        // Tap checked box for 'Done task 2'
        final checkedBoxes = find.byIcon(PhosphorIconsFill.checkSquare);
        expect(checkedBoxes, findsNWidgets(2));

        // Tap the second checked task ('Done task 2')
        await tester.tap(checkedBoxes.at(1));
        await tester.pumpAndSettle();

        // Done task 2 was unchecked, so it moves after Active task (before Done task 1)
        expect(
          currentMd,
          contains('- [ ] Active task\n- [ ] Done task 2\n- [x] Done task 1'),
        );
      },
    );

    testWidgets(
      'more than 3 completed items auto-collapse under summary header',
      (tester) async {
        const initialMd = '''- [ ] Pending task
- [x] Done 1
- [x] Done 2
- [x] Done 3
- [x] Done 4
''';

        await tester.pumpWidget(buildTestWidget(markdown: initialMd));
        await tester.pumpAndSettle();

        // Pending task is visible
        expect(find.text('Pending task', findRichText: true), findsOneWidget);

        // Summary header is visible with count 4 and caretRight
        expect(find.text('4 completed items'), findsOneWidget);
        expect(find.byIcon(PhosphorIconsBold.caretRight), findsOneWidget);

        // Tapping summary header expands the completed items
        await tester.tap(find.text('4 completed items'));
        await tester.pumpAndSettle();

        // Header now displays caretDown
        expect(find.byIcon(PhosphorIconsBold.caretDown), findsOneWidget);

        // All 4 completed tasks are rendered
        expect(find.text('Done 1', findRichText: true), findsOneWidget);
        expect(find.text('Done 2', findRichText: true), findsOneWidget);
        expect(find.text('Done 3', findRichText: true), findsOneWidget);
        expect(find.text('Done 4', findRichText: true), findsOneWidget);

        // Tapping summary header again collapses back
        await tester.tap(find.text('4 completed items'));
        await tester.pumpAndSettle();

        expect(find.byIcon(PhosphorIconsBold.caretRight), findsOneWidget);
      },
    );

    testWidgets(
      'unchecking an item so completed count drops to 3 automatically uncollapses',
      (tester) async {
        const initialMd = '''- [ ] Pending task
- [x] Done 1
- [x] Done 2
- [x] Done 3
- [x] Done 4
''';
        String currentMd = initialMd;

        await tester.pumpWidget(
          buildTestWidget(
            markdown: initialMd,
            onChanged: (val) => currentMd = val,
          ),
        );
        await tester.pumpAndSettle();

        // Initially collapsed: 4 completed items
        expect(find.text('4 completed items'), findsOneWidget);

        // Expand to uncheck
        await tester.tap(find.text('4 completed items'));
        await tester.pumpAndSettle();

        // Uncheck 'Done 4'
        final checkIcons = find.byIcon(PhosphorIconsFill.checkSquare);
        expect(checkIcons, findsNWidgets(4));
        await tester.tap(checkIcons.at(3));
        await tester.pumpAndSettle();

        // Now only 3 completed tasks remain -> automatically uncollapsed
        expect(find.text('4 completed items'), findsNothing);
        expect(find.text('3 completed items'), findsNothing);

        // All items are rendered inline
        expect(find.text('Pending task', findRichText: true), findsOneWidget);
        expect(find.text('Done 4', findRichText: true), findsOneWidget);
        expect(find.text('Done 1', findRichText: true), findsOneWidget);
        expect(find.text('Done 2', findRichText: true), findsOneWidget);
        expect(find.text('Done 3', findRichText: true), findsOneWidget);

        // Verify serialized markdown contains updated uncheck
        expect(currentMd, contains('- [ ] Done 4'));
      },
    );

    testWidgets(
      'checking a focused task keeps a visible caret below the collapsed list',
      (tester) async {
        const initialMd = '''- [ ] Task to check
- [x] Done 1
- [x] Done 2
- [x] Done 3
''';

        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(markdown: initialMd, controller: controller),
        );
        await tester.pumpAndSettle();

        // Tap on the text of 'Task to check' to give it focus/caret
        await tester.tap(
          find.text('Task to check', findRichText: true),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        // Tap the unchecked box to complete it
        final uncheckedBox = find.byIcon(PhosphorIconsRegular.square);
        expect(uncheckedBox, findsOneWidget);
        await tester.tap(uncheckedBox);
        await tester.pumpAndSettle();

        // Completed items now total 4, so they collapse under summary header
        expect(find.text('4 completed items'), findsOneWidget);

        expect(controller.composer!.selection, isNotNull);
        expect(
          controller.editor!.document.getNodeById(controller.selectedNodeId!),
          isA<ParagraphNode>(),
        );

        // Verify that the task component returns Rect.zero for collapsed items
        final taskState =
            tester.state(find.byType(QuietTaskComponent).first)
                as DocumentComponent;
        expect(
          taskState.getRectForPosition(const TextNodePosition(offset: 0)),
          equals(Rect.zero),
        );
      },
    );

    testWidgets('Android completion preserves focus, IME and unrelated caret', (
      tester,
    ) async {
      final controller = QuietSuperEditorController();
      final focus = FocusNode();
      await tester.pumpWidget(
        buildTestWidget(
          markdown: '- [ ] First task\n- [ ] Keep writing',
          controller: controller,
          focusNode: focus,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.text('Keep writing', findRichText: true)),
      );
      await tester.pumpAndSettle();
      final selection = controller.composer!.selection;
      expect(selection, isNotNull);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await tester.tap(find.byIcon(PhosphorIconsRegular.square).first);
      await tester.pumpAndSettle();
      expect(controller.composer!.selection, selection);
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focus.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'Android checking the focused task continues typing in next active row',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [ ] First task\n- [ ] Next task',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(find.text('First task', findRichText: true)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(PhosphorIconsRegular.square).first);
        await tester.pumpAndSettle();
        final selected =
            controller.editor!.document.getNodeById(controller.selectedNodeId!)
                as TaskNode;
        expect(selected.text.toPlainText(), 'Next task');
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        controller.insertSnippet('Continue ');
        await tester.pumpAndSettle();
        expect(
          (controller.editor!.document.first as TaskNode).text.toPlainText(),
          'Continue Next task',
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'paragraph below many folded rows has compact left-aligned caret geometry',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown:
                '${List.generate(20, (i) => '- [x] Completed item $i').join('\n')}\n\nParagraph below',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        final summary = tester.getRect(find.text('20 completed items'));
        final paragraph = tester.getRect(
          find.text('Paragraph below', findRichText: true),
        );
        expect(paragraph.top - summary.bottom, lessThan(25));
        await tester.tapAt(Offset(paragraph.left + 1, paragraph.center.dy));
        await tester.pumpAndSettle();
        final selection = controller.composer!.selection!;
        expect(
          controller.editor!.document.getNodeById(selection.extent.nodeId),
          isA<ParagraphNode>(),
        );
        final layout =
            tester.state(find.byType(SingleColumnDocumentLayout))
                as DocumentLayout;
        final caret = layout.getRectForPosition(selection.extent)!;
        final globalCaret = layout.getGlobalOffsetFromDocumentOffset(
          caret.topLeft,
        );
        expect(globalCaret.dx, closeTo(paragraph.left, 3));
        expect(globalCaret.dy, closeTo(paragraph.top, 3));
        controller.insertSnippet('New ');
        await tester.pumpAndSettle();
        expect(
          find.text('New Paragraph below', findRichText: true),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'arrow navigation skips folded tasks and empty task caret starts after checkbox',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown:
                '- [ ] \n- [x] One\n- [x] Two\n- [x] Three\n- [x] Four\n\nAfter',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.text('New task...')));
        await tester.pumpAndSettle();
        final layout =
            tester.state(find.byType(SingleColumnDocumentLayout))
                as DocumentLayout;
        final caret = layout.getRectForPosition(
          controller.composer!.selection!.extent,
        )!;
        final checkbox = tester.getRect(
          find.byIcon(PhosphorIconsRegular.square),
        );
        expect(
          layout.getGlobalOffsetFromDocumentOffset(caret.topLeft).dx,
          closeTo(checkbox.right + 8, 2),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          controller.editor!.document.getNodeById(controller.selectedNodeId!),
          isA<ParagraphNode>(),
        );
        expect(find.text('4 completed items'), findsOneWidget);
        expect(find.text('One', findRichText: true), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('collapse moves a selection whose base is in a completed task', (
      tester,
    ) async {
      final controller = QuietSuperEditorController();
      await tester.pumpWidget(
        buildTestWidget(
          markdown:
              '- [ ] Active\n- [x] One\n- [x] Two\n- [x] Three\n- [x] Four\n\nAfter',
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 completed items'));
      await tester.pumpAndSettle();
      final doc = controller.editor!.document;
      controller.editor!.execute([
        ChangeSelectionRequest(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: doc.getNodeAt(1)!.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: doc.last.id,
              nodePosition: const TextNodePosition(offset: 2),
            ),
          ),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 completed items'));
      await tester.pumpAndSettle();
      expect(controller.composer!.selection!.isCollapsed, isTrue);
      expect(controller.selectedNodeId, doc.first.id);
      expect(find.text('One', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rapid double toggle cancels pending completion without moving rows',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [ ] First\n- [ ] Second',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(PhosphorIconsRegular.square).first);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byIcon(PhosphorIconsFill.checkSquare));
        await tester.pumpAndSettle();
        final tasks = SmartTaskController.findTaskBlocks(
          controller.editor!.document,
        ).single.tasks;
        expect(tasks.map((task) => task.text.toPlainText()), [
          'First',
          'Second',
        ]);
        expect(tasks.every((task) => !task.isComplete), isTrue);
        expect(controller.canUndo, isFalse);
      },
    );

    testWidgets(
      'completion, collapse and writing position undo and redo together',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [ ] Last active\n- [x] One\n- [x] Two\n- [x] Three',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getCenter(find.text('Last active', findRichText: true)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(PhosphorIconsRegular.square));
        await tester.pumpAndSettle();
        expect(controller.editor!.document.last, isA<ParagraphNode>());
        expect(tester.testTextInput.isVisible, isTrue);
        controller.undo();
        await tester.pumpAndSettle();
        expect(controller.editor!.document.nodeCount, 4);
        expect(
          (controller.editor!.document.first as TaskNode).isComplete,
          isFalse,
        );
        expect(find.text('4 completed items'), findsNothing);
        controller.redo();
        await tester.pumpAndSettle();
        expect(find.text('4 completed items'), findsOneWidget);
        expect(
          controller.editor!.document.getNodeById(controller.selectedNodeId!),
          isA<ParagraphNode>(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final useIme in [false, true]) {
      testWidgets(
        'backspace below a folded list reveals tasks without consuming paragraph (IME: $useIme)',
        (tester) async {
          final controller = QuietSuperEditorController();
          await tester.pumpWidget(
            buildTestWidget(
              markdown:
                  '- [x] One\n- [x] Two\n- [x] Three\n- [x] Four\n\nKeep paragraph',
              controller: controller,
            ),
          );
          await tester.pumpAndSettle();
          final paragraphRect = tester.getRect(
            find.text('Keep paragraph', findRichText: true),
          );
          await tester.tapAt(
            Offset(paragraphRect.left + 1, paragraphRect.center.dy),
          );
          await tester.pumpAndSettle();
          final before = controller.editor!.document;
          final paragraphId = before.last.id;
          if (useIme) {
            controller.editor!.execute([
              DeleteUpstreamAtBeginningOfNodeRequest(before.last),
            ]);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          }
          await tester.pumpAndSettle();
          expect(find.text('Four', findRichText: true), findsOneWidget);
          expect(
            find.text('Keep paragraph', findRichText: true),
            findsOneWidget,
          );
          expect(before.nodeCount, 5);
          expect(before.last.id, paragraphId);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
    }

    testWidgets(
      'Delete before a folded list reveals it without merging task text',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown:
                '- [ ] Active\n- [x] One\n- [x] Two\n- [x] Three\n- [x] Four',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        final active = tester.getRect(find.text('Active', findRichText: true));
        await tester.tapAt(Offset(active.right - 1, active.center.dy));
        await tester.pumpAndSettle();
        // End is independent of the width occupied by the rich-text widget.
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();
        expect(find.text('One', findRichText: true), findsOneWidget);
        expect(
          (controller.editor!.document.first as TaskNode).text.toPlainText(),
          'Active',
        );
        expect(
          SmartTaskController.findTaskBlocks(
            controller.editor!.document,
          ).single.tasks.length,
          5,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'opening an all-completed note allows immediate typing below the summary',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [x] One\n- [x] Two\n- [x] Three\n- [x] Four',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        final summary = tester.getRect(find.text('4 completed items'));
        await tester.tapAt(Offset(2, summary.bottom + 15));
        await tester.pumpAndSettle();
        final doc = controller.editor!.document;
        expect(
          doc.getNodeById(controller.selectedNodeId!),
          isA<ParagraphNode>(),
        );
        final layout =
            tester.state(find.byType(SingleColumnDocumentLayout))
                as DocumentLayout;
        final caret = layout.getRectForPosition(
          controller.composer!.selection!.extent,
        )!;
        expect(
          layout.getGlobalOffsetFromDocumentOffset(caret.topLeft).dx,
          lessThan(5),
        );
        expect(
          layout.getGlobalOffsetFromDocumentOffset(caret.topLeft).dy -
              summary.bottom,
          lessThan(25),
        );
        expect(tester.testTextInput.isVisible, isTrue);
        controller.insertSnippet('Notes below');
        await tester.pumpAndSettle();
        expect(find.text('Notes below', findRichText: true), findsOneWidget);
        expect(doc.nodeCount, 5);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'IME or programmatic selection reveals a folded task before editing',
      (tester) async {
        final controller = QuietSuperEditorController();
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [x] One\n- [x] Two\n- [x] Three\n- [x] Four',
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
        controller.editor!.execute([
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: controller.editor!.document.first.id,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('One', findRichText: true), findsOneWidget);
        controller.insertSnippet('Edit ');
        await tester.pumpAndSettle();
        expect(find.text('Edit One', findRichText: true), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a pending checkbox callback is cancelled when the editor is removed',
      (tester) async {
        int changes = 0;
        await tester.pumpWidget(
          buildTestWidget(
            markdown: '- [ ] First\n- [ ] Second',
            onChanged: (_) => changes++,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(PhosphorIconsRegular.square).first);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(changes, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping checkbox exhibits immediate visual completion and smooth dwell',
      (tester) async {
        const initialMd = '''- [ ] Dwell task
- [ ] Another task
''';
        String currentMd = initialMd;

        await tester.pumpWidget(
          buildTestWidget(
            markdown: initialMd,
            onChanged: (val) => currentMd = val,
          ),
        );
        await tester.pumpAndSettle();

        final firstBox = find.byIcon(PhosphorIconsRegular.square).first;
        await tester.tap(firstBox);
        // Pump only 50ms (before the 250ms delay completes)
        await tester.pump(const Duration(milliseconds: 50));

        // Visually, the box immediately flipped to checkmark (optimistic visual feedback)
        expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

        // Document has NOT moved yet (giving user peaceful dwell time)
        expect(currentMd, equals(initialMd));

        // After completing the 250ms dwell animation:
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Now the document move has completed
        expect(currentMd, contains('- [ ] Another task\n- [x] Dwell task'));
      },
    );

    testWidgets(
      'paragraphs following a completed task list are not merged, struck through, or collapsed',
      (tester) async {
        const initialMd = '''- [ ] new item
- [x] item 1
- [x] item 2
- [x] item 3
- [x] item 4
- [x] item 5
new thins
hey thanks
''';

        await tester.pumpWidget(buildTestWidget(markdown: initialMd));
        await tester.pumpAndSettle();

        // The completed items should be collapsed under "5 completed items"
        expect(find.text('5 completed items'), findsOneWidget);

        // Paragraphs following the task list MUST remain visible outside the collapse
        expect(
          find.textContaining('new thins', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('hey thanks', findRichText: true),
          findsOneWidget,
        );

        // Verify that 'new thins' is in a ParagraphComponent (not a QuietTaskComponent)
        final paragraphWidget = tester.firstWidget<ParagraphComponent>(
          find.byType(ParagraphComponent),
        );
        expect(
          paragraphWidget.viewModel.text.toPlainText(),
          contains('new thins'),
        );
        expect(
          paragraphWidget.viewModel.text.hasAttributionAt(
            0,
            attribution: strikethroughAttribution,
          ),
          isFalse,
        );
      },
    );

    test(
      'QuietTaskNodeSerializer outputs blank line before following non-task node',
      () {
        final doc = MutableDocument(
          nodes: [
            TaskNode(id: '1', text: AttributedText('task 1'), isComplete: true),
            ParagraphNode(
              id: '2',
              text: AttributedText('paragraph after task'),
            ),
          ],
        );

        final serialized = serializeDocumentToMarkdown(
          doc,
          syntax: MarkdownSyntax.normal,
          customNodeSerializers: const [QuietTaskNodeSerializer()],
        );

        // Must be separated by blank line (\n\n) so CommonMark doesn't merge them
        expect(serialized, contains('- [x] task 1\n\nparagraph after task'));
      },
    );
  });
}
