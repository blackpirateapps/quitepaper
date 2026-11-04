import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestApp({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          focusNode: focusNode,
        ),
      ),
    );
  }

  testWidgets('Ctrl+B shortcut wraps selection with **', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello world');
    final focusNode = FocusNode();

    await tester.pumpWidget(buildTestApp(
      controller: controller,
      focusNode: focusNode,
    ));

    focusNode.requestFocus();
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    await tester.pump();

    // Send Ctrl+B
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.text, equals('Hello **world**'));
  });

  testWidgets('Ctrl+I shortcut wraps selection with *', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello world');
    final focusNode = FocusNode();

    await tester.pumpWidget(buildTestApp(
      controller: controller,
      focusNode: focusNode,
    ));

    focusNode.requestFocus();
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    await tester.pump();

    // Send Ctrl+I
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.text, equals('Hello *world*'));
  });

  testWidgets('Ctrl+V shortcut triggers onPaste callback', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello');
    final focusNode = FocusNode();
    var pasteInvoked = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          focusNode: focusNode,
          onPaste: () {
            pasteInvoked = true;
          },
        ),
      ),
    ));

    focusNode.requestFocus();
    await tester.pump();

    // Send Ctrl+V
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(pasteInvoked, isTrue);
  });

  testWidgets('Ctrl+V shortcut in SuperEditor mode triggers onPaste callback', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello SuperEditor');
    final focusNode = FocusNode();
    var pasteInvoked = false;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            editingStyle: EditorEditingStyle.superEditor,
            onPaste: () {
              pasteInvoked = true;
            },
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(pasteInvoked, isTrue);
  });

  testWidgets('Ctrl+V shortcut in Visual (wysiwyg) mode triggers onPaste callback', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello Visual');
    final focusNode = FocusNode();
    var pasteInvoked = false;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            editingStyle: EditorEditingStyle.wysiwyg,
            onPaste: () {
              pasteInvoked = true;
            },
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(pasteInvoked, isTrue);
  });

  testWidgets('Ctrl+V shortcut in Markdown table segment triggers onPaste callback', (tester) async {
    final controller = MarkdownEditingController(
      text: 'Before table\n\n| Col 1 | Col 2 |\n|---|---|\n| A | B |\n\nAfter table',
    );
    final focusNode = FocusNode();
    var pasteInvoked = false;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            editingStyle: EditorEditingStyle.markdown,
            onPaste: () {
              pasteInvoked = true;
            },
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    final textFields = find.byType(TextField);
    expect(textFields, findsWidgets);
    await tester.tap(textFields.first);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(pasteInvoked, isTrue);
  });
}
