import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/note_link_inline_menu.dart';
import 'package:quitepaper/features/editor/presentation/widgets/tag_inline_menu.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/application/tag_providers.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';

void main() {
  group('WYSIWYG and Markdown Autocomplete Integration Tests', () {
    late AppDatabase db;
    late NotesRepository repository;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createEditorApp(
      Note note, {
      EditorEditingStyle initialGlobalStyle = EditorEditingStyle.wysiwyg,
      List<Tag>? mockTags,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith(
            (ref) => EditingStyleNotifier(prefs)..state = initialGlobalStyle,
          ),
          if (mockTags != null)
            allTagsProvider.overrideWith((ref) => Stream.value(mockTags)),
        ],
        child: MaterialApp(
          home: EditorScreen(note: note),
        ),
      );
    }

    Future<void> finishTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('WYSIWYG mode displays note link overlay when typing [[', (tester) async {
      final now = DateTime.now();
      final targetNote = Note(
        id: 'target-1',
        title: 'Meeting Notes',
        content: 'Action items',
        createdAt: now,
        updatedAt: now,
        tags: const ['work'],
      );
      await repository.saveNote(targetNote);

      final currentNote = Note(
        id: 'current-1',
        title: 'Project Alpha',
        content: 'Refer to ',
        createdAt: now,
        updatedAt: now,
        tags: const [],
      );
      await repository.saveNote(currentNote);

      await tester.pumpWidget(createEditorApp(
        currentNote,
        initialGlobalStyle: EditorEditingStyle.wysiwyg,
      ));
      await tester.pumpAndSettle();

      // Find the visual document editable block TextField containing "Refer to "
      final blockField = find.widgetWithText(TextField, 'Refer to ');
      expect(blockField, findsOneWidget);

      await tester.tap(blockField);
      await tester.pumpAndSettle();

      // Enter 'Refer to [[Meet' into the block
      await tester.enterText(blockField, 'Refer to [[Meet');
      await tester.pumpAndSettle();

      // Verify NoteLinkInlineMenu appears
      expect(find.byType(NoteLinkInlineMenu), findsOneWidget);
      expect(find.text('LINK TO NOTE'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsOneWidget);

      // Tap on the target note
      await tester.tap(find.text('Meeting Notes'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // The overlay should dismiss after selection
      expect(find.byType(NoteLinkInlineMenu), findsNothing);

      // The document content should now contain the note link
      final updatedNote = await repository.getNoteById('current-1');
      expect(updatedNote?.content, contains('Meeting Notes'));

      await finishTest(tester);
    });

    testWidgets('WYSIWYG mode tag autocomplete: # alone shows nothing, #a shows tag menu', (tester) async {
      final now = DateTime.now();
      final currentNote = Note(
        id: 'current-tag-1',
        title: 'Ideas',
        content: 'Start idea ',
        createdAt: now,
        updatedAt: now,
        tags: const [],
      );
      await repository.saveNote(currentNote);

      final availableTags = [
        Tag(
          id: 'tag-1',
          name: 'architecture',
          color: 'blue',
          createdAt: now,
          updatedAt: now,
          noteCount: 5,
        ),
        Tag(
          id: 'tag-2',
          name: 'action',
          color: 'teal',
          createdAt: now,
          updatedAt: now,
          noteCount: 2,
        ),
      ];

      await tester.pumpWidget(createEditorApp(
        currentNote,
        initialGlobalStyle: EditorEditingStyle.wysiwyg,
        mockTags: availableTags,
      ));
      await tester.pumpAndSettle();

      final blockField = find.widgetWithText(TextField, 'Start idea ');
      expect(blockField, findsOneWidget);

      await tester.tap(blockField);
      await tester.pumpAndSettle();

      // 1. User types '#' alone: nothing should appear
      await tester.enterText(blockField, 'Start idea #');
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsNothing);

      // 2. User types any character immediately after '#': e.g. '#a'
      final blockWithHash = find.widgetWithText(TextField, 'Start idea #');
      await tester.enterText(blockWithHash, 'Start idea #a');
      await tester.pumpAndSettle();

      // Tag overlay appears with candidates
      expect(find.byType(TagInlineMenu), findsOneWidget);
      expect(find.text('TAGS'), findsOneWidget);
      expect(find.text('#architecture'), findsOneWidget);
      expect(find.text('#action'), findsOneWidget);

      // 3. User selects a tag from the list
      await tester.tap(find.text('#architecture'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Menu closes
      expect(find.byType(TagInlineMenu), findsNothing);

      // Note content in repository contains inserted #architecture with trailing space
      final updatedNote = await repository.getNoteById('current-tag-1');
      expect(updatedNote?.content, contains('#architecture '));

      await finishTest(tester);
    });

    testWidgets('Tag autocomplete in Markdown mode allows selection with trailing space', (tester) async {
      final now = DateTime.now();
      final currentNote = Note(
        id: 'current-md-1',
        title: 'Notes Today',
        content: 'Today was productive ',
        createdAt: now,
        updatedAt: now,
        tags: const [],
      );
      await repository.saveNote(currentNote);

      final availableTags = [
        Tag(
          id: 'tag-3',
          name: 'journal',
          color: 'orange',
          createdAt: now,
          updatedAt: now,
          noteCount: 10,
        ),
      ];

      await tester.pumpWidget(createEditorApp(
        currentNote,
        initialGlobalStyle: EditorEditingStyle.markdown,
        mockTags: availableTags,
      ));
      await tester.pumpAndSettle();

      // Find the main markdown TextField
      final editorField = find.widgetWithText(TextField, 'Today was productive ');
      expect(editorField, findsOneWidget);

      await tester.tap(editorField);
      await tester.pumpAndSettle();

      // Type '#j'
      await tester.enterText(editorField, 'Today was productive #j');
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsOneWidget);
      expect(find.text('#journal'), findsOneWidget);

      // Tap '#journal'
      await tester.tap(find.text('#journal'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsNothing);

      // Verified text has #journal with trailing space
      final updatedNote = await repository.getNoteById('current-md-1');
      expect(updatedNote?.content, contains('#journal '));

      await finishTest(tester);
    });

    testWidgets('Tag autocomplete in WYSIWYG mode supports Escape dismissal', (tester) async {
      final now = DateTime.now();
      final currentNote = Note(
        id: 'current-key-1',
        title: 'Tasks',
        content: 'Task item ',
        createdAt: now,
        updatedAt: now,
        tags: const [],
      );
      await repository.saveNote(currentNote);

      final availableTags = [
        Tag(
          id: 'tag-1',
          name: 'alpha',
          color: 'blue',
          createdAt: now,
          updatedAt: now,
          noteCount: 5,
        ),
        Tag(
          id: 'tag-2',
          name: 'apex',
          color: 'teal',
          createdAt: now,
          updatedAt: now,
          noteCount: 2,
        ),
      ];

      await tester.pumpWidget(createEditorApp(
        currentNote,
        initialGlobalStyle: EditorEditingStyle.wysiwyg,
        mockTags: availableTags,
      ));
      await tester.pumpAndSettle();

      final blockField = find.widgetWithText(TextField, 'Task item ');
      await tester.tap(blockField);
      await tester.pumpAndSettle();

      // Enter '#a'
      await tester.enterText(blockField, 'Task item #a');
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsOneWidget);

      // Press Escape to dismiss
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsNothing);

      await finishTest(tester);
    });
  });
}
