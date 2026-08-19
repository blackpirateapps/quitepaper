import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  group('Markdown Image Parser & Controller Tests', () {
    const assetId = '550e8400-e29b-41d4-a716-446655440000';
    final styles = MarkdownStyles.fromColors(AppColors.light);

    test('Parses ![alt](qp://asset/<UUID>) token with exact character offset preservation', () {
      const text = '# Note Title\n\nHere is a photo:\n![Mountain Hike](qp://asset/$assetId)\n\nEnd of note.';
      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);

      expect(span.toPlainText(), equals(text));
      expect(span.toPlainText().length, equals(text.length));
    });

    test('Parses multiple images, links, and text without offset drift', () {
      const text = '''
# Architecture

![System Flow](qp://asset/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa)

For more info see [External Spec](https://example.com/spec).

![Diagram 2](qp://asset/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb)
''';

      final span = MarkdownParser.buildTextSpan(text: text, styles: styles);
      expect(span.toPlainText(), equals(text));
    });

    testWidgets('MarkdownEditingController builds text spans matching raw content', (tester) async {
      const text = 'Hello world\n![Cover](qp://asset/$assetId)\nGoodbye';
      final controller = MarkdownEditingController(text: text, styles: styles);

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

      final builtSpan = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(builtSpan.toPlainText(), equals(text));
    });
  });
}
