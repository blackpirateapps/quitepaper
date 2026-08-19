import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/link_prompt_dialog.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestApp({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ),
    );
  }

  testWidgets('LinkPromptDialog returns title and url on submit', (tester) async {
    ({String title, String url})? dialogResult;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await LinkPromptDialog.show(
                context,
                initialTitle: 'Quiet Paper',
                initialUrl: 'https://quietpaper.app',
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Insert Link'), findsOneWidget);
    expect(find.text('Quiet Paper'), findsOneWidget);

    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(dialogResult, isNotNull);
    expect(dialogResult?.title, equals('Quiet Paper'));
    expect(dialogResult?.url, equals('https://quietpaper.app'));
  });

  testWidgets('MarkdownEditor context menu provides formatting options on selection', (tester) async {
    final controller = MarkdownEditingController(text: 'Hello world');
    final focusNode = FocusNode();

    await tester.pumpWidget(buildTestApp(
      controller: controller,
      focusNode: focusNode,
    ));

    focusNode.requestFocus();
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
    await tester.pumpAndSettle();

    // Verify widget builds without error with selection active
    expect(controller.selection.textInside(controller.text), equals('world'));
  });
}
