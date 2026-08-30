import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/presentation/plain_text_viewer.dart';
import 'package:quitepaper/core/attachments/text/attachment_text_detector.dart';

void main() {
  Widget buildViewer({
    required String text,
    TextAttachmentFormat format = TextAttachmentFormat.sourceCode,
    String? fileName,
    String? mimeType,
    String? overrideLanguageId,
    String? searchQuery,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PlainTextViewer(
            text: text,
            format: format,
            fileName: fileName,
            mimeType: mimeType,
            overrideLanguageId: overrideLanguageId,
            searchQuery: searchQuery,
          ),
        ),
      ),
    );
  }

  group('PlainTextViewer - Syntax Highlighting and Features', () {
    testWidgets('renders source code with line numbers and selectable text', (tester) async {
      const code = 'final int answer = 42;\nprint(answer);';
      await tester.pumpWidget(buildViewer(
        text: code,
        fileName: 'solution.dart',
        mimeType: 'text/x-dart',
      ));
      await tester.pumpAndSettle();

      // Verify text is present
      expect(find.text(code, findRichText: true), findsOneWidget);
      // Verify line numbers 1 and 2
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('handles presentation language override', (tester) async {
      const code = 'SELECT * FROM users WHERE id = 1;';
      await tester.pumpWidget(buildViewer(
        text: code,
        fileName: 'query.txt',
        overrideLanguageId: 'sql',
      ));
      await tester.pumpAndSettle();

      expect(find.text(code, findRichText: true), findsOneWidget);
    });

    testWidgets('handles empty text gracefully', (tester) async {
      await tester.pumpWidget(buildViewer(
        text: '',
        fileName: 'empty.dart',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Empty file'), findsOneWidget);
    });

    testWidgets('highlights search queries in attachment', (tester) async {
      const code = 'const hello = "world";\nprint(hello);';
      await tester.pumpWidget(buildViewer(
        text: code,
        fileName: 'test.js',
        searchQuery: 'hello',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}
