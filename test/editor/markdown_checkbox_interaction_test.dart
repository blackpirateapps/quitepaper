import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestApp({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('tapping checkbox marker on "- [ ]" toggles it to "- [x]"', (tester) async {
    final controller = MarkdownEditingController(text: '- [ ] Buy groceries');
    final focusNode = FocusNode();
    String? updatedText;

    await tester.pumpWidget(buildTestApp(
      controller: controller,
      focusNode: focusNode,
      onChanged: (text) => updatedText = text,
    ));

    // Tap at top left of TextField (within the checkbox marker "- [ ]")
    final textFieldTopLeft = tester.getTopLeft(find.byType(TextField));
    await tester.tapAt(textFieldTopLeft + const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(controller.text, equals('- [x] Buy groceries'));
    expect(updatedText, equals('- [x] Buy groceries'));

    // Wait to avoid double-tap gesture
    await tester.pump(const Duration(milliseconds: 500));

    // Tap again to toggle back to unchecked
    await tester.tapAt(textFieldTopLeft + const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(controller.text, equals('- [ ] Buy groceries'));
  });

  testWidgets('tapping on task text does not toggle checkbox', (tester) async {
    final controller = MarkdownEditingController(text: '- [ ] Buy groceries');
    final focusNode = FocusNode();
    String? updatedText;

    await tester.pumpWidget(buildTestApp(
      controller: controller,
      focusNode: focusNode,
      onChanged: (text) => updatedText = text,
    ));

    // Tap far to the right (on the text "groceries")
    final textFieldTopRight = tester.getTopRight(find.byType(TextField));
    await tester.tapAt(textFieldTopRight - const Offset(20, -8));
    await tester.pumpAndSettle();

    // Should remain unchecked
    expect(controller.text, equals('- [ ] Buy groceries'));
    expect(updatedText, isNull);
  });
}
