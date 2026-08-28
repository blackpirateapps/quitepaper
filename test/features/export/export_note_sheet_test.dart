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

  group('ExportNoteSheet Widget Tests', () {
    testWidgets('renders all format tiles and note title', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-1',
        title: 'Meeting Notes & Action Items',
        content: 'Content here.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        tags: const ['work'],
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      expect(find.text('Export Note'), findsOneWidget);
      expect(find.text('Meeting Notes & Action Items'), findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('PDF Document'), findsOneWidget);
      expect(find.text('HTML Webpage'), findsOneWidget);
      expect(find.text('Plain Text'), findsOneWidget);
      expect(find.text('Microsoft Word'), findsOneWidget);
      expect(find.text('Quiet Paper Package'), findsOneWidget);
      expect(find.text('Save File'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('toggles advanced options container when tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-2',
        title: 'Project Roadmap',
        content: 'Roadmap content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Options'), findsOneWidget);
      expect(find.text('Include metadata'), findsNothing);

      // Tap Advanced Options to expand
      await tester.tap(find.text('Advanced Options'));
      await tester.pumpAndSettle();

      expect(find.text('Include metadata'), findsOneWidget);
      expect(find.text('Include attachments'), findsOneWidget);
      expect(find.text('Include OCR recognized text'), findsOneWidget);
    });

    testWidgets('switches selected format when format tile is tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final note = Note(
        id: 'test-3',
        title: 'Design Specs',
        content: 'Design specs.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(createWidgetUnderTest(note));
      await tester.pumpAndSettle();

      // Tap PDF tile
      await tester.tap(find.text('PDF Document'));
      await tester.pumpAndSettle();

      // Tap DOCX tile
      await tester.tap(find.text('Microsoft Word'));
      await tester.pumpAndSettle();
    });
  });
}
