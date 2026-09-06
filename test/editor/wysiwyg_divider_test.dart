import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';

void main() {
  Widget buildEditorWithToolbar({
    required SemanticEditorController controller,
    required FocusNode focusNode,
    required TextEditingController textController,
    ValueChanged<String>? onChanged,
    void Function(TextEditingController, FocusNode)? onActiveTargetChanged,
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
                  onActiveTargetChanged: onActiveTargetChanged,
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

  group('WYSIWYG Divider (Horizontal Rule) Tests', () {
    testWidgets('Typing --- in an empty block converts to divider and places focus on the line below without jumping to previous line', (tester) async {
      const initialText = 'Line 1\n\n';
      String? latestMarkdown;
      final controller = SemanticEditorController(
        initialMarkdown: initialText,
        onMarkdownChanged: (val) => latestMarkdown = val,
      );
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: initialText);
      TextEditingController? activeTargetController;
      FocusNode? activeTargetFocusNode;

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
        onChanged: (val) => latestMarkdown = val,
        onActiveTargetChanged: (c, f) {
          activeTargetController = c;
          activeTargetFocusNode = f;
        },
      ));
      await tester.pumpAndSettle();

      // Find all text fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // Line 1 and empty line 2

      // Focus the second (empty) text field
      await tester.tap(textFields.at(1));
      await tester.pumpAndSettle();

      // Type '-' three times in the second text field
      await tester.enterText(textFields.at(1), '-');
      await tester.pump();
      await tester.enterText(textFields.at(1), '--');
      await tester.pump();
      await tester.enterText(textFields.at(1), '---');
      await tester.pumpAndSettle();

      // Divider widget must now exist
      expect(find.byType(Divider), findsOneWidget);

      // A HorizontalRuleBlock must be in the document
      expect(controller.document.blocks.any((b) => b is HorizontalRuleBlock), isTrue);

      // The selection must NOT be on the previous line (Line 1)
      final hrIdx = controller.document.blocks.indexWhere((b) => b is HorizontalRuleBlock);
      expect(hrIdx, equals(1));
      expect(controller.document.blocks.length, greaterThan(hrIdx + 1));

      // An editable block must exist BELOW the divider
      final blockBelow = controller.document.blocks[hrIdx + 1];
      expect(blockBelow, isA<ParagraphBlock>());

      // Selection must be on the block below the divider
      expect(controller.selection.base.blockId, equals(blockBelow.id));
      expect(controller.selection.base.offset, equals(0));

      // The active focus node must be on the block below, NOT the first block
      expect(activeTargetFocusNode, isNotNull);
      expect(activeTargetFocusNode!.hasFocus, isTrue);

      // Typing in the active focused controller writes to the line below the divider
      activeTargetController!.text = 'Line below divider';
      activeTargetController!.selection = const TextSelection.collapsed(offset: 18);
      controller.handleVisualBlockTextChange(blockBelow.id, 'Line below divider', activeTargetController!.selection);
      await tester.pumpAndSettle();

      expect(controller.markdown, contains('---'));
      expect(controller.markdown, contains('Line below divider'));
      expect(latestMarkdown, contains('---'));
      expect(latestMarkdown, contains('Line below divider'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Tapping Divider button in FormattingToolbar converts empty block to divider and focuses line below', (tester) async {
      const initialText = 'Heading line\n\n';
      final controller = SemanticEditorController(initialMarkdown: initialText);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: initialText);
      FocusNode? activeTargetFocusNode;

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
        onActiveTargetChanged: (_, f) => activeTargetFocusNode = f,
      ));
      await tester.pumpAndSettle();

      // Focus the second (empty) text field
      final textFields = find.byType(TextField);
      await tester.tap(textFields.at(1));
      await tester.pumpAndSettle();

      // Tap the Divider button in toolbar
      final dividerBtn = find.byTooltip('Divider (---)');
      expect(dividerBtn, findsOneWidget);
      await tester.tap(dividerBtn);
      await tester.pumpAndSettle();

      // Verify divider is rendered
      expect(find.byType(Divider), findsOneWidget);

      // Verify a HorizontalRuleBlock exists
      final hrIdx = controller.document.blocks.indexWhere((b) => b is HorizontalRuleBlock);
      expect(hrIdx, equals(1));

      // Verify an empty ParagraphBlock exists below the divider
      final blockBelow = controller.document.blocks[hrIdx + 1];
      expect(blockBelow, isA<ParagraphBlock>());
      expect(blockBelow.plainText, isEmpty);

      // Verify selection is on the block below
      expect(controller.selection.base.blockId, equals(blockBelow.id));
      expect(activeTargetFocusNode?.hasFocus, isTrue);

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Tapping on the divider line widget directs focus to the line below', (tester) async {
      const md = 'Above\n---\nBelow';
      final controller = SemanticEditorController(initialMarkdown: md);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: md);
      FocusNode? activeTargetFocusNode;

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
        onActiveTargetChanged: (_, f) => activeTargetFocusNode = f,
      ));
      await tester.pumpAndSettle();

      final divider = find.byType(Divider);
      expect(divider, findsOneWidget);

      // Tap directly on the divider
      await tester.tap(divider);
      await tester.pumpAndSettle();

      // Verify the block below received focus
      final belowBlock = controller.document.blocks.last;
      expect(belowBlock.plainText, equals('Below'));
      expect(activeTargetFocusNode?.hasFocus, isTrue);
      expect(controller.selection.base.blockId, equals(belowBlock.id));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });

    testWidgets('Pressing Backspace on the line below divider deletes the divider', (tester) async {
      const md = 'First\n---\n\n';
      final controller = SemanticEditorController(initialMarkdown: md);
      controller.styles = MarkdownStyles.fromColors(AppColors.light);
      final focusNode = FocusNode();
      final textController = TextEditingController(text: md);

      await tester.pumpWidget(buildEditorWithToolbar(
        controller: controller,
        focusNode: focusNode,
        textController: textController,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);

      // Find the text field for the line below divider (it's the second textfield)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // 'First' and empty line below divider

      await tester.tap(textFields.at(1));
      await tester.pumpAndSettle();

      // Send Backspace key event at offset 0
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Divider should now be deleted
      expect(find.byType(Divider), findsNothing);
      expect(controller.document.blocks.any((b) => b is HorizontalRuleBlock), isFalse);
      expect(controller.markdown, equals('First'));

      focusNode.dispose();
      textController.dispose();
      controller.dispose();
    });
  });
}
