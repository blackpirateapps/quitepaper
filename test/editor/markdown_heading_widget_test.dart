import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/heading/markdown_heading_action_sheet.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('MarkdownHeadingActionSheet Widget Tests', () {
    testWidgets('displays all 6 heading levels and triggers onSelectLevel', (tester) async {
      int? selectedLevel;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MarkdownHeadingActionSheet.show(
                      context,
                      currentLevel: 1,
                      onSelectLevel: (lvl) => selectedLevel = lvl,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and levels
      expect(find.text('Heading Level'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
      expect(find.text('H4'), findsOneWidget);
      expect(find.text('H5'), findsOneWidget);
      expect(find.text('H6'), findsOneWidget);

      // Tap H2
      await tester.tap(find.text('H2'));
      await tester.pumpAndSettle();

      expect(selectedLevel, 2);
    });

    testWidgets('convert to paragraph triggers callback', (tester) async {
      var convertedToParagraph = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MarkdownHeadingActionSheet.show(
                      context,
                      currentLevel: 2,
                      onSelectLevel: (_) {},
                      onConvertToParagraph: () => convertedToParagraph = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Convert to Paragraph (Normal text)'), findsOneWidget);
      await tester.tap(find.text('Convert to Paragraph (Normal text)'));
      await tester.pumpAndSettle();

      expect(convertedToParagraph, isTrue);
    });
  });

  group('FormattingToolbar Heading Tests', () {
    testWidgets('long-pressing heading button opens MarkdownHeadingActionSheet', (tester) async {
      final controller = MarkdownEditingController(text: '## My Heading');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
                FormattingToolbar(
                  controller: controller,
                  focusNode: focusNode,
                  onTagPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long-press heading button
      final headingBtn = find.byIcon(PhosphorIconsRegular.textH);
      expect(headingBtn, findsOneWidget);
      await tester.longPress(headingBtn);
      await tester.pumpAndSettle();

      // Action sheet should appear
      expect(find.text('Heading Level'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);

      // Tap H1
      await tester.tap(find.text('H1'));
      await tester.pumpAndSettle();

      // Heading should now be # My Heading
      expect(controller.text, '# My Heading');

      focusNode.dispose();
      controller.dispose();
    });
  });
}
