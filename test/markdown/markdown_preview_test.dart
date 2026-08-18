import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    testWidgets('renders frontmatter properties (author, source, created, description) with icons and derives title',
        (tester) async {
      const markdown = '''---
title: "Attention Is All You Need"
author: Ashish Vaswani et al.
source: https://arxiv.org/abs/1706.03762
created: 2017-06-12
description: The paper introducing the Transformer architecture.
status: published
rating: 5
internal_id: 99482
---

# Transformer Architecture
The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.
''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Frontmatter title should be rendered as main document title
      expect(find.text('Attention Is All You Need'), findsOneWidget);

      // Frontmatter metadata card should be rendered
      expect(find.byType(QuietFrontmatterCard), findsOneWidget);

      // Recognized properties and values
      expect(find.text('Author'), findsOneWidget);
      expect(find.text('Ashish Vaswani et al.'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('https://arxiv.org/abs/1706.03762'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Jun 12, 2017'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('The paper introducing the Transformer architecture.'), findsOneWidget);

      // Icons
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);

      // Unrecognized fields must be hidden automatically
      expect(find.text('status'), findsNothing);
      expect(find.text('published'), findsNothing);
      expect(find.text('rating'), findsNothing);
      expect(find.text('internal_id'), findsNothing);
      expect(find.text('99482'), findsNothing);

      // Body content is rendered cleanly
      expect(find.text('Transformer Architecture'), findsOneWidget);
      expect(find.textContaining('The dominant sequence transduction models'), findsOneWidget);
    });

    testWidgets('triggers onTapLink when tapping on frontmatter source URL',
        (tester) async {
      String? tappedUrl;
      const markdown = '''---
source: https://example.com/flutter-docs
author: Google
---
# Main Content
''';

      await tester.pumpWidget(
        buildWrapper(
          QuietMarkdownPreview(
            markdownData: markdown,
            onTapLink: (text, href, title) {
              tappedUrl = href;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('https://example.com/flutter-docs'), findsOneWidget);
      await tester.tap(find.text('https://example.com/flutter-docs'));
      await tester.pumpAndSettle();

      expect(tappedUrl, equals('https://example.com/flutter-docs'));
    });

    testWidgets('hides frontmatter with only unknown keys without rendering empty card',
        (tester) async {
      const markdown = '''---
status: draft
draft_id: 1234
custom_flag: true
---
# Clean Note
This note only has unknown frontmatter keys.
''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietFrontmatterCard), findsNothing);
      expect(find.text('status'), findsNothing);
      expect(find.text('draft'), findsNothing);
      expect(find.text('draft_id'), findsNothing);
      expect(find.text('Clean Note'), findsOneWidget);
      expect(find.text('This note only has unknown frontmatter keys.'), findsOneWidget);
    });

    testWidgets('default onTapLink triggers LinkConfirmationDialog on untrusted domain link',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const markdown = '''---
source: https://untrusted-site.org/very/long/path/with/parameters?token=xyz
---
# Main Content
''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('https://untrusted-site.org/very/long/path/with/parameters?token=xyz'), findsOneWidget);
      await tester.tap(find.text('https://untrusted-site.org/very/long/path/with/parameters?token=xyz'));
      await tester.pumpAndSettle();

      // Verify LinkConfirmationDialog opened
      expect(find.text('Open External Link?'), findsOneWidget);
      expect(find.text('https://untrusted-site.org/very/long/path/with/parameters?token=xyz'), findsWidgets);
      expect(find.text('Trust links from untrusted-site.org in the future'), findsOneWidget);
    });

    testWidgets('renders ==highlighted text== using HighlightSyntax and custom styling',
        (tester) async {
      const markdown = 'Here is some ==highlighted text== inside a paragraph.';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure == delimiters are not rendered as literal text
      expect(find.textContaining('==highlighted text=='), findsNothing);
      // Ensure the text content inside highlight is rendered
      expect(find.text('highlighted text'), findsOneWidget);
      expect(find.textContaining('Here is some'), findsOneWidget);
    });
  });
}

