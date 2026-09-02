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
  });
}
