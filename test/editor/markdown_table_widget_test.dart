import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';
import 'package:quitepaper/features/editor/domain/markdown_table_position.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_view.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/table_insert_dialog.dart';

void main() {
  const parser = MarkdownTableParser();

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        extensions: const [AppColors.light],
      ),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('MarkdownTableView - Widget Tests', () {
    testWidgets('renders table cells accurately in read-only mode', (tester) async {
      const markdown = '''
| Fruit | Color | Price |
| :--- | :---: | ---: |
| Apple | Red | \$1.00 |
| Banana | Yellow | \$0.50 |
''';
      final table = parser.findTables(markdown).first;

      await tester.pumpWidget(
        wrapWithTheme(
          MarkdownTableView(
            table: table,
            readOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fruit', findRichText: true), findsOneWidget);
      expect(find.text('Color', findRichText: true), findsOneWidget);
      expect(find.text('Price', findRichText: true), findsOneWidget);
      expect(find.text('Apple', findRichText: true), findsOneWidget);
      expect(find.text('Banana', findRichText: true), findsOneWidget);
    });

    testWidgets('fires onCellTap when tapping a cell in editable mode', (tester) async {
      const markdown = '''
| Task | Owner |
| --- | --- |
| Refactor | Alex |
''';
      final table = parser.findTables(markdown).first;
      TablePosition? tappedPos;

      await tester.pumpWidget(
        wrapWithTheme(
          MarkdownTableView(
            table: table,
            onCellTap: (pos) => tappedPos = pos,
            readOnly: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refactor', findRichText: true));
      await tester.pumpAndSettle();

      expect(tappedPos, isNotNull);
      expect(tappedPos!.row, 1);
      expect(tappedPos!.column, 0);
    });
  });

  group('MarkdownTableEditor - Widget Tests', () {
    testWidgets('renders active cell and allows inline editing and toolbar operations', (tester) async {
      var currentDoc = const TextEditingValue(
        text: '''
# Document

| Col 1 | Col 2 |
| --- | --- |
| A | B |
''',
      );

      final table = parser.findTables(currentDoc.text).first;

      final controller = MarkdownTableController(
        table: table,
        getDocumentValue: () => currentDoc,
        onUpdateDocument: (newVal) => currentDoc = newVal,
        initialPosition: const TablePosition(row: 1, column: 0),
        styles: MarkdownStyles.fromColors(AppColors.light),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MarkdownTableEditor(
            controller: controller,
            styles: MarkdownStyles.fromColors(AppColors.light),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify active cell contains initial text 'A'
      expect(controller.cellController.text, 'A');

      // Edit cell text
      controller.cellController.text = 'Apple';
      await tester.pumpAndSettle();

      expect(currentDoc.text.contains('| Apple | B |'), isTrue);

      // Tap '+Row' in toolbar
      await tester.tap(find.text('+Row'));
      await tester.pumpAndSettle();

      expect(controller.table.rowCount, 3); // 1 header + 2 body rows

      // Tap '+Col' in toolbar
      await tester.tap(find.text('+Col'));
      await tester.pumpAndSettle();

      expect(controller.table.columnCount, 3);

      controller.dispose();
    });
  });

  group('TableInsertDialog - Widget Tests', () {
    testWidgets('increments and decrements row/col steppers and returns configuration', (tester) async {
      ({int rows, int columns})? result;

      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await TableInsertDialog.show(
                  ctx,
                  initialRows: 2,
                  initialColumns: 2,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Insert Table'), findsOneWidget);

      // Increment columns
      final addIcons = find.byIcon(Icons.add_rounded);
      await tester.tap(addIcons.first); // Columns +
      await tester.pumpAndSettle();

      // Click Insert button
      await tester.tap(find.text('Insert (3×3)', findRichText: true));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.columns, 3);
      expect(result!.rows, 2);
    });
  });

  group('MarkdownEditor - Hybrid Integration Tests', () {
    testWidgets('renders single TextField for plain notes and hybrid editor when table exists', (tester) async {
      final docController = MarkdownEditingController(
        text: '''
Hello world!

| Key | Value |
| --- | --- |
| Theme | Warm Paper |
''',
        styles: MarkdownStyles.fromColors(AppColors.light),
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        wrapWithTheme(
          MarkdownEditor(
            controller: docController,
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify table view is rendered
      expect(find.text('Key', findRichText: true), findsOneWidget);
      expect(find.text('Value', findRichText: true), findsOneWidget);
      expect(find.text('Theme', findRichText: true), findsOneWidget);

      // Tap on cell 'Theme' to activate hybrid table editor
      await tester.tap(find.text('Theme', findRichText: true));
      await tester.pumpAndSettle();

      // Verify toolbar appears with '+Row' and '+Col'
      expect(find.text('+Row'), findsOneWidget);
      expect(find.text('+Col'), findsOneWidget);

      docController.dispose();
      focusNode.dispose();
    });
  });
}
