import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/table/table_insert_dialog.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EditorScreen Overflow Menu & Top Bar Streamlining', () {
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
      await tester.pump(const Duration(milliseconds: 1000));
    }

    Widget createEditorApp(Note note, {bool initialPreview = false, Key? key}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: EditorScreen(
            key: key,
            note: note,
            initialPreviewMode: initialPreview,
          ),
        ),
      );
    }

    testWidgets('Editor AppBar does NOT contain search icon in edit mode or preview mode',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'no-search-icon-1',
        title: 'Calm Note',
        content: 'Distraction-free editorial writing.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      // 1. Edit mode
      await tester.pumpWidget(createEditorApp(note, initialPreview: false, key: const ValueKey('edit')));
      await tester.pumpAndSettle();

      expect(find.widgetWithIcon(QuietIconButton, Icons.search_rounded), findsNothing);
      expect(find.byTooltip('Find in note'), findsNothing);

      // 2. Preview mode
      await tester.pumpWidget(createEditorApp(note, initialPreview: true, key: const ValueKey('preview')));
      await tester.pumpAndSettle();

      expect(find.widgetWithIcon(QuietIconButton, Icons.search_rounded), findsNothing);
      expect(find.byTooltip('Find in note'), findsNothing);

      await finishTest(tester);
    });

    testWidgets(
        '3-dot menu displays consolidated "Insert" option with Phosphor icons and no redundant preview item',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'menu-test-1',
        title: 'Menu Streamline Note',
        content: 'Testing 3-dot overflow menu simplification.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Open 3-dot menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Consolidated "Insert" option exists with Phosphor icons
      expect(find.text('Insert'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Insert'),
          matching: find.byIcon(PhosphorIconsRegular.plusCircle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Insert'),
          matching: find.byIcon(PhosphorIconsRegular.caretRight),
        ),
        findsOneWidget,
      );

      // Redundant Markdown preview toggle is gone
      expect(find.text('Markdown preview'), findsNothing);
      expect(find.text('Switch to edit'), findsNothing);

      // Submenu options are NOT visible in main menu
      expect(find.text('Insert image'), findsNothing);
      expect(find.text('Scan document'), findsNothing);
      expect(find.text('Insert table'), findsNothing);
      expect(find.text('Attach file'), findsNothing);

      // Other core menu items remain accessible
      expect(find.text('Find in note'), findsOneWidget);
      expect(find.text('Export note'), findsOneWidget);
      expect(find.text('Version history'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets(
        'Tapping "Insert" transitions to submenu with 4 Phosphor-icon options and back button returns to main menu',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'menu-test-2',
        title: 'Submenu Navigation Note',
        content: 'Testing submenu drilldown and back transition.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Open 3-dot menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Tap "Insert"
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      // Submenu view is displayed with header and back button
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);

      // All 4 insertion options are visible inside ListTiles with Phosphor icons
      final insertImageTile = find.widgetWithText(ListTile, 'Insert image');
      expect(insertImageTile, findsOneWidget);
      expect(
        find.descendant(of: insertImageTile, matching: find.byIcon(PhosphorIconsRegular.image)),
        findsOneWidget,
      );

      final scanDocTile = find.widgetWithText(ListTile, 'Scan document');
      expect(scanDocTile, findsOneWidget);
      expect(
        find.descendant(of: scanDocTile, matching: find.byIcon(PhosphorIconsRegular.scan)),
        findsOneWidget,
      );

      final insertTableTile = find.widgetWithText(ListTile, 'Insert table');
      expect(insertTableTile, findsOneWidget);
      expect(
        find.descendant(of: insertTableTile, matching: find.byIcon(PhosphorIconsRegular.table)),
        findsOneWidget,
      );

      final attachFileTile = find.widgetWithText(ListTile, 'Attach file');
      expect(attachFileTile, findsOneWidget);
      expect(
        find.descendant(of: attachFileTile, matching: find.byIcon(PhosphorIconsRegular.paperclip)),
        findsOneWidget,
      );

      // Main menu items are no longer visible in submenu view
      expect(find.text('Find in note'), findsNothing);
      expect(find.text('Export note'), findsNothing);

      // Tap Back button
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Main menu is restored
      expect(find.text('Insert'), findsOneWidget);
      expect(find.text('Find in note'), findsOneWidget);
      expect(find.text('Insert image'), findsNothing);

      await finishTest(tester);
    });

    testWidgets('Tapping "Insert table" from submenu closes sheet and opens TableInsertDialog',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'menu-test-3',
        title: 'Table Action Note',
        content: 'Testing table dialog opening.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Open 3-dot menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Drill down into "Insert"
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      // Tap "Insert table"
      await tester.tap(find.text('Insert table'));
      await tester.pumpAndSettle();

      // Bottom sheet is dismissed and TableInsertDialog is presented
      expect(find.byType(TableInsertDialog), findsOneWidget);
      expect(find.text('Insert Table'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Read-only note does not display "Insert" in 3-dot menu',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'menu-test-4',
        title: 'Locked Note',
        content: 'Read only contents.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Lock note via 3-dot menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lock note (Read-only)'));
      await tester.pumpAndSettle();

      // Open 3-dot menu again
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // "Insert" is not present for read-only notes
      expect(find.text('Insert'), findsNothing);
      expect(find.byIcon(PhosphorIconsRegular.plusCircle), findsNothing);

      await finishTest(tester);
    });
  });
}
