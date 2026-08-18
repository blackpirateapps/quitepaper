import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';

void main() {
  Widget buildWrapper(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('QuietMarkdownPreview Widget', () {
    testWidgets('renders No content placeholder when markdownData is empty',
        (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(markdownData: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No content'), findsOneWidget);
    });

    testWidgets('renders title and tags when provided in preview',
        (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            title: 'Sample Note Title',
            tags: ['work', 'design'],
            markdownData: '# Heading\nThis is content.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sample Note Title'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);
      expect(find.text('#design'), findsOneWidget);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('This is content.'), findsOneWidget);
    });

    testWidgets('renders shrinkWrapped preview without scrolling',
        (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          const SingleChildScrollView(
            child: QuietMarkdownPreview(
              markdownData: '### Mini heading\nShrinkwrap content paragraph.',
              shrinkWrap: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mini heading'), findsOneWidget);
      expect(find.text('Shrinkwrap content paragraph.'), findsOneWidget);
    });

    testWidgets('handles massive markdown document with virtualized lazy rendering',
        (tester) async {
      final longDoc = List.generate(
        300,
        (i) => '### Header Section $i\n\nParagraph text for section $i with details.',
      ).join('\n\n');

      final scrollController = ScrollController();

      await tester.pumpWidget(
        buildWrapper(
          QuietMarkdownPreview(
            title: 'Massive Document',
            markdownData: longDoc,
            scrollController: scrollController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top section should be visible
      expect(find.text('Massive Document'), findsOneWidget);
      expect(find.text('Header Section 0'), findsOneWidget);

      // Distant section 290 is NOT rendered initially (virtualized!)
      expect(find.text('Header Section 290'), findsNothing);

      // Scroll down deep into the document
      scrollController.jumpTo(10000);
      await tester.pumpAndSettle();

      // After scrolling, later sections are dynamically transformed and rendered
      expect(find.text('Header Section 0'), findsNothing); // top item unmounted
    });

    testWidgets('wraps preview content in SelectionArea for multi-line cross-paragraph selection',
        (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            title: 'Selectable Document',
            markdownData: 'Line 1 paragraph.\n\nLine 2 paragraph with **bold**.\n\n- Item 1\n- Item 2',
            selectable: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text('Selectable Document'), findsOneWidget);
      expect(find.text('Line 1 paragraph.'), findsOneWidget);
      expect(find.textContaining('Line 2 paragraph with'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });
}
