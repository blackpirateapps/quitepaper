import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildTestEditor({
    required MarkdownEditingController controller,
    required FocusNode focusNode,
    bool isDark = false,
  }) {
    return MaterialApp(
      theme: isDark
          ? ThemeData.dark().copyWith(extensions: [AppColors.dark])
          : ThemeData.light().copyWith(extensions: [AppColors.light]),
      home: Scaffold(
        body: MarkdownEditor(
          controller: controller,
          focusNode: focusNode,
        ),
      ),
    );
  }

  group('MarkdownEditor Widget Tests', () {
    testWidgets('renders initial Markdown text and allows typing and editing', (tester) async {
      final controller = MarkdownEditingController(text: '# Hello\nThis is **bold** text.');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
      ));

      expect(find.byType(MarkdownEditor), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, equals('# Hello\nThis is **bold** text.'));

      // Enter text
      await tester.enterText(find.byType(TextField), '# New Title\n- Item 1\n- Item 2');
      await tester.pumpAndSettle();

      expect(controller.text, equals('# New Title\n- Item 1\n- Item 2'));
    });

    testWidgets('supports cursor positioning and selection in Markdown source', (tester) async {
      final controller = MarkdownEditingController(text: 'Hello **world**');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
      ));

      // Set selection inside "**world**"
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 15);
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, equals(6));
      expect(controller.selection.extentOffset, equals(15));
      expect(controller.text.substring(controller.selection.start, controller.selection.end),
          equals('**world**'));
    });

    testWidgets('renders cleanly in both Light and Dark themes', (tester) async {
      final controller = MarkdownEditingController(text: '# Light & Dark Theme Support\n`code`');
      final focusNode = FocusNode();

      // Light theme
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        isDark: false,
      ));
      expect(find.byType(MarkdownEditor), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(buildTestEditor(
        controller: controller,
        focusNode: focusNode,
        isDark: true,
      ));
      expect(find.byType(MarkdownEditor), findsOneWidget);
    });
  });
}
