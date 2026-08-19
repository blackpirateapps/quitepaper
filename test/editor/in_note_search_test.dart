import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/in_note_search_bar.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final styles = MarkdownStyles.fromColors(AppColors.light);

  group('MarkdownParser In-Note Search Highlighting', () {
    test('buildTextSpan highlights search query matches with 1:1 text preservation', () {
      const source = 'Quiet Paper makes writing quiet and peaceful.';
      final span = MarkdownParser.buildTextSpan(
        text: source,
        styles: styles,
        searchQuery: 'quiet',
        activeSearchRange: const TextRange(start: 0, end: 5),
      );

      // Verify exact 1:1 text preservation
      expect(span.toPlainText(), equals(source));

      final children = span.children!.whereType<TextSpan>().toList();
      // First match "Quiet" (active)
      final activeMatch = children.firstWhere((s) => s.text == 'Quiet');
      expect(activeMatch.style?.backgroundColor, equals(styles.activeSearchHighlight.backgroundColor));
      expect(activeMatch.style?.fontWeight, equals(FontWeight.w600));

      // Second match "quiet" (non-active)
      final secondaryMatch = children.firstWhere((s) => s.text == 'quiet');
      expect(secondaryMatch.style?.backgroundColor, equals(styles.searchHighlight.backgroundColor));
    });

    test('MarkdownEditingController setSearchHighlight notifies listeners', () {
      final controller = MarkdownEditingController(text: 'Hello World! Hello Again!');
      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.setSearchHighlight(
        query: 'Hello',
        activeRange: const TextRange(start: 0, end: 5),
      );

      expect(notified, isTrue);
      expect(controller.searchQuery, equals('Hello'));
      expect(controller.activeSearchRange, equals(const TextRange(start: 0, end: 5)));
    });
  });

  group('InNoteSearchBar Widget Unit Tests', () {
    testWidgets('renders search field, match counter, navigation buttons, and replace options',
        (tester) async {
      final searchController = TextEditingController(text: 'peace');
      final searchFocusNode = FocusNode();
      final replaceController = TextEditingController(text: 'calm');
      final replaceFocusNode = FocusNode();

      var prevTapped = false;
      var nextTapped = false;
      var closeTapped = false;
      var toggleReplaceTapped = false;
      var replaceTapped = false;
      var replaceAllTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InNoteSearchBar(
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              onClose: () => closeTapped = true,
              onPreviousMatch: () => prevTapped = true,
              onNextMatch: () => nextTapped = true,
              matchCount: 3,
              currentMatchIndex: 0,
              showReplace: true,
              onToggleReplace: () => toggleReplaceTapped = true,
              replaceController: replaceController,
              replaceFocusNode: replaceFocusNode,
              onReplace: () => replaceTapped = true,
              onReplaceAll: () => replaceAllTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('peace'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Replace with...'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Tap Next
      await tester.tap(find.byTooltip('Next match'));
      expect(nextTapped, isTrue);

      // Tap Previous
      await tester.tap(find.byTooltip('Previous match'));
      expect(prevTapped, isTrue);

      // Tap Replace
      await tester.tap(find.text('Replace'));
      expect(replaceTapped, isTrue);

      // Tap Replace All
      await tester.tap(find.text('All'));
      expect(replaceAllTapped, isTrue);

      // Tap Toggle Replace
      await tester.tap(find.byTooltip('Hide replace'));
      expect(toggleReplaceTapped, isTrue);

      // Tap Close
      await tester.tap(find.byTooltip('Close search'));
      expect(closeTapped, isTrue);
    });
  });

  group('EditorScreen In-Note Search & Replace Integration', () {
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

    Widget createEditorApp(Note note, {bool initialPreview = false}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: EditorScreen(
            note: note,
            initialPreviewMode: initialPreview,
          ),
        ),
      );
    }

    testWidgets('triggers in-note search from AppBar action, navigates matches, and highlights',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'search-test-1',
        title: 'Editorial Design',
        content: 'Bear style editorial writing is calm. Editorial focus is essential.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Search bar initially closed
      expect(find.byType(InNoteSearchBar), findsNothing);

      // Tap search icon in AppBar
      await tester.tap(find.byTooltip('Find in note'));
      await tester.pumpAndSettle();

      // Search bar is now visible
      expect(find.byType(InNoteSearchBar), findsOneWidget);

      // Enter search query "editorial"
      await tester.enterText(find.widgetWithText(TextField, 'Find in note...'), 'editorial');
      await tester.pumpAndSettle();

      // Match count is 2 (case-insensitive matches "editorial" and "Editorial")
      expect(find.text('1/2'), findsOneWidget);

      // Navigate to next match
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      // Next again wraps to 1
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      // Previous wraps to 2
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      // Close search
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(InNoteSearchBar), findsNothing);
    });

    testWidgets('replace and replace all functionality updates content and recalculates matches',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'replace-test-1',
        title: 'Apple Banana Fruit',
        content: 'I love apple pie and apple juice.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      // Open search with replace via shortcut or button
      await tester.tap(find.byTooltip('Find in note'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Find in note...'), 'apple');
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      // Toggle Replace row
      await tester.tap(find.byTooltip('Show replace'));
      await tester.pumpAndSettle();
      expect(find.text('Replace with...'), findsOneWidget);

      // Enter replace text "orange"
      await tester.enterText(find.widgetWithText(TextField, 'Replace with...'), 'orange');
      await tester.pumpAndSettle();

      // Replace current match
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      // 1 match remaining
      expect(find.text('1/1'), findsOneWidget);

      // Replace All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Check text is updated in editor
      expect(find.text('I love orange pie and orange juice.'), findsOneWidget);
      expect(find.text('0/0'), findsOneWidget);
    });

    testWidgets('pulling / swiping down at top of editor reveals in-note search',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'swipe-down-test',
        title: 'Swipe Down Search',
        content: 'First line of writing\nSecond line\nThird line',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();

      expect(find.byType(InNoteSearchBar), findsNothing);

      // Drag down in editor area
      await tester.drag(find.text('Swipe Down Search'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Search bar should now appear
      expect(find.byType(InNoteSearchBar), findsOneWidget);
    });

    testWidgets('in-note search works in Markdown Preview mode with search query highlighting',
        (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'preview-search-test',
        title: 'Preview Highlight Test',
        content: '# Header\nThis note contains sample text for search test.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialPreview: true));
      await tester.pumpAndSettle();

      expect(find.byType(QuietMarkdownPreview), findsOneWidget);

      // Trigger search via AppBar
      await tester.tap(find.byTooltip('Find in note'));
      await tester.pumpAndSettle();

      expect(find.byType(InNoteSearchBar), findsOneWidget);

      // Enter query
      await tester.enterText(find.widgetWithText(TextField, 'Find in note...'), 'sample');
      await tester.pumpAndSettle();

      expect(find.text('1/1'), findsOneWidget);
    });
  });
}
