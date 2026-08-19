import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/app.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/core/widgets/quiet_fab.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/sidebar/presentation/sidebar_view.dart';
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

  testWidgets('Quiet Paper phone layout: empty state and note creation flow',
      (tester) async {
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

  testWidgets('Empty note is discarded on exit without cluttering note list',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);

    // Tap FAB
    await tester.tap(find.byType(QuietFab));
    await tester.pumpAndSettle();

    // Do not type anything, simply press back
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Should return to empty state without creating a blank draft
    expect(find.text('No notes yet'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Reopening note preserves content and state', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'reopen-1',
      title: 'Persistent Title',
      content: 'Paragraph 1\n\nParagraph 2 with **bold**',
      createdAt: now,
      updatedAt: now,
      tags: const ['saved'],
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Open note (opens in preview mode)
    await tester.tap(find.text('Persistent Title'));
    await tester.pumpAndSettle();

    // Verify preview mode is active with edit button next to 3-dots
    expect(find.byType(QuietMarkdownPreview), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    // Tap edit button to switch to edit mode
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Verify content loaded in text fields
    expect(find.text('Persistent Title'), findsOneWidget);
    expect(find.text('Paragraph 1\n\nParagraph 2 with **bold**'), findsOneWidget);

    // Modify content
    await tester.enterText(find.byType(TextField).last,
        'Paragraph 1\n\nParagraph 2 with **bold**\n\nParagraph 3');
    await tester.pump(const Duration(milliseconds: 800));

    // Leave
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Reopen (opens in preview mode)
    await tester.tap(find.text('Persistent Title'));
    await tester.pumpAndSettle();

    // Tap edit button to verify updated content in TextField
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Paragraph 1\n\nParagraph 2 with **bold**\n\nParagraph 3'),
        findsOneWidget);

    // Back to main
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await finishTest(tester);
  });

  testWidgets('Sidebar drawer navigation to Archive, Trash, Pinned',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify Sidebar contents
    expect(find.byType(SidebarView), findsOneWidget);
    expect(find.text('Quiet Paper'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('All Notes'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);

    // Navigate to Archive
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsWidgets);
    expect(find.text('Archive is empty'), findsOneWidget);
    expect(find.text('Archived notes will appear here.'), findsOneWidget);

    // Open drawer again and navigate to Trash
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Trash'), findsWidgets);
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(
        find.text(
            'Notes stay here until you delete them\npermanently.'),
        findsOneWidget);

    // Open drawer again and navigate back to All Notes
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Archive and Unarchive note flow with Undo', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'arch-flow',
      title: 'Note to Archive',
      content: 'Archiving flow test',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Note to Archive'), findsOneWidget);

    // Long press note to open context menu
    await tester.longPress(find.text('Note to Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive note'), findsOneWidget);
    await tester.tap(find.text('Archive note'));
    await tester.pumpAndSettle();

    // Disappeared from All Notes, SnackBar appeared
    expect(find.text('Note to Archive'), findsNothing);
    expect(find.text('Note archived'), findsOneWidget);

    // Open drawer and navigate to Archive
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    // Note is now in Archive
    expect(find.text('Note to Archive'), findsOneWidget);

    // Long press note in Archive -> Unarchive
    await tester.longPress(find.text('Note to Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Unarchive note'), findsOneWidget);
    await tester.tap(find.text('Unarchive note'));
    await tester.pumpAndSettle();

    expect(find.text('Note to Archive'), findsNothing);

    // Back to All Notes
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Note to Archive'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Move to Trash, Restore, and Permanent Deletion flows',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'trash-flow',
      title: 'Note for Trash',
      content: 'Trash and permanent deletion test',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Note for Trash'), findsOneWidget);

    // Long press -> Move to Trash
    await tester.longPress(find.text('Note for Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Move to Trash'), findsOneWidget);
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Note for Trash'), findsNothing);
    expect(find.text('Note moved to Trash'), findsOneWidget);

    // Navigate to Trash
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Note for Trash'), findsOneWidget);

    // Long press in Trash -> Delete permanently
    await tester.longPress(find.text('Note for Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Delete permanently'), findsOneWidget);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Delete permanently?'), findsOneWidget);
    expect(
        find.text(
            'This note will be permanently deleted.\nThis action cannot be undone.'),
        findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete Permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Note for Trash'), findsNothing);
    expect(find.text('Trash is empty'), findsOneWidget);

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
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Architectural Blueprint'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing);

    // Search by tag
    await tester.enterText(find.byType(TextField), 'food');
    await tester.pump(const Duration(milliseconds: 200));
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

  testWidgets('Settings screen displays import markdown section', (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap Settings icon
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('IMPORT'), findsOneWidget);
    expect(find.text('Import Markdown Folder'), findsOneWidget);
    expect(find.text('Choose folder to import'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Pinning and unpinning notes from context sheet',
      (tester) async {
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

  testWidgets('Overflow menu toggles Markdown preview cleanly in Editor',
      (tester) async {
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

    // Tap overflow menu
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Markdown preview'), findsOneWidget);
    await tester.tap(find.text('Markdown preview'));
    await tester.pumpAndSettle();

    // TextFields are gone, rendered preview is shown
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Heading One'), findsOneWidget);

    // Tap overflow menu to switch back to edit
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Switch to edit'), findsOneWidget);
    await tester.tap(find.text('Switch to edit'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));

    await finishTest(tester);
  });

  testWidgets('Tablet layout displays split view with active note editor',
      (tester) async {
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

    // Sidebar and note list are visible
    expect(find.byType(SidebarView), findsOneWidget);
    expect(find.text('Tablet Note'), findsOneWidget);

    // Tap note in middle pane to open in detail view
    await tester.tap(find.text('Tablet Note'));
    await tester.pumpAndSettle();

    // Editor is visible on right pane simultaneously with sidebar
    expect(find.byType(EditorScreen), findsOneWidget);
    await finishTest(tester);
  });

  testWidgets('Tablet layout allows collapsing and restoring both sidebars',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'tab-collapse',
      title: 'Collapsible Note',
      content: 'Focus mode and sidebar collapse test',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap note in middle pane to open
    await tester.tap(find.text('Collapsible Note'));
    await tester.pumpAndSettle();

    // 1. Collapse Navigation Sidebar via its collapse button in header
    expect(find.byIcon(Icons.menu_open_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.menu_open_rounded).first);
    await tester.pumpAndSettle();

    // Navigation sidebar width animated to 0
    final navContainers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(navContainers.first.constraints?.maxWidth, 0.0);

    // 2. Collapse Note List Sidebar via Focus mode icon in Editor
    await tester.tap(find.byTooltip('Focus mode (hide sidebars)'));
    await tester.pumpAndSettle();

    // Both sidebars are collapsed (focus mode active)
    expect(find.byTooltip('Exit focus mode'), findsOneWidget);
    expect(find.byTooltip('Show sidebars'), findsOneWidget);

    // 3. Restore sidebars via sidebar restore button in Editor
    await tester.tap(find.byTooltip('Show sidebars'));
    await tester.pumpAndSettle();

    // Both sidebars restored
    final restoredNavContainers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(restoredNavContainers.first.constraints?.maxWidth, 280.0);

    await finishTest(tester);
  });

  testWidgets('Swiping note to the right archives the note with undo snackbar',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'swipe-arch',
      title: 'Swipe Note',
      content: 'Swipe right to archive test',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Swipe Note'), findsOneWidget);

    // Swipe right (start to end)
    await tester.drag(find.text('Swipe Note'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Note should be archived and removed from active list
    expect(find.text('Swipe Note'), findsNothing);
    expect(find.text('Note archived'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe Note'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets(
      'Archiving note shows undo snackbar which auto-dismisses after duration',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'arch-auto-dismiss',
      title: 'Auto Dismiss Note',
      content: 'Testing auto dismiss of archive snackbar',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Auto Dismiss Note'), findsOneWidget);

    // Swipe right to archive
    await tester.drag(find.text('Auto Dismiss Note'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Note archived and SnackBar with Undo is visible
    expect(find.text('Auto Dismiss Note'), findsNothing);
    expect(find.text('Note archived'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Fast-forward beyond SnackBar duration (3 seconds)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // SnackBar should now be dismissed automatically
    expect(find.text('Note archived'), findsNothing);
    expect(find.text('Undo'), findsNothing);

    await finishTest(tester);
  });

  testWidgets(
      'Creating note, pasting long text with no title, and exiting works cleanly',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap create note
    await tester.tap(find.text('Create note'));
    await tester.pumpAndSettle();

    // Paste long text in body with no title
    const longText =
        'This is the very first line of a massive document that discusses software engineering, offline architecture, and databases.\n\nParagraph 2 with lots of words and detail.\n\nParagraph 3.';
    await tester.enterText(find.byType(TextField).last, longText);
    await tester.pump(const Duration(milliseconds: 800));

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Back on note list, note exists with auto-title
    expect(find.text('Notes'), findsOneWidget);
    expect(
        find.text(
            'This is the very first line...'),
        findsOneWidget);

    // Reopen the note (opens in preview mode)
    await tester.tap(find.text('This is the very first line...'));
    await tester.pumpAndSettle();

    // Verify preview mode is active
    expect(find.byType(QuietMarkdownPreview), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    // Tap edit button to switch to edit mode
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text(longText), findsOneWidget);

    // Tap preview button next to 3-dots to switch back to preview
    await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
    await tester.pumpAndSettle();

    // Markdown preview renders without layout exception
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(QuietMarkdownPreview), findsOneWidget);

    // Exit back
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets(
      'Title field in editor automatically fills from body first line and respects manual title edits',
      (tester) async {
    setPhoneSize(tester);

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Create a new note
    await tester.tap(find.text('Create note'));
    await tester.pumpAndSettle();

    final titleFinder = find.byType(TextField).first;
    final bodyFinder = find.byType(TextField).last;

    // Initially title is empty
    expect((tester.widget(titleFinder) as TextField).controller!.text, '');

    // Type in body
    await tester.enterText(bodyFinder, 'Grocery list for the weekend\nApples and milk');
    await tester.pump();

    // Title field is automatically filled
    expect((tester.widget(titleFinder) as TextField).controller!.text,
        'Grocery list for the weekend');

    // Manually edit title
    await tester.enterText(titleFinder, 'Custom Grocery Title');
    await tester.pump();

    // Type more in body
    await tester.enterText(
        bodyFinder, 'Different first line\nApples, milk, and bread');
    await tester.pump();

    // Title remains the custom title
    expect((tester.widget(titleFinder) as TextField).controller!.text,
        'Custom Grocery Title');

    // Exit back
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Custom Grocery Title'), findsOneWidget);

    await finishTest(tester);
  });

  testWidgets('Tablet layout close button deselects active note cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2.0;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    await repository.saveNote(Note(
      id: 'tab-close',
      title: 'Tablet Note',
      content: 'Testing tablet close button',
      createdAt: now,
      updatedAt: now,
    ));

    await tester.pumpWidget(buildTestApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap note in middle pane
    await tester.tap(find.text('Tablet Note'));
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);

    // Tap close button in editor
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Note is deselected and placeholder is shown
    expect(find.text('No note selected'), findsOneWidget);
    expect(find.byType(SidebarView), findsOneWidget);

    await finishTest(tester);
  });
}
