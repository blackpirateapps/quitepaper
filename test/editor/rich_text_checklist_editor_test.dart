import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('RichTextEditor — Checklist & Todolist Integration Tests', () {
    late RichDocumentController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = RichDocumentController();
      focusNode = FocusNode();
    });

    tearDown(() {
      focusNode.dispose();
      controller.dispose();
    });

    Widget buildTestApp() {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RichTextEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
    }

    testWidgets('1. Toggling checklist on empty paragraph places cursor AFTER the checkbox', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Starts as empty paragraph
      expect(controller.document.blocks.first, isA<ParagraphBlock>());

      // User toggles checklist from toolbar/shortcut
      controller.toggleChecklist();
      await tester.pumpAndSettle();

      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, false);

      // Verify the visual checkbox icon appears
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);

      // Verify TextField selection is after the checkbox (offset 1, not offset 0)
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.selection.baseOffset, 1);
      expect(editableText.controller.selection.extentOffset, 1);
      expect(editableText.controller.text, '\uFFFC');
    });

    testWidgets('2. Typing "hey" into checklist item keeps cursor directly AFTER "y"', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      controller.toggleChecklist();
      await tester.pumpAndSettle();

      // Focus editor
      focusNode.requestFocus();
      await tester.pump();

      // User types "hey"
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      editableText.controller.text = '\uFFFChey';
      editableText.controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pumpAndSettle();

      // Controller document should be updated with "hey" (pure, without \uFFFC)
      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      expect(controller.document.blocks.first.plainText, 'hey');
      expect(controller.toMarkdown(), '- [ ] hey');

      // The selection remains at offset 4 (right after 'y', not lagging behind after 'e')
      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.selection.baseOffset, 4);
      expect(updatedEditable.controller.selection.extentOffset, 4);
    });

    testWidgets('3. Cursor cannot be moved before the checkbox gutter', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      controller.toggleChecklist();
      await tester.pumpAndSettle();

      final editableText = tester.widget<EditableText>(find.byType(EditableText));

      // Attempt to place cursor at offset 0 (before the checkbox)
      editableText.controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      // Automatically clamped to offset 1 (after the checkbox)
      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.selection.baseOffset, 1);
      expect(updatedEditable.controller.selection.extentOffset, 1);
    });

    testWidgets('4. Pressing Enter at end of checklist item creates new unchecked item on the next line', (tester) async {
      controller.setMarkdown('- [ ] Buy groceries');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      // Place cursor at the end of "Buy groceries" (offset: 1 + 13 = 14)
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.text, '\uFFFCBuy groceries');
      editableText.controller.selection = const TextSelection.collapsed(offset: 14);
      await tester.pump();

      // Simulate pressing Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Document now has 2 blocks
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[0].plainText, 'Buy groceries');
      expect(controller.document.blocks[1], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[1].plainText, '');
      expect((controller.document.blocks[1] as ChecklistItemBlock).isChecked, false);

      // Verify the cursor is on the new line, right after the new checkbox
      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, '\uFFFCBuy groceries\n\uFFFC');
      // Line 0 is 14 chars + 1 ('\n') = 15. Line 1 checkbox is at 15. Cursor should be at 16!
      expect(updatedEditable.controller.selection.baseOffset, 16);
      expect(updatedEditable.controller.selection.extentOffset, 16);
    });

    testWidgets('5. Pressing Enter on empty checklist item converts to paragraph', (tester) async {
      controller.setMarkdown('- [ ] Task 1\n- [ ] ');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      // Cursor is at end of line 2 (offset 8)
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.text, '\uFFFCTask 1\n\uFFFC');
      editableText.controller.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();

      // Press Enter on empty checklist item
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Block 1 is converted to ParagraphBlock
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[1], isA<ParagraphBlock>());
      expect(controller.document.blocks[1].plainText, '');

      // Controller text should now have regular newline with no second \uFFFC
      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, '\uFFFCTask 1\n');
    });

    testWidgets('6. Pressing Backspace at start of checklist item converts to paragraph', (tester) async {
      controller.setMarkdown('- [ ] Item');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      // Cursor is right after checkbox (offset 1, content offset 0)
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      editableText.controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      // Press Backspace
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Block is converted to paragraph preserving text "Item"
      expect(controller.document.blocks.first, isA<ParagraphBlock>());
      expect(controller.document.blocks.first.plainText, 'Item');
      expect(controller.toMarkdown(), 'Item');

      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, 'Item');
      expect(updatedEditable.controller.selection.baseOffset, 0);
    });

    testWidgets('7. Tapping checkbox toggles checked/completed state', (tester) async {
      controller.setMarkdown('- [ ] First task');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsNothing);

      // Tap the checkbox icon
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Now checked
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsOneWidget);
      expect(controller.toMarkdown(), '- [x] First task');

      // Tap again to uncheck
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(controller.toMarkdown(), '- [ ] First task');
    });

    testWidgets('8. Multi-item checklist maintains 1:1 offsets with zero cumulative drift across lines', (tester) async {
      controller.setMarkdown('- [ ] One\n- [ ] Two\n- [ ] Three');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      // Line 0: \uFFFCOne (len 4)
      // Line 1: \uFFFCTwo (len 4, start at 5)
      // Line 2: \uFFFCThree (len 6, start at 10)
      expect(editableText.controller.text, '\uFFFCOne\n\uFFFCTwo\n\uFFFCThree');

      // Place cursor at end of Line 1 ("Two", offset 9)
      editableText.controller.selection = const TextSelection.collapsed(offset: 9);
      await tester.pump();

      // Press Enter at end of Line 1
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Should insert new item between "Two" and "Three" (at block index 2)
      expect(controller.document.blocks.length, 4);
      expect(controller.document.blocks[0].plainText, 'One');
      expect(controller.document.blocks[1].plainText, 'Two');
      expect(controller.document.blocks[2].plainText, '');
      expect(controller.document.blocks[2], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[3].plainText, 'Three');

      // Cursor is placed right after the new checkbox at index 2
      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, '\uFFFCOne\n\uFFFCTwo\n\uFFFC\n\uFFFCThree');
      // Line 0: 4 + 1 = 5. Line 1: 4 + 1 = 5 (running: 10). Line 2 prefix: 1. Caret at 11!
      expect(updatedEditable.controller.selection.baseOffset, 11);
    });

    testWidgets('9. Bulleted list items also maintain prefix parity and clean continuation', (tester) async {
      controller.setMarkdown('- First bullet');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pump();

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.text, '• First bullet');

      // Place cursor at end of "First bullet" (offset 2 + 12 = 14)
      editableText.controller.selection = const TextSelection.collapsed(offset: 14);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<BulletedListItemBlock>());
      expect(controller.document.blocks[0].plainText, 'First bullet');
      expect(controller.document.blocks[1], isA<BulletedListItemBlock>());
      expect(controller.document.blocks[1].plainText, '');

      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, '• First bullet\n• ');
      // Line 0: 14 + 1 = 15. Line 1 prefix is 2 ('• '). Caret at 17!
      expect(updatedEditable.controller.selection.baseOffset, 17);
    });
  });
}
