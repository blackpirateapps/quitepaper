import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_fab.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/search/presentation/search_screen.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({required SharedPreferences prefs, Widget? home}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: home ?? const NotesScreen(),
      ),
    );
  }

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
  }

  void setTabletSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0;
  }

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('Core Writing Loop & Notes Browsing User Journeys', () {
    testWidgets('Journey 1: Quick note creation -> type content -> back -> appears in list',
        (tester) async {
      setPhoneSize(tester);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Empty state shown
      expect(find.text('No notes yet'), findsOneWidget);

      // Tap + FAB
      await tester.tap(find.byType(QuietFab));
      await tester.pumpAndSettle();

      // In Editor
      expect(find.byType(TextField), findsNWidgets(2));

      // Enter title and content
      await tester.enterText(find.byType(TextField).first, 'Core Writing Loop');
      await tester.enterText(find.byType(TextField).last, 'Writing in Quiet Paper feels calm and luxurious.');
      await tester.pump(const Duration(milliseconds: 800)); // autosave debounce

      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Note appears in Notes list
      expect(find.text('Core Writing Loop'), findsOneWidget);
      expect(find.text('Writing in Quiet Paper feels calm and luxurious.'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Journey 2: Return to note -> content is completely preserved',
        (tester) async {
      setPhoneSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await repository.saveNote(Note(
        id: 'exist-1',
        title: 'Project Ideas',
        content: 'Idea 1: Local first notes\nIdea 2: Markdown preview',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Project Ideas'), findsOneWidget);

      // Tap note to open
      await tester.tap(find.text('Project Ideas'));
      await tester.pumpAndSettle();

      // Content intact in editor
      expect(find.text('Project Ideas'), findsOneWidget);
      expect(find.text('Idea 1: Local first notes\nIdea 2: Markdown preview'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Typing in edit mode and immediately switching to Markdown preview renders updated content',
        (tester) async {
      setPhoneSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final note = Note(
        id: 'edit-prev-1',
        title: 'Initial Title',
        content: 'Initial content',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(buildApp(prefs: prefs, home: EditorScreen(note: note)));
      await tester.pumpAndSettle();

      // In edit mode: type new content into body
      await tester.enterText(find.byType(TextField).last, '# Newly Typed Heading\n**Newly bolded text**');
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Tap Markdown preview
      expect(find.text('Markdown preview'), findsOneWidget);
      await tester.tap(find.text('Markdown preview'));
      await tester.pumpAndSettle();

      // Preview mode is active: text fields gone, rendered markdown visible!
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Newly Typed Heading'), findsOneWidget);

      // Switch back to edit
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Switch to edit'), findsOneWidget);
      await tester.tap(find.text('Switch to edit'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('# Newly Typed Heading\n**Newly bolded text**'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Journey 3: Immediate Search -> debounced matching -> match highlight -> open result',
        (tester) async {
      setPhoneSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await repository.saveNote(Note(
        id: 'search-1',
        title: 'Flutter Architecture',
        content: 'Drift SQLite persistence with Riverpod',
        createdAt: now,
        updatedAt: now,
      ));

      await repository.saveNote(Note(
        id: 'search-2',
        title: 'Recipe Book',
        content: 'Pasta with garlic and olive oil',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);

      // Type search query
      await tester.enterText(find.byType(TextField), 'Architecture');
      await tester.pump(const Duration(milliseconds: 250)); // debounce
      await tester.pumpAndSettle();

      // Only search-1 matches
      expect(find.text('Flutter Architecture'), findsOneWidget);
      expect(find.text('Recipe Book'), findsNothing);

      // Tap result to open editor
      await tester.tap(find.text('Flutter Architecture'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.text('Drift SQLite persistence with Riverpod'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Journey 4: Tag filtering -> filter bar tap -> displays filtered notes',
        (tester) async {
      setPhoneSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await repository.saveNote(Note(
        id: 'tag-1',
        title: 'Flutter Note',
        content: 'Some text #mobile #dev',
        createdAt: now,
        updatedAt: now,
        tags: const ['mobile', 'dev'],
      ));

      await repository.saveNote(Note(
        id: 'tag-2',
        title: 'Design Note',
        content: 'Design system #design',
        createdAt: now,
        updatedAt: now,
        tags: const ['design'],
      ));

      await tester.pumpWidget(buildApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Note'), findsOneWidget);
      expect(find.text('Design Note'), findsOneWidget);

      // Tap #design in the filter bar
      await tester.tap(find.text('#design'));
      await tester.pumpAndSettle();

      // Only Design Note is shown
      expect(find.text('Design Note'), findsOneWidget);
      expect(find.text('Flutter Note'), findsNothing);

      // Tap All to clear filter
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Note'), findsOneWidget);
      expect(find.text('Design Note'), findsOneWidget);

      await finishTest(tester);
    });

    test('Critical Regression Test: Trash indefinite persistence (Zero Auto-Delete)',
        () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 90));
      await repository.saveNote(Note(
        id: 'trash-ancient',
        title: 'Ancient Trashed Note',
        content: '90 days old in trash',
        createdAt: oldDate,
        updatedAt: oldDate,
        isTrashed: true,
        deletedAt: oldDate,
      ));

      // Query trash directly
      final trashedNotes = await repository.watchNotes(isTrashed: true).first;
      expect(trashedNotes.length, 1);
      expect(trashedNotes.first.id, 'trash-ancient');
      expect(trashedNotes.first.title, 'Ancient Trashed Note');

      // Active notes do NOT include trash
      final activeNotes = await repository.watchNotes(isTrashed: false).first;
      expect(activeNotes, isEmpty);
    });

    testWidgets('Tablet Three-Pane Split View: Note selection and quiet placeholder',
        (tester) async {
      setTabletSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await repository.saveNote(Note(
        id: 'tab-1',
        title: 'Tablet Note One',
        content: 'Content on tablet',
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(buildApp(prefs: prefs));
      await tester.pumpAndSettle();

      // 3-pane elements visible
      expect(find.text('All Notes'), findsOneWidget); // sidebar
      expect(find.text('Tablet Note One'), findsOneWidget); // middle list
      expect(find.text('No note selected'), findsOneWidget); // right placeholder

      // Select note from list
      await tester.tap(find.text('Tablet Note One'));
      await tester.pumpAndSettle();

      // Right pane now displays editor with note content
      expect(find.text('No note selected'), findsNothing);
      expect(find.text('Content on tablet'), findsOneWidget);

      // Close note on tablet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Deselected back to quiet placeholder
      expect(find.text('No note selected'), findsOneWidget);

      await finishTest(tester);
    });
  });
}
