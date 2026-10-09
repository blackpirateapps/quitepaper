import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/markdown_table_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/table_editor_screen.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  const sampleTable = '| Col 1 | Col 2 |\n| --- | --- |\n| a | b |\n| c | d |';

  Widget host({required void Function(String?) onResult}) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await TableEditorScreen.open(
                  context,
                  initialTableMarkdown: sampleTable,
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the full-screen table editor with the cell grid', (tester) async {
    await tester.pumpWidget(host(onResult: (_) {}));
    await openScreen(tester);

    expect(find.byType(TableEditorScreen), findsOneWidget);
    expect(find.byType(MarkdownTableEditor), findsOneWidget);
    expect(find.text('Edit table'), findsOneWidget);
  });

  testWidgets('duplicate row via overflow menu changes the returned markdown', (tester) async {
    String? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openScreen(tester);

    // Open the overflow menu and duplicate the active (header) row.
    await tester.tap(find.byIcon(PhosphorIconsRegular.dotsThreeVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate row'));
    await tester.pumpAndSettle();

    // Finish editing.
    await tester.tap(find.byIcon(PhosphorIconsRegular.check));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final tables = const MarkdownTableParser().findTables(result!);
    expect(tables, isNotEmpty);
    // Original had 2 body rows; duplicating adds one more.
    expect(tables.first.bodyRows.length, 3);
  });

  testWidgets('delete table returns an empty string sentinel', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openScreen(tester);

    await tester.tap(find.byIcon(PhosphorIconsRegular.dotsThreeVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete table'));
    await tester.pumpAndSettle();

    expect(result, '');
  });
}
