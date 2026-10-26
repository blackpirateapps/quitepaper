import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_checklist_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_editor_surface.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('Visual Editor — Dedicated Checklist Widget Integration Tests', () {
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
          body: RichEditorSurface(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
    }

    testWidgets('1. Toggling checklist on empty paragraph renders RichChecklistEditor widget', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Starts as empty paragraph
      expect(controller.document.blocks.first, isA<ParagraphBlock>());

      // User toggles checklist from toolbar/shortcut
      controller.toggleChecklist();
      await tester.pumpAndSettle();

      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      expect((controller.document.blocks.first as ChecklistItemBlock).isChecked, false);

      // Verify dedicated RichChecklistEditor widget is rendered
      expect(find.byType(RichChecklistEditor), findsOneWidget);

      // Verify the visual checkbox icon appears
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);

      // Verify TextField has pure text without \uFFFC hacks
      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.text, '');
      expect(editableText.controller.selection.baseOffset, 0);
    });

    testWidgets('2. Typing "hey" into checklist item updates document without phantom placeholder characters', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      controller.toggleChecklist();
      await tester.pumpAndSettle();

      // User enters text into the checklist item TextField
      await tester.enterText(find.byType(TextField), 'hey');
      await tester.pumpAndSettle();

      // Controller document should be updated with pure "hey"
      expect(controller.document.blocks.first, isA<ChecklistItemBlock>());
      expect(controller.document.blocks.first.plainText, 'hey');
      expect(controller.toMarkdown(), '- [ ] hey');

      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.controller.text, 'hey');
    });

    testWidgets('3. Checkbox icon is physically isolated from TextField (cursor cannot appear before checkbox)', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      controller.toggleChecklist();
      await tester.pumpAndSettle();

      // Checkbox is in a separate widget on the left
      final iconFinder = find.byIcon(PhosphorIconsRegular.square);
      final textFieldFinder = find.byType(TextField);

      expect(iconFinder, findsOneWidget);
      expect(textFieldFinder, findsOneWidget);

      final iconBox = tester.getRect(iconFinder);
      final textBox = tester.getRect(textFieldFinder);

      // Icon is strictly to the left of the text field
      expect(iconBox.right <= textBox.left, isTrue);
    });

    testWidgets('4. Scenario 1: Typing a sentence and pressing Enter creates a new checkbox on the second line that persists when typing', (tester) async {
      controller.setMarkdown('Existing note text\n- [ ] Buy groceries');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);

      // Focus the checklist TextField
      final checklistTextField = find.descendant(
        of: find.byType(RichChecklistEditor),
        matching: find.byType(TextField),
      );
      await tester.tap(checklistTextField);
      await tester.pumpAndSettle();

      // Press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Second checklist item is created
      expect(controller.document.blocks.length, 3);
      expect(controller.document.blocks[1], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[1].plainText, 'Buy groceries');
      expect(controller.document.blocks[2], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[2].plainText, '');

      // Two checkbox icons appear
      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(2));

      // Now type on the second line: "Fresh milk"
      final secondItemTextField = find.descendant(
        of: find.byType(RichChecklistEditor),
        matching: find.byType(TextField),
      ).last;
      await tester.enterText(secondItemTextField, 'Fresh milk');
      await tester.pumpAndSettle();

      // Both checkboxes still persist (checkbox does NOT disappear)
      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(2));
      expect(controller.document.blocks[2], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[2].plainText, 'Fresh milk');
      expect(controller.toMarkdown(), 'Existing note text\n- [ ] Buy groceries\n- [ ] Fresh milk');
    });

    testWidgets('5. Scenario 2: In a new note, clicking checklist icon and pressing Enter after first item creates checkbox with cursor inside second item', (tester) async {
      // New note starts empty
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // User immediately clicks checklist icon
      controller.toggleChecklist();
      await tester.pumpAndSettle();

      // Type first item
      await tester.enterText(find.byType(TextField), 'First item');
      await tester.pumpAndSettle();

      // Focus and send Enter
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Document has 2 checklist items
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[0].plainText, 'First item');
      expect(controller.document.blocks[1], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[1].plainText, '');

      // Line 2 has a checkbox
      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(2));

      // Cursor is focused in the second item at offset 0 (which is after the checkbox widget)
      final textFields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(textFields.length, 2);
      expect(textFields.last.controller.selection.baseOffset, 0);
      expect(textFields.last.controller.text, '');
    });

    testWidgets('6. Pressing Enter on empty checklist item converts to paragraph', (tester) async {
      controller.setMarkdown('- [ ] Task 1\n- [ ] ');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final checklistFields = find.descendant(
        of: find.byType(RichChecklistEditor),
        matching: find.byType(TextField),
      );
      expect(checklistFields, findsNWidgets(2));

      // Tap the second empty item
      await tester.tap(checklistFields.last);
      await tester.pumpAndSettle();

      // Press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Second block is converted to ParagraphBlock
      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[1], isA<ParagraphBlock>());
      expect(controller.document.blocks[1].plainText, '');

      // Only 1 checkbox remains
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
    });

    testWidgets('7. Pressing Backspace at offset 0 of empty checklist item removes it', (tester) async {
      controller.setMarkdown('- [ ] Task 1\n- [ ] ');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final checklistFields = find.descendant(
        of: find.byType(RichChecklistEditor),
        matching: find.byType(TextField),
      );
      expect(checklistFields, findsNWidgets(2));

      // Tap the second empty item
      await tester.tap(checklistFields.last);
      await tester.pumpAndSettle();

      // Press Backspace at offset 0
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      // Only 1 checklist item remains
      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks[0], isA<ChecklistItemBlock>());
      expect(controller.document.blocks[0].plainText, 'Task 1');
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
    });

    testWidgets('8. Tapping checkbox toggles checked/completed state', (tester) async {
      controller.setMarkdown('- [ ] First task');
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsNothing);

      // Tap the checkbox icon
      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      // Now checked
      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, true);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsOneWidget);
      expect(controller.toMarkdown(), '- [x] First task');

      // Tap again to uncheck
      await tester.tap(find.byIcon(PhosphorIconsRegular.checkSquare));
      await tester.pumpAndSettle();

      expect((controller.document.blocks[0] as ChecklistItemBlock).isChecked, false);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(controller.toMarkdown(), '- [ ] First task');
    });

    testWidgets('9. Bulleted list items continue to work smoothly in RichTextEditor', (tester) async {
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
      expect(updatedEditable.controller.selection.baseOffset, 17);
    });
  });
}
