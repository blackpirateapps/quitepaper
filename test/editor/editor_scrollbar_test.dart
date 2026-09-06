import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/intelligent_heading_scrollbar.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('EditorScreen Intelligent Scrollbar Integration', () {
    late AppDatabase db;
    late NotesRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> finishTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    Widget createEditorApp(
      Note note, {
      bool initialPreview = false,
      double width = 400,
      double height = 400,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: SizedBox(
            width: width,
            height: height,
            child: EditorScreen(
              note: note,
              initialPreviewMode: initialPreview,
            ),
          ),
        ),
      );
    }

    testWidgets('EditorScreen in edit mode renders IntelligentHeadingScrollbar and displays headings on hover',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-scrollbar-1',
        title: 'System Design',
        content: '''
# Architecture Overview
The system is built on Flutter.
Paragraph 1 with extended architectural details.
Paragraph 2 with deep explanation of components.
Paragraph 3 with offline-first design principles.

## Database Layer
Drift SQLite persistence with migrations.
Paragraph 4 detailing schema and DAOs.
Paragraph 5 covering sync queues and local encryption.
Paragraph 6 detailing search indices.

### Encryption Core
Argon2id and XChaCha20-Poly1305.
Paragraph 7 on master keys and key derivation.
Paragraph 8 on cryptographic zero knowledge guarantees.
Paragraph 9 on session token protection.
''',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      expect(find.byType(IntelligentHeadingScrollbar), findsOneWidget);

      final scrollbarRect = tester.getRect(find.byType(IntelligentHeadingScrollbar));

      // Trigger hover over scrollbar
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(Offset(scrollbarRect.right - 8, scrollbarRect.center.dy));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Architecture Overview'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Database Layer'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Encryption Core'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('EditorScreen in preview mode renders IntelligentHeadingScrollbar',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-scrollbar-2',
        title: 'Preview Document',
        content: '''
# Executive Summary
Key takeaways.

## Detailed Metrics
Numbers and analytics.
''',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialPreview: true));
      await tester.pumpAndSettle();

      expect(find.byType(IntelligentHeadingScrollbar), findsOneWidget);

      final scrollbarRect = tester.getRect(find.byType(IntelligentHeadingScrollbar));

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(Offset(scrollbarRect.right - 8, scrollbarRect.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('Executive Summary'), findsOneWidget);
      expect(find.text('Detailed Metrics'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('switching notes updates headings to the new note without stale entries',
        (tester) async {
      final now = DateTime.now();
      final noteA = Note(
        id: 'note-a',
        title: 'Note A',
        content: '''
# Alpha Section
Content A line 1
Content A line 2
Content A line 3
Content A line 4
Content A line 5
Content A line 6
Content A line 7
Content A line 8
Content A line 9
Content A line 10
''',
        createdAt: now,
        updatedAt: now,
      );
      final noteB = Note(
        id: 'note-b',
        title: 'Note B',
        content: '''
# Beta Section
Content B line 1
Content B line 2
Content B line 3
Content B line 4
Content B line 5
Content B line 6
Content B line 7
Content B line 8
Content B line 9
Content B line 10
''',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(noteA);
      await repository.saveNote(noteB);

      // Render with Note A
      await tester.pumpWidget(createEditorApp(noteA));
      await tester.pumpAndSettle();

      final scrollbarRect = tester.getRect(find.byType(IntelligentHeadingScrollbar));

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(Offset(scrollbarRect.right - 8, scrollbarRect.center.dy));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Alpha Section'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Beta Section'), findsNothing);

      // Switch to Note B
      await tester.pumpWidget(createEditorApp(noteB));
      await tester.pumpAndSettle();

      // Move mouse again to trigger hover
      final rectB = tester.getRect(find.byType(IntelligentHeadingScrollbar));
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset(rectB.right - 8, rectB.center.dy));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Beta Section'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Alpha Section'), findsNothing);

      await finishTest(tester);
    });

    testWidgets(
        'EditorScreen on wide display pins scrollbar to viewport edge with medium paragraph width and supports margin scrolling',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-scrollbar-wide',
        title: 'Wide Document',
        content: '''
# Section 1
${List.generate(25, (i) => 'Line $i of text in Section 1').join('\n')}

# Section 2
${List.generate(25, (i) => 'Line $i of text in Section 2').join('\n')}
''',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      // Render on wide display (1200x800)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createEditorApp(note, width: 1200, height: 800));
      await tester.pumpAndSettle();

      final scrollbarFinder = find.byType(IntelligentHeadingScrollbar);
      expect(scrollbarFinder, findsOneWidget);

      final scrollbarRect = tester.getRect(scrollbarFinder);
      expect(scrollbarRect.width, equals(1200));
      expect(scrollbarRect.right, equals(1200));

      // Trigger hover over scrollbar at the far right edge of the screen
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(Offset(scrollbarRect.right - 8, scrollbarRect.center.dy));
      await tester.pumpAndSettle();

      // Heading labels appear
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Section 1'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'Section 2'), findsOneWidget);

      // Verify margin scrolling: pointer scroll event in the left margin (x=100) scrolls the document
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final initialOffset = scrollable.position.pixels;
      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(100, 300),
          scrollDelta: Offset(0, 120),
        ),
      );
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(initialOffset));

      await finishTest(tester);
    });
  });
}
