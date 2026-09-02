import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/domain/source_range.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/heading/markdown_heading_action_sheet.dart';
import 'package:quitepaper/features/editor/presentation/widgets/heading/markdown_heading_badge.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('HeadingBlock Domain & Helper Tests', () {
    test('badgeLabel and levelDescription return formatted labels', () {
      const h1 = HeadingBlock(
        id: 'h1',
        level: 1,
        runs: [PlainRun('Title', SourceRange(2, 7))],
        sourceRange: SourceRange(0, 7),
        markerRange: SourceRange(0, 2),
        contentRange: SourceRange(2, 7),
      );
      expect(h1.badgeLabel, 'H1');
      expect(h1.levelDescription, 'Title (H1)');
      expect(h1.nextLevel, 2);
      expect(h1.previousLevel, 6);

      const h6 = HeadingBlock(
        id: 'h6',
        level: 6,
        runs: [PlainRun('Micro', SourceRange(7, 12))],
        sourceRange: SourceRange(0, 12),
        markerRange: SourceRange(0, 7),
        contentRange: SourceRange(7, 12),
      );
      expect(h6.badgeLabel, 'H6');
      expect(h6.levelDescription, 'Micro (H6)');
      expect(h6.nextLevel, 1);
      expect(h6.previousLevel, 5);
    });
  });

  group('MarkdownHeadingBadge Widget Tests', () {
    testWidgets('renders H1 badge and responds to taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MarkdownHeadingBadge(
                level: 1,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('H1'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);

      await tester.tap(find.text('H1'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('disabled badge does not trigger onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MarkdownHeadingBadge(
                level: 3,
                enabled: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('H3'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);

      await tester.tap(find.text('H3'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });
  });

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

  group('VisualDocumentEditor Heading Interaction Tests', () {
    testWidgets('tapping heading badge opens action sheet and modifies heading level in canonical Markdown', (tester) async {
      const md = '# Section Title\n\nBody content here.';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                onChanged: (val) => updatedMarkdown = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading badge should show H1
      expect(find.text('H1'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Section Title'), findsOneWidget);

      // Tap H1 badge to open action sheet
      await tester.tap(find.text('H1'));
      await tester.pumpAndSettle();

      // Select H3 from action sheet
      expect(find.text('Heading Level'), findsOneWidget);
      await tester.tap(find.text('H3'));
      await tester.pumpAndSettle();

      // Canonical markdown should now be ### Section Title
      expect(controller.markdown, startsWith('### Section Title'));
      expect(updatedMarkdown, startsWith('### Section Title'));
      expect(find.text('H3'), findsOneWidget);

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('converting heading to paragraph updates canonical Markdown', (tester) async {
      const md = '## Subheading\n\nSome body text.';
      var updatedMarkdown = md;
      final controller = SemanticEditorController(
        initialMarkdown: md,
        onMarkdownChanged: (val) => updatedMarkdown = val,
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualDocumentEditor(
                controller: controller,
                focusNode: focusNode,
                onChanged: (val) => updatedMarkdown = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('H2'), findsOneWidget);

      // Tap H2 badge
      await tester.tap(find.text('H2'));
      await tester.pumpAndSettle();

      // Tap convert to paragraph
      await tester.tap(find.text('Convert to Paragraph (Normal text)'));
      await tester.pumpAndSettle();

      // Markdown should no longer have ##
      expect(controller.markdown, startsWith('Subheading'));
      expect(controller.markdown, isNot(contains('## Subheading')));
      expect(updatedMarkdown, startsWith('Subheading'));

      focusNode.dispose();
      controller.dispose();
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
