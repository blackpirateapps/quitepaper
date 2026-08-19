import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
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
}
