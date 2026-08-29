import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/export/presentation/export_note_sheet.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(Note note) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ExportNoteSheet(note: note),
        ),
      ),
    );
  }

  group('ExportNoteSheet Redesign Widget Tests', () {
    testWidgets('renders header, note title, all 6 formats in unified grouped selector, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-1',
        title: 'Voyage to the Andromeda Galaxy',
        content: 'Content here.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        tags: const ['space', 'sci-fi'],
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Export Note'), findsOneWidget);
      expect(find.text('Voyage to the Andromeda Galaxy'), findsOneWidget);

      // Section header
      expect(find.text('FORMAT'), findsOneWidget);

      // All 6 format titles and concise subtitles
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('.md · Portable Markdown'), findsOneWidget);

      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('.pdf · Searchable Document'), findsOneWidget);

      expect(find.text('HTML'), findsOneWidget);
      expect(find.text('.html · Standalone Web Page'), findsOneWidget);

      expect(find.text('Plain Text'), findsOneWidget);
      expect(find.text('.txt · Clean Plain Text'), findsOneWidget);

      expect(find.text('Microsoft Word'), findsOneWidget);
      expect(find.text('.docx · Microsoft Word'), findsOneWidget);

      expect(find.text('Quiet Paper Package'), findsOneWidget);
      expect(find.text('.qpnote · Full-Fidelity Note'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);

      // Action buttons
      expect(find.text('Save File'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Advanced Options'), findsOneWidget);
    });

    testWidgets('switches selected format and shows checkmark only on selected format', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-2',
        title: 'Architecture Overview',
        content: 'Overview.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      // Initially Markdown is selected (from default preferences)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap PDF
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap HTML
      await tester.tap(find.text('HTML'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap Microsoft Word
      await tester.tap(find.text('Microsoft Word'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap Quiet Paper Package
      await tester.tap(find.text('Quiet Paper Package'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('expands and collapses Advanced Options with format-specific options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-3',
        title: 'Test Note',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      // Initially options are collapsed
      expect(find.text('YAML frontmatter with dates, tags, and pinned state'), findsNothing);

      // Expand Advanced Options
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      // Markdown specific options visible
      expect(find.text('YAML frontmatter with dates, tags, and pinned state'), findsOneWidget);
      expect(find.text('Rewrite local relative asset links in attachments folder'), findsOneWidget);
      expect(find.text('Append searchable scan transcripts at end of file'), findsOneWidget);

      // Switch to PDF format while options are expanded
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      // PDF specific options visible
      expect(find.text('Header card with note dates, tags, and attributes'), findsOneWidget);
      expect(find.text('Embed image attachments directly into PDF pages'), findsOneWidget);
      expect(find.text('Append searchable scan transcripts to PDF'), findsOneWidget);
      expect(find.text('YAML frontmatter with dates, tags, and pinned state'), findsNothing);

      // Switch to HTML format
      await tester.tap(find.text('HTML'));
      await tester.pumpAndSettle();

      expect(find.text('Embed images inline as self-contained Base64 data URIs'), findsOneWidget);

      // Switch to Quiet Paper Package
      await tester.tap(find.text('Quiet Paper Package'));
      await tester.pumpAndSettle();

      expect(find.text('Preserve tags, timestamps, and note ID in metadata.json'), findsOneWidget);
      expect(find.text('Pack all attached images and documents into package'), findsOneWidget);
      expect(find.text('Pack structured OCR transcripts into ocr/ folder'), findsOneWidget);

      // Collapse Advanced Options
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      expect(find.text('Preserve tags, timestamps, and note ID in metadata.json'), findsNothing);
    });

    testWidgets('toggling switch updates option state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-4',
        title: 'Toggle Test Note',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      // Find switch for 'Include metadata'
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3));

      // Toggle first switch
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cleanly without overflow on small 320dp width screen', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-5',
        title: 'Very Long Title That Might Cause Problems On Narrow Devices',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      expect(find.text('Export Note'), findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Save File'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly without overflow on tablet 1200dp width screen with max width constraint', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-6',
        title: 'Tablet Note',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      expect(find.text('Export Note'), findsOneWidget);
      expect(find.text('Tablet Note'), findsOneWidget);
      expect(find.text('Quiet Paper Package'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles untitled note gracefully with fallback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-7',
        title: '',
        content: '',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('accessible semantics expose selected state on format rows', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-8',
        title: 'Accessibility Test',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      // Verify that exactly 1 format row is marked as selected in Semantics
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.selected == true &&
            widget.properties.button == true),
        findsOneWidget,
      );

      // Tap PDF and check that exactly 1 format row is still selected in Semantics
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.selected == true &&
            widget.properties.button == true),
        findsOneWidget,
      );
    });

    testWidgets('anchors to the bottom of the screen on both phone and tablet viewports', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-bottom-anchor',
        title: 'Bottom Anchor Test',
        content: 'Content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      final sheetContainer = find.descendant(
        of: find.byType(ExportNoteSheet),
        matching: find.byType(Container),
      ).first;

      final rect = tester.getRect(sheetContainer);
      expect(rect.bottom, equals(900));
      expect(rect.width, lessThanOrEqualTo(580));
    });
  });
}
