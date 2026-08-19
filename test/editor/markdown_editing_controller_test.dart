import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  group('MarkdownEditingController', () {
    testWidgets('buildTextSpan produces styled span matching text', (tester) async {
      final controller = MarkdownEditingController(
        text: '# Heading\n**bold text**',
      );

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('# Heading\n**bold text**'));
    });

    testWidgets('text mutations update TextSpan without losing Markdown markers', (tester) async {
      final controller = MarkdownEditingController(text: 'Initial');

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      controller.text = 'Updated with `inline code`';
      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('Updated with `inline code`'));
    });

    testWidgets('supports static custom MarkdownStyles override', (tester) async {
      final customStyles = MarkdownStyles.fromColors(AppColors.dark);
      final controller = MarkdownEditingController(
        text: '# Dark Mode Style',
        styles: customStyles,
      );

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('# Dark Mode Style'));
      expect(controller.styles, equals(customStyles));
    });

    testWidgets('preserves spaces immediately after hashes and inside heading text', (tester) async {
      final controller = MarkdownEditingController(
        text: '#   \n##   My Heading with   spaces   ',
      );

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('#   \n##   My Heading with   spaces   '));
    });

    testWidgets('preserves spaces immediately after checkbox markers and inside task text', (tester) async {
      final controller = MarkdownEditingController(
        text: '- [ ]   \n- [x]   Completed task with   spaces   ',
      );

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('- [ ]   \n- [x]   Completed task with   spaces   '));
    });
  });
}
