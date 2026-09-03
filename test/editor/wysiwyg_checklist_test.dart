import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  Widget buildEditorWithToolbar({
    required SemanticEditorController controller,
    required FocusNode focusNode,
    required TextEditingController textController,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: VisualDocumentEditor(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                ),
              ),
            ),
            FormattingToolbar(
              controller: textController,
              focusNode: focusNode,
              semanticController: controller,
              onTagPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  group('WYSIWYG Checklist Engine Tests', () {
    testWidgets('Tapping Checklist button in FormattingToolbar immediately converts block to checklist without typing', (tester) async {
      const initialText = 'Buy oat milk';
      String? latestMarkdown;
      final controller = SemanticEditorController(
        initialMarkdown: initialText,
        onMarkdownChanged: (val) => latestMarkdown = val,
      );
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: initialText);

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
        onChanged: (val) => latestMarkdown = val,
      ));
      await tester.pumpAndSettle();

      // Initially a ParagraphBlock with no square icon
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(find.byIcon(PhosphorIconsRegular.square), findsNothing);

      // Tap the Checklist button on the formatting toolbar
      final checklistBtn = find.byTooltip('Checklist (- [ ])');
      expect(checklistBtn, findsOneWidget);
      await tester.tap(checklistBtn);
      await tester.pumpAndSettle();

      // The block must immediately be converted to ChecklistItemBlock
      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      final itemBlock = controller.document.blocks.first as ChecklistItemBlock;
      expect(itemBlock.checked, isFalse);
      expect(itemBlock.plainText, equals('Buy oat milk'));

      // The uncompleted Phosphor square icon must immediately appear
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);

      // Canonical markdown has - [ ]
      expect(controller.markdown, startsWith('- [ ] Buy oat milk'));
      expect(latestMarkdown, startsWith('- [ ] Buy oat milk'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Tapping square checkbox toggles item to done, updates canonical markdown, and applies strikethrough', (tester) async {
      const md = '- [ ] Buy groceries';
      final controller = SemanticEditorController(initialMarkdown: md);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: 'Buy groceries');
      String? latestMarkdown;

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
        onChanged: (val) => latestMarkdown = val,
      ));
      await tester.pumpAndSettle();

      // Verify initial unchecked state
      final squareIcon = find.byIcon(PhosphorIconsRegular.square);
      expect(squareIcon, findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);

      // Tap the checkbox icon
      await tester.tap(squareIcon);
      await tester.pumpAndSettle();

      // Checkbox is now checked using PhosphorIconsFill.checkSquare
      expect(find.byIcon(PhosphorIconsRegular.square), findsNothing);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      // Controller and emitted markdown updated
      expect(controller.markdown, startsWith('- [x] Buy groceries'));
      expect(latestMarkdown, startsWith('- [x] Buy groceries'));

      // Verify strikethrough styling in the TextField
      final textFieldFinder = find.widgetWithText(TextField, 'Buy groceries');
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.style?.decoration, equals(TextDecoration.lineThrough));

      // Tap the checked checkbox again to uncheck
      final checkedIcon = find.byIcon(PhosphorIconsFill.checkSquare);
      await tester.tap(checkedIcon);
      await tester.pumpAndSettle();

      // Checkbox is back to unchecked square
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);
      expect(controller.markdown, startsWith('- [ ] Buy groceries'));

      final uncheckTextField = tester.widget<TextField>(textFieldFinder);
      expect(uncheckTextField.style?.decoration, isNot(equals(TextDecoration.lineThrough)));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Checkbox toggle works seamlessly when note contains frontmatter', (tester) async {
      const mdWithFrontmatter = '---\ntitle: Daily Standup\ntags: [meeting]\n---\n- [ ] Ship release build';
      final controller = SemanticEditorController(
        initialMarkdown: mdWithFrontmatter,
        stripFrontmatter: true,
      );
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: 'Ship release build');

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
      ));
      await tester.pumpAndSettle();

      final squareIcon = find.byIcon(PhosphorIconsRegular.square);
      expect(squareIcon, findsOneWidget);

      // Tap the checkbox
      await tester.tap(squareIcon);
      await tester.pumpAndSettle();

      // Verify checked state
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);
      expect(controller.markdown, contains('- [x] Ship release build'));
      expect(controller.markdown, contains('title: Daily Standup'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Phosphor icons are used for both checked and unchecked states', (tester) async {
      const md = '- [ ] Incomplete\n- [x] Complete';
      final controller = SemanticEditorController(initialMarkdown: md);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController();

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
      ));
      await tester.pumpAndSettle();

      // Check for PhosphorIconsRegular.square (0xe45E)
      final uncompletedIconFinder = find.byIcon(PhosphorIconsRegular.square);
      expect(uncompletedIconFinder, findsOneWidget);
      final Icon uncompletedIcon = tester.widget<Icon>(uncompletedIconFinder);
      expect(uncompletedIcon.icon?.codePoint, equals(0xe45E));
      expect(uncompletedIcon.icon?.fontFamily, equals('Phosphor'));

      // Check for PhosphorIconsFill.checkSquare (0xe186)
      final completedIconFinder = find.byIcon(PhosphorIconsFill.checkSquare);
      expect(completedIconFinder, findsOneWidget);
      final Icon completedIcon = tester.widget<Icon>(completedIconFinder);
      expect(completedIcon.icon?.codePoint, equals(0xe186));
      expect(completedIcon.icon?.fontFamily, equals('Phosphor-Fill'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('FormattingToolbar bullet, ordered list, and quote buttons immediately convert blocks', (tester) async {
      const text = 'Hello world';
      final controller = SemanticEditorController(initialMarkdown: text);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: text);

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
      ));
      await tester.pumpAndSettle();

      // Tap Bullet List button
      await tester.tap(find.byTooltip('Bullet List (-)'));
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<ListItemBlock>());
      expect(controller.markdown, startsWith('- Hello world'));

      // Tap Numbered List button
      await tester.tap(find.byTooltip('Numbered List (1.)'));
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<OrderedListItemBlock>());
      expect(controller.markdown, startsWith('1. Hello world'));

      // Tap Quote button
      await tester.tap(find.byTooltip('Quote (>)'));
      await tester.pumpAndSettle();
      expect(controller.document.blocks.first, isA<QuoteBlock>());
      expect(controller.markdown, startsWith('> Hello world'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });
  });
}
