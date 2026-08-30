import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/presentation/plain_text_viewer.dart';
import 'package:quitepaper/core/attachments/text/attachment_text_detector.dart';

void main() {
  Widget buildViewer({
    required String text,
    TextAttachmentFormat format = TextAttachmentFormat.plainText,
    String? searchQuery,
    int currentMatchIndex = 0,
    ValueChanged<int>? onMatchesCountChanged,
    ScrollController? scrollController,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PlainTextViewer(
            text: text,
            format: format,
            searchQuery: searchQuery,
            currentMatchIndex: currentMatchIndex,
            onMatchesCountChanged: onMatchesCountChanged,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  group('PlainTextViewer - 1,000 Line Progressive Chunking & Global Search', () {
    testWidgets('Small files (<1,000 lines) render completely without chunk banner', (tester) async {
      final text = List.generate(50, (i) => 'Line ${i + 1} content').join('\n');
      await tester.pumpWidget(buildViewer(text: text));
      await tester.pumpAndSettle();

      expect(find.textContaining('Line 1 content', findRichText: true), findsOneWidget);
      expect(find.textContaining('Line 50 content', findRichText: true), findsOneWidget);
      expect(find.textContaining('Showing 1,000 of'), findsNothing);
      expect(find.text('Load next 1,000 lines'), findsNothing);
    });

    testWidgets('Large files (2,500 lines) load only first 1,000 lines initially and show chunk banner', (tester) async {
      final text = List.generate(2500, (i) => 'Line ${i + 1}: Alpha beta gamma').join('\n');
      await tester.pumpWidget(buildViewer(text: text));
      await tester.pumpAndSettle();

      // First line is rendered
      expect(find.textContaining('Line 1: Alpha beta gamma', findRichText: true), findsOneWidget);
      // Line 1,000 is rendered
      expect(find.textContaining('Line 1000: Alpha beta gamma', findRichText: true), findsOneWidget);
      // Line 1,500 is NOT yet rendered in the initial slice
      expect(find.textContaining('Line 1500: Alpha beta gamma', findRichText: true), findsNothing);

      // Chunk banner is present
      expect(find.text('Showing 1,000 of 2,500 lines (40%)'), findsOneWidget);
      expect(find.text('Load next 1,000 lines'), findsOneWidget);
      expect(find.text('Load all lines'), findsOneWidget);
    });

    testWidgets('Tapping "Load next 1,000 lines" expands window to 2,000 lines', (tester) async {
      tester.view.physicalSize = const Size(800, 40000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final text = List.generate(2500, (i) => 'Line ${i + 1}: Alpha beta gamma').join('\n');
      await tester.pumpWidget(buildViewer(text: text));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1,000 of 2,500 lines (40%)'), findsOneWidget);

      await tester.tap(find.text('Load next 1,000 lines'));
      await tester.pumpAndSettle();

      // Now 2,000 lines loaded
      expect(find.text('Showing 2,000 of 2,500 lines (80%)'), findsOneWidget);
      expect(find.textContaining('Line 1500: Alpha beta gamma', findRichText: true), findsOneWidget);
      expect(find.textContaining('Line 2200: Alpha beta gamma', findRichText: true), findsNothing);
    });

    testWidgets('Tapping "Load all lines" loads complete document and removes footer', (tester) async {
      tester.view.physicalSize = const Size(800, 40000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final text = List.generate(2500, (i) => 'Line ${i + 1}: Alpha beta gamma').join('\n');
      await tester.pumpWidget(buildViewer(text: text));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load all lines'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Line 2500: Alpha beta gamma', findRichText: true), findsOneWidget);
      expect(find.text('Load next 1,000 lines'), findsNothing);
      expect(find.textContaining('Showing 2,500 of 2,500'), findsNothing);
    });

    testWidgets('Scrolling near bottom automatically triggers progressive chunk loading', (tester) async {
      final text = List.generate(3000, (i) => 'Line ${i + 1}: Alpha beta gamma').join('\n');
      final controller = ScrollController();
      await tester.pumpWidget(buildViewer(text: text, scrollController: controller));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1,000 of 3,000 lines (33%)'), findsOneWidget);

      // Scroll to near bottom of current window (extentAfter < 600)
      controller.jumpTo(controller.position.maxScrollExtent - 200.0);
      await tester.pumpAndSettle();

      // Should automatically load next 1,000 lines
      expect(find.text('Showing 2,000 of 3,000 lines (66%)'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('Global search indexes full file and auto-expands loaded slice to target match line', (tester) async {
      final lines = List.generate(3500, (i) => 'Line ${i + 1}: regular text');
      lines[2800] = 'Line 2801: SPECIAL_DISCOVERY_KEYWORD';
      final text = lines.join('\n');

      int matchCount = 0;
      final controller = ScrollController();

      await tester.pumpWidget(buildViewer(
        text: text,
        searchQuery: 'SPECIAL_DISCOVERY_KEYWORD',
        currentMatchIndex: 0,
        onMatchesCountChanged: (c) => matchCount = c,
        scrollController: controller,
      ));
      await tester.pumpAndSettle();

      // 1. Matches count reports 1 across entire 3,500-line file
      expect(matchCount, equals(1));

      // 2. Because match is on line 2801, PlainTextViewer auto-expanded loaded lines to 3,000 lines
      expect(find.textContaining('SPECIAL_DISCOVERY_KEYWORD', findRichText: true), findsOneWidget);
      expect(find.text('Showing 3,000 of 3,500 lines (85%)'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Navigating to match beyond current window expands and scrolls', (tester) async {
      final lines = List.generate(3000, (i) => 'Line ${i + 1}: item');
      lines[400] = 'Line 401: UNIQUE_ITEM_FIRST';
      lines[2400] = 'Line 2401: UNIQUE_ITEM_SECOND';
      final text = lines.join('\n');

      int matchCount = 0;
      final controller = ScrollController();

      // First, render with first match
      await tester.pumpWidget(buildViewer(
        text: text,
        searchQuery: 'UNIQUE_ITEM',
        currentMatchIndex: 0,
        onMatchesCountChanged: (c) => matchCount = c,
        scrollController: controller,
      ));
      await tester.pumpAndSettle();

      expect(matchCount, equals(2));
      // Initially loaded only 1,000 lines because match 0 is on line 401
      expect(find.text('Showing 1,000 of 3,000 lines (33%)'), findsOneWidget);

      // Now switch to match index 1 (line 2401)
      await tester.pumpWidget(buildViewer(
        text: text,
        searchQuery: 'UNIQUE_ITEM',
        currentMatchIndex: 1,
        onMatchesCountChanged: (c) => matchCount = c,
        scrollController: controller,
      ));
      await tester.pumpAndSettle();

      // Should auto-expand to include line 2401 (up to 3000 lines)
      expect(find.textContaining('UNIQUE_ITEM_SECOND', findRichText: true), findsOneWidget);

      controller.dispose();
    });
  });
}
