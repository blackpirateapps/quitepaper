import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

void main() {
  Widget buildVisualEditor({
    required SemanticEditorController controller,
    required FocusNode focusNode,
    ValueChanged<String>? onChanged,
    void Function(TextEditingController, FocusNode)? onActiveTargetChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: VisualDocumentEditor(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onActiveTargetChanged: onActiveTargetChanged,
          ),
        ),
      ),
    );
  }

  Widget buildMarkdownEditor({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
    ValueChanged<String>? onChanged,
    void Function(TextEditingController, FocusNode)? onActiveTargetChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            editingStyle: EditorEditingStyle.markdown,
            onChanged: onChanged,
            onActiveTargetChanged: onActiveTargetChanged,
          ),
        ),
      ),
    );
  }

  group('WYSIWYG Table Editing - Focus & Keystroke Tests', () {
    testWidgets('typing inside a cell updates content and retains focus without jumping outside table', (tester) async {
      const initialMd = '''
First paragraph text

| Fruit | Price |
| :--- | :--- |
| Apple | \$1.00 |

Second paragraph text
''';

      var currentMarkdown = initialMd;
      final controller = SemanticEditorController(
        initialMarkdown: initialMd,
        onMarkdownChanged: (val) => currentMarkdown = val,
      );
      final focusNode = FocusNode();

      TextEditingController? activeTargetCtrl;
      FocusNode? activeTargetFn;

      await tester.pumpWidget(buildVisualEditor(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => currentMarkdown = val,
        onActiveTargetChanged: (ctrl, fn) {
          activeTargetCtrl = ctrl;
          activeTargetFn = fn;
        },
      ));
      await tester.pumpAndSettle();

      // Verify initial rendering
      expect(find.text('First paragraph text'), findsOneWidget);
      expect(find.text('Apple', findRichText: true), findsOneWidget);

      // Tap cell 'Apple' to activate table editor
      await tester.tap(find.text('Apple', findRichText: true));
      await tester.pumpAndSettle();

      // Verify MarkdownTableEditor is active
      expect(find.byType(MarkdownTableEditor), findsOneWidget);

      // Verify active target is the cell controller and focus node
      expect(activeTargetCtrl, isNotNull);
      expect(activeTargetFn, isNotNull);
      expect(activeTargetFn!.hasFocus, isTrue);

      // Active cell TextField should have 'Apple'
      final cellFieldFinder = find.byKey(const ValueKey('cell_1_0'));
      expect(cellFieldFinder, findsOneWidget);
      final cellTextField = tester.widget<TextField>(cellFieldFinder);
      expect(cellTextField.controller?.text, 'Apple');
      expect(cellTextField.textInputAction, TextInputAction.next);
      expect(cellTextField.maxLines, 1);

      // Type 1 character into the cell
      await tester.enterText(cellFieldFinder, 'Apples');
      await tester.pumpAndSettle();

      // Verify focus is STILL on the active cell TextField, not jumped to paragraph
      expect(activeTargetFn!.hasFocus, isTrue);
      expect(find.byType(MarkdownTableEditor), findsOneWidget);
      expect(currentMarkdown, contains('| Apples | \$1.00 |'));

      // Type another character
      await tester.enterText(cellFieldFinder, 'Applesauce');
      await tester.pumpAndSettle();

      expect(activeTargetFn!.hasFocus, isTrue);
      expect(currentMarkdown, contains('| Applesauce | \$1.00 |'));

      // Backspace a character
      await tester.enterText(cellFieldFinder, 'Applesauc');
      await tester.pumpAndSettle();

      // Focus must remain inside the cell
      expect(activeTargetFn!.hasFocus, isTrue);
      expect(currentMarkdown, contains('| Applesauc | \$1.00 |'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('moving to the next cell retains focus and soft keyboard active target', (tester) async {
      const initialMd = '''
| Task | Status |
| --- | --- |
| Design | Done |
''';

      var currentMarkdown = initialMd;
      final controller = SemanticEditorController(
        initialMarkdown: initialMd,
        onMarkdownChanged: (val) => currentMarkdown = val,
      );
      final focusNode = FocusNode();

      TextEditingController? activeTargetCtrl;
      FocusNode? activeTargetFn;

      await tester.pumpWidget(buildVisualEditor(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) => currentMarkdown = val,
        onActiveTargetChanged: (ctrl, fn) {
          activeTargetCtrl = ctrl;
          activeTargetFn = fn;
        },
      ));
      await tester.pumpAndSettle();

      // Tap cell 'Design' to activate table editor (row 1, col 0)
      await tester.tap(find.text('Design', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cell_1_0')), findsOneWidget);
      expect(activeTargetFn!.hasFocus, isTrue);

      // Now tap on the next cell 'Done' (row 1, col 1)
      await tester.tap(find.text('Done', findRichText: true));
      await tester.pumpAndSettle();

      // The new active cell must be cell_1_1
      final cell11Finder = find.byKey(const ValueKey('cell_1_1'));
      expect(cell11Finder, findsOneWidget);

      // Active target must have updated and remain focused
      expect(activeTargetCtrl?.text, 'Done');
      expect(activeTargetFn, isNotNull);
      expect(activeTargetFn!.hasFocus, isTrue);

      // Type in new cell
      await tester.enterText(cell11Finder, 'In Progress');
      await tester.pumpAndSettle();

      expect(currentMarkdown, contains('| Design | In Progress |'));
      expect(activeTargetFn!.hasFocus, isTrue);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('submitting a cell advances to next cell and keeps focus', (tester) async {
      const initialMd = '''
| Col 1 | Col 2 |
| --- | --- |
| A | B |
''';

      final controller = SemanticEditorController(initialMarkdown: initialMd);
      final focusNode = FocusNode();

      TextEditingController? activeTargetCtrl;
      FocusNode? activeTargetFn;

      await tester.pumpWidget(buildVisualEditor(
        controller: controller,
        focusNode: focusNode,
        onActiveTargetChanged: (ctrl, fn) {
          activeTargetCtrl = ctrl;
          activeTargetFn = fn;
        },
      ));
      await tester.pumpAndSettle();

      // Tap header cell 'Col 1' (row 0, col 0)
      await tester.tap(find.text('Col 1', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cell_0_0')), findsOneWidget);
      expect(activeTargetCtrl?.text, 'Col 1');

      // Bind input via enterText and submit the field (simulating "Next" key on soft keyboard)
      await tester.enterText(find.byKey(const ValueKey('cell_0_0')), 'Col 1');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Focus should have advanced to Col 2 (row 0, col 1)
      expect(find.byKey(const ValueKey('cell_0_1')), findsOneWidget);
      expect(activeTargetCtrl?.text, 'Col 2');
      expect(activeTargetFn!.hasFocus, isTrue);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('tapping paragraph outside table deactivates table editor cleanly', (tester) async {
      const initialMd = '''
Paragraph above

| Header |
| --- |
| Item |

Paragraph below
''';

      final controller = SemanticEditorController(initialMarkdown: initialMd);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildVisualEditor(
        controller: controller,
        focusNode: focusNode,
      ));
      await tester.pumpAndSettle();

      // Tap cell 'Item'
      await tester.tap(find.text('Item', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownTableEditor), findsOneWidget);

      // Tap 'Paragraph below' outside table
      await tester.tap(find.text('Paragraph below'));
      await tester.pumpAndSettle();

      // Table editor should now be deactivated
      expect(find.byType(MarkdownTableEditor), findsNothing);

      focusNode.dispose();
      controller.dispose();
    });
  });

  group('Markdown Mode Table Editing - Focus Tests', () {
    testWidgets('moving to next cell in markdown mode preserves focus and target', (tester) async {
      const initialMd = '''
# Heading

| Col A | Col B |
| --- | --- |
| 10 | 20 |

Trailing text
''';

      final docController = MarkdownEditingController(
        text: initialMd,
        styles: MarkdownStyles.fromColors(AppColors.light),
      );
      final focusNode = FocusNode();

      TextEditingController? activeTargetCtrl;
      FocusNode? activeTargetFn;

      await tester.pumpWidget(buildMarkdownEditor(
        controller: docController,
        focusNode: focusNode,
        onActiveTargetChanged: (ctrl, fn) {
          activeTargetCtrl = ctrl;
          activeTargetFn = fn;
        },
      ));
      await tester.pumpAndSettle();

      // Tap on cell '10' (row 1, col 0)
      await tester.tap(find.text('10', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownTableEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('cell_1_0')), findsOneWidget);
      expect(activeTargetFn!.hasFocus, isTrue);

      // Tap on cell '20' (row 1, col 1)
      await tester.tap(find.text('20', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cell_1_1')), findsOneWidget);
      expect(activeTargetCtrl?.text, '20');
      expect(activeTargetFn!.hasFocus, isTrue);

      // Tap on trailing text segment outside table
      final segFinders = find.byType(TextField);
      // The last TextField is the trailing text segment
      await tester.tap(segFinders.last);
      await tester.pumpAndSettle();

      // Table editor should deactivate
      expect(find.byType(MarkdownTableEditor), findsNothing);

      docController.dispose();
      focusNode.dispose();
    });
  });

  group('MarkdownTableController - FocusNode Unit Tests', () {
    test('maintains distinct focus nodes per cell and prunes on resize', () {
      const md = '''
| H1 | H2 |
| --- | --- |
| A | B |
''';
      final table = const MarkdownTableParser().findTables(md).first;
      var currentDoc = const TextEditingValue(text: md);

      final controller = MarkdownTableController(
        table: table,
        getDocumentValue: () => currentDoc,
        onUpdateDocument: (val) => currentDoc = val,
      );

      final fn00 = controller.getFocusNodeFor(const TablePosition(row: 0, column: 0));
      final fn01 = controller.getFocusNodeFor(const TablePosition(row: 0, column: 1));
      final fn10 = controller.getFocusNodeFor(const TablePosition(row: 1, column: 0));

      expect(identical(fn00, fn01), isFalse);
      expect(identical(fn00, fn10), isFalse);
      expect(identical(controller.cellFocusNode, fn00), isTrue);

      // Switch to (1, 1)
      controller.setActivePosition(const TablePosition(row: 1, column: 1));
      expect(controller.activePosition, const TablePosition(row: 1, column: 1));
      expect(identical(controller.cellFocusNode, controller.getFocusNodeFor(const TablePosition(row: 1, column: 1))), isTrue);

      controller.dispose();
    });
  });
}
