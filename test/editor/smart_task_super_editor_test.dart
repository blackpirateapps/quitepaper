import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
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
    TypographySettings typography = const TypographySettings(),
  }) {
    return ProviderScope(
      overrides: [
        typographySettingsProvider.overrideWith(
          (ref) => _MockTypographyNotifier(typography),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: Scaffold(
          body: QuietSuperEditor(
            initialMarkdown: markdown,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('SmartTaskController Unit Tests', () {
    test('findTaskBlocks finds isolated contiguous task blocks', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: '0', text: AttributedText('Section 1')),
        TaskNode(id: '1', text: AttributedText('T1'), isComplete: false),
        TaskNode(id: '2', text: AttributedText('T2'), isComplete: true),
        ParagraphNode(id: '3', text: AttributedText('Section 2')),
        TaskNode(id: '4', text: AttributedText('T3'), isComplete: false),
      ]);

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

    test('calculateDestinationIndex when checking moves item to bottom of contiguous block', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: '0', text: AttributedText('Header')),
        TaskNode(id: '1', text: AttributedText('Task A'), isComplete: false),
        TaskNode(id: '2', text: AttributedText('Task B'), isComplete: false),
        TaskNode(id: '3', text: AttributedText('Task C'), isComplete: false),
        ParagraphNode(id: '4', text: AttributedText('Footer')),
      ]);

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
    });

    test('calculateDestinationIndex when unchecking moves item to bottom of active items', () {
      final doc = MutableDocument(nodes: [
        TaskNode(id: '1', text: AttributedText('Active 1'), isComplete: false),
        TaskNode(id: '2', text: AttributedText('Done 1'), isComplete: true),
        TaskNode(id: '3', text: AttributedText('Done 2'), isComplete: true),
      ]);

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
    });

    test('isBlockExpanded auto-collapses when completed count > 3 and toggles', () {
      final doc = MutableDocument(nodes: [
        TaskNode(id: '1', text: AttributedText('D1'), isComplete: true),
        TaskNode(id: '2', text: AttributedText('D2'), isComplete: true),
        TaskNode(id: '3', text: AttributedText('D3'), isComplete: true),
        TaskNode(id: '4', text: AttributedText('D4'), isComplete: true),
      ]);

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
    });
  });

  group('QuietTaskComponent Visual & Alignment Tests', () {
    testWidgets('empty task displays "New task..." placeholder matching text styling', (tester) async {
      const markdown = '- [ ] \n- [ ] Task with text';

      await tester.pumpWidget(
        buildTestWidget(markdown: markdown),
      );
      await tester.pumpAndSettle();

      // "New task..." placeholder appears for the empty item
      expect(find.text('New task...'), findsOneWidget);
      // Non-empty item text appears
      expect(find.text('Task with text', findRichText: true), findsOneWidget);
    });

    testWidgets('checkbox has optical top padding centered with first line of text', (tester) async {
      const markdown = '- [ ] Align test';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          typography: const TypographySettings(fontSize: 18.0, lineHeight: 1.6),
        ),
      );
      await tester.pumpAndSettle();

      final quietTaskFinder = find.byType(QuietTaskComponent);
      expect(quietTaskFinder, findsOneWidget);

      // Locate the gesture detector around the checkbox icon
      final checkboxGesture = find.descendant(
        of: quietTaskFinder,
        matching: find.byType(GestureDetector),
      ).first;

      final paddingWidget = tester.widget<Padding>(
        find.ancestor(
          of: checkboxGesture,
          matching: find.byType(Padding),
        ).first,
      );

      final insets = paddingWidget.padding as EdgeInsets;
      // Formula: ((18.0 * 1.6) - 20.0) / 2 = (28.8 - 20) / 2 = 4.4
      expect(insets.top, closeTo(4.4, 0.05));
    });
  });

  group('Smart Todolist Interactive Journey Tests in SuperEditor', () {
    testWidgets('checking an item moves it to the bottom of the checklist block', (tester) async {
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
      expect(currentMd, contains('- [ ] Second task\n- [ ] Third task\n- [x] First task'));
    });

    testWidgets('unchecking an item moves it back up to the bottom of active items', (tester) async {
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
      expect(currentMd, contains('- [ ] Active task\n- [ ] Done task 2\n- [x] Done task 1'));
    });

    testWidgets('more than 3 completed items auto-collapse under summary header', (tester) async {
      const initialMd = '''- [ ] Pending task
- [x] Done 1
- [x] Done 2
- [x] Done 3
- [x] Done 4
''';

      await tester.pumpWidget(
        buildTestWidget(markdown: initialMd),
      );
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
    });

    testWidgets('unchecking an item so completed count drops to 3 automatically uncollapses', (tester) async {
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
    });

    testWidgets('checking a focused task clears composer selection and avoids ghost caret', (tester) async {
      const initialMd = '''- [ ] Task to check
- [x] Done 1
- [x] Done 2
- [x] Done 3
''';

      await tester.pumpWidget(
        buildTestWidget(markdown: initialMd),
      );
      await tester.pumpAndSettle();

      // Tap on the text of 'Task to check' to give it focus/caret
      await tester.tap(find.text('Task to check', findRichText: true), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap the unchecked box to complete it
      final uncheckedBox = find.byIcon(PhosphorIconsRegular.square);
      expect(uncheckedBox, findsOneWidget);
      await tester.tap(uncheckedBox);
      await tester.pumpAndSettle();

      // Completed items now total 4, so they collapse under summary header
      expect(find.text('4 completed items'), findsOneWidget);

      // Verify that the task component returns Rect.zero for collapsed items
      final taskState = tester.state(
        find.byType(QuietTaskComponent).first,
      ) as DocumentComponent;
      expect(
        taskState.getRectForPosition(const TextNodePosition(offset: 0)),
        equals(Rect.zero),
      );
    });

    testWidgets('tapping checkbox exhibits immediate visual completion and smooth dwell', (tester) async {
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
    });

    testWidgets('paragraphs following a completed task list are not merged, struck through, or collapsed', (tester) async {
      const initialMd = '''- [ ] new item
- [x] item 1
- [x] item 2
- [x] item 3
- [x] item 4
- [x] item 5
new thins
hey thanks
''';

      await tester.pumpWidget(
        buildTestWidget(markdown: initialMd),
      );
      await tester.pumpAndSettle();

      // The completed items should be collapsed under "5 completed items"
      expect(find.text('5 completed items'), findsOneWidget);

      // Paragraphs following the task list MUST remain visible outside the collapse
      expect(find.textContaining('new thins', findRichText: true), findsOneWidget);
      expect(find.textContaining('hey thanks', findRichText: true), findsOneWidget);

      // Verify that 'new thins' is in a ParagraphComponent (not a QuietTaskComponent)
      final paragraphWidget = tester.firstWidget<ParagraphComponent>(
        find.byType(ParagraphComponent),
      );
      expect(paragraphWidget.viewModel.text.toPlainText(), contains('new thins'));
      expect(paragraphWidget.viewModel.text.hasAttributionAt(0, attribution: strikethroughAttribution), isFalse);
    });

    test('QuietTaskNodeSerializer outputs blank line before following non-task node', () {
      final doc = MutableDocument(nodes: [
        TaskNode(id: '1', text: AttributedText('task 1'), isComplete: true),
        ParagraphNode(id: '2', text: AttributedText('paragraph after task')),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietTaskNodeSerializer()],
      );

      // Must be separated by blank line (\n\n) so CommonMark doesn't merge them
      expect(serialized, contains('- [x] task 1\n\nparagraph after task'));
    });
  });
}
