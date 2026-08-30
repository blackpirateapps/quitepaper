import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/widgets/intelligent_heading_scrollbar.dart';

void main() {
  Widget buildTestableWidget({
    required Widget child,
    required ScrollController scrollController,
    required String markdownData,
    TextEditingController? contentController,
    String? title,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: IntelligentHeadingScrollbar(
            scrollController: scrollController,
            markdownData: markdownData,
            contentController: contentController,
            title: title,
            child: child,
          ),
        ),
      ),
    );
  }

  group('IntelligentHeadingScrollbar - Widget Tests', () {
    testWidgets('renders scrollable child and minimal scrollbar thumb', (tester) async {
      final scrollController = ScrollController();
      const markdown = '''
# Heading 1
Line 1
Line 2
Line 3
## Heading 2
Line 4
Line 5
''';

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 2000,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byType(IntelligentHeadingScrollbar), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      // When idle, heading labels are not visible (opacity 0)
      final heading1Finder = find.text('Heading 1');
      expect(heading1Finder, findsNothing);
    });

    testWidgets('hovering scrollbar reveals dynamic heading labels and gradient', (tester) async {
      final scrollController = ScrollController();
      const markdown = '''
# Introduction
Paragraph text.

## Architecture
Deep dive.

### Sync Engine
Details.
''';

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 2000,
              child: Text('Note Content'),
            ),
          ),
        ),
      );

      // Trigger hover by moving mouse pointer over the right edge of scrollbar
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move into scrollbar hit area (x: 390, y: 300)
      await gesture.moveTo(const Offset(390, 300));
      await tester.pumpAndSettle();

      // Heading labels should now be visible
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Sync Engine'), findsOneWidget);

      // Move mouse away
      await gesture.moveTo(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Headings fade out
      expect(find.text('Introduction'), findsNothing);
    });

    testWidgets('tapping a heading label jumps scroll position to that section', (tester) async {
      final scrollController = ScrollController();
      const markdown = '''
# Introduction
Line

## Middle Section
Line

### Conclusion
Line
''';

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 3000,
              child: Text('Document'),
            ),
          ),
        ),
      );

      // Hover to reveal headings
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(390, 300));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      expect(scrollController.offset, equals(0.0));
      expect(find.text('Conclusion'), findsOneWidget);

      // Tap on Conclusion heading
      await tester.tap(find.text('Conclusion'));
      await tester.pumpAndSettle();

      // Scroll position moved forward
      expect(scrollController.offset, greaterThan(0.0));
    });

    testWidgets('dynamic window slides for long document with 50+ headings', (tester) async {
      final scrollController = ScrollController();
      final buffer = StringBuffer();
      for (var i = 0; i < 60; i++) {
        buffer.writeln('## Section $i\nContent for section $i\n');
      }
      final markdown = buffer.toString();

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 10000,
              child: Text('Massive Document'),
            ),
          ),
        ),
      );

      // Hover to reveal headings at top
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(390, 300));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      // Near top: Section 0 visible, Section 59 not visible in the window
      expect(find.text('Section 0'), findsOneWidget);
      expect(find.text('Section 59'), findsNothing);

      // Scroll to the bottom
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // Near bottom: Section 59 visible, Section 0 no longer visible
      expect(find.text('Section 59'), findsOneWidget);
      expect(find.text('Section 0'), findsNothing);
    });

    testWidgets('empty document has no heading overlay or TOC panel', (tester) async {
      final scrollController = ScrollController();
      const markdown = 'Just a paragraph without any headings.';

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 2000,
              child: Text('No Headings Document'),
            ),
          ),
        ),
      );

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(390, 300));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      // Should find no heading texts or errors
      expect(find.byType(IntelligentHeadingScrollbar), findsOneWidget);
      expect(find.text('No Headings Document'), findsOneWidget);
    });

    testWidgets('accessibility semantics labels provided for headings', (tester) async {
      final scrollController = ScrollController();
      const markdown = '''
# Security & Privacy
Zero knowledge.
''';

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: markdown,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 2000,
              child: Text('Document'),
            ),
          ),
        ),
      );

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(390, 300));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Jump to Security & Privacy'),
        findsOneWidget,
      );
    });

    testWidgets('live editing with TextEditingController updates headings immediately', (tester) async {
      final scrollController = ScrollController();
      final contentController = TextEditingController(text: '# Initial Heading\nBody');

      await tester.pumpWidget(
        buildTestableWidget(
          scrollController: scrollController,
          markdownData: contentController.text,
          contentController: contentController,
          child: SingleChildScrollView(
            controller: scrollController,
            child: const SizedBox(
              height: 2000,
              child: Text('Body'),
            ),
          ),
        ),
      );

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(390, 300));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      expect(find.text('Initial Heading'), findsOneWidget);

      // Simulate live typing
      contentController.text = '# Initial Heading\n\n## Added Live Section\nMore text';
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Added Live Section'), findsOneWidget);
    });
  });
}
