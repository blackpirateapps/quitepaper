import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/app.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 360 x 800 logical dp
  }

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Widget buildTestApp({SharedPreferences? prefs}) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const QuietPaperApp(),
    );
  }

  testWidgets('Quiet Paper phone layout: empty state and note creation flow', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Verify main screen header and empty state
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.text('Start writing something.'), findsOneWidget);

    // Tap "Create note"
    await tester.tap(find.text('Create note'));
    await tester.pumpAndSettle();

    // Now on EditorScreen
    expect(find.byType(TextField), findsNWidgets(2)); // Title and content

    // Enter title and content with a tag
    await tester.enterText(find.byType(TextField).first, 'First Thoughts');
    await tester.enterText(
        find.byType(TextField).last, 'Writing my first note with #ideas.');
    await tester.pump(const Duration(milliseconds: 800)); // Allow debounced autosave

    // Tap back icon button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Check that we are back on main screen and note is listed
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('First Thoughts'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Search flow finds matching notes', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Pre-populate notes
    await repository.saveNote(Note(
      id: 'n-1',
      title: 'Architectural Blueprint',
      content: 'Using Flutter and Drift #tech',
      createdAt: now,
      updatedAt: now,
    ));

    await repository.saveNote(Note(
      id: 'n-2',
      title: 'Grocery list',
      content: 'Apples, bananas, milk #food',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Architectural Blueprint'), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);

    // Tap Search icon
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    // Type query
    await tester.enterText(find.byType(TextField), 'architect');
    await tester.pumpAndSettle();

    expect(find.text('Architectural Blueprint'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing);

    // Search by tag
    await tester.enterText(find.byType(TextField), 'food');
    await tester.pumpAndSettle();

    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Architectural Blueprint'), findsNothing);

    // Back to main
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await finishTest(tester);
  });

  testWidgets('Settings screen allows theme selection', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap Settings icon
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Light paper'), findsOneWidget);
    expect(find.text('Dark paper'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);

    // Select Dark paper
    await tester.tap(find.text('Dark paper'));
    await tester.pumpAndSettle();

    expect(prefs.getString('app_theme_mode'), 'dark');

    // Back to main
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await finishTest(tester);
  });

  testWidgets('Pinning and unpinning notes from context sheet', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'p-1',
      title: 'Important Note',
      content: 'Must remember this',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Important Note'), findsOneWidget);
    expect(find.text('Pinned'), findsNothing);

    // Long press to open context menu
    await tester.longPress(find.text('Important Note'));
    await tester.pumpAndSettle();

    expect(find.text('Pin note'), findsOneWidget);
    await tester.tap(find.text('Pin note'));
    await tester.pumpAndSettle();

    // Verify pinned header appeared
    expect(find.text('Pinned'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Markdown preview mode toggles cleanly in Editor', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final testNote = Note(
      id: 'prev-1',
      title: 'Markdown Test',
      content: '# Heading One\n**Bold text**\n- Item A\n- Item B',
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveNote(testNote);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: EditorScreen(note: testNote),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In edit mode: text fields are visible
    expect(find.byType(TextField), findsNWidgets(2));

    // Tap preview toggle icon
    await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
    await tester.pumpAndSettle();

    // TextFields are gone, rendered preview is shown
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Heading One'), findsOneWidget);

    // Tap toggle back
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    await finishTest(tester);
  });

  testWidgets('Tablet layout displays split view with active note editor', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'tab-1',
      title: 'Tablet Note',
      content: 'Testing split view master-detail layout',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Sidebar has "Notes" and "Tablet Note"
    expect(find.text('Tablet Note'), findsOneWidget);

    // Tap note in sidebar to open in detail view
    await tester.tap(find.text('Tablet Note'));
    await tester.pumpAndSettle();

    // Editor is visible on right pane simultaneously with sidebar
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('Tablet Note'), findsWidgets);

    await finishTest(tester);
  });
}
