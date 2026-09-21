import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';

void main() {
  Widget buildTestableWidget({
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
            ),
            FormattingToolbar(
              controller: controller,
              focusNode: focusNode,
              onTagPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  group('FormattingToolbar Widget Tests', () {
    testWidgets('highlights Bold button when bold is active in Markdown mode', (tester) async {
      final controller = MarkdownEditingController(text: '**hello**');
      controller.selection = const TextSelection.collapsed(offset: 4); // inside bold
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));

      // Find bold button by tooltip
      final boldFinder = find.byTooltip('Bold (**text**)');
      expect(boldFinder, findsOneWidget);

      final materialWidget = tester.widget<Material>(
        find.descendant(of: boldFinder, matching: find.byType(Material)),
      );
      expect(materialWidget.color, isNot(Colors.transparent)); // Highlighted with accent tint

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('toggles bold when tapping B button in Markdown mode', (tester) async {
      final controller = MarkdownEditingController(text: 'hello');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));

      // Tap Bold button
      final boldFinder = find.byTooltip('Bold (**text**)');
      await tester.tap(boldFinder);
      await tester.pumpAndSettle();

      expect(controller.text, equals('**hello**'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('highlights Italic and Strikethrough when active', (tester) async {
      final controller = MarkdownEditingController(text: '*italic* ~~strike~~');
      final focusNode = FocusNode();

      // Position cursor in *italic*
      controller.selection = const TextSelection.collapsed(offset: 4);

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));

      final italicFinder = find.byTooltip('Italic (*text*)');
      final italicMaterial = tester.widget<Material>(
        find.descendant(of: italicFinder, matching: find.byType(Material)),
      );
      expect(italicMaterial.color, isNot(Colors.transparent));

      // Move cursor to ~~strike~~
      controller.selection = const TextSelection.collapsed(offset: 12);
      await tester.pumpAndSettle();

      final strikeFinder = find.byTooltip('Strikethrough (~~text~~)');
      final strikeMaterial = tester.widget<Material>(
        find.descendant(of: strikeFinder, matching: find.byType(Material)),
      );
      expect(strikeMaterial.color, isNot(Colors.transparent));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('renders Aa Format Hub button and opens Bear-style sheet', (tester) async {
      final controller = MarkdownEditingController(text: 'sample text');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));

      // Find Aa Format Hub button
      final hubButtonFinder = find.byTooltip('Format & Structure Catalog');
      expect(hubButtonFinder, findsOneWidget);

      // Tap Aa button to open sheet
      await tester.tap(hubButtonFinder);
      await tester.pumpAndSettle();

      // Verify Bear-style header and initial sections are displayed
      expect(find.text('Format & Structure'), findsOneWidget);
      expect(find.text('TEXT STYLES'), findsOneWidget);
      expect(find.text('STRUCTURE & HEADINGS'), findsOneWidget);
      expect(find.text('LISTS & ORGANIZATION'), findsOneWidget);

      // Scroll to verify INSERTS & MEDIA
      await tester.scrollUntilVisible(
        find.text('INSERTS & MEDIA'),
        100.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('INSERTS & MEDIA'), findsOneWidget);

      // Scroll back or tap To-do List option in sheet
      await tester.scrollUntilVisible(
        find.text('To-do List'),
        -50.0,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('To-do List'));
      await tester.pumpAndSettle();

      // Verify formatting applied to current line
      expect(controller.text, equals('- [ ] sample text'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('displays dynamic heading level badge when cursor is in heading', (tester) async {
      final controller = MarkdownEditingController(text: '### Subsection Header');
      controller.selection = const TextSelection.collapsed(offset: 6);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestableWidget(
        controller: controller,
        focusNode: focusNode,
      ));

      // The heading button should display '3' badge
      expect(find.text('3'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('renders Insert (+) button and opens insert menu', (tester) async {
      var tablePressed = false;
      final controller = MarkdownEditingController(text: 'test');
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller, focusNode: focusNode),
              FormattingToolbar(
                controller: controller,
                focusNode: focusNode,
                onTagPressed: () {},
                onTablePressed: () => tablePressed = true,
              ),
            ],
          ),
        ),
      ));

      // Find Insert button
      final insertButton = find.byTooltip('Insert...');
      expect(insertButton, findsOneWidget);

      // Tap Insert button
      await tester.tap(insertButton);
      await tester.pumpAndSettle();

      // On mobile/default, opens modal bottom sheet with 'Insert' header
      expect(find.text('Insert'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
      expect(find.text('Web Link'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget);

      // Tap Table in insert menu
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();

      expect(tablePressed, isTrue);

      focusNode.dispose();
      controller.dispose();
    });
  });
}
