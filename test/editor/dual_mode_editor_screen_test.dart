import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  group('Dual-Mode EditorScreen & Frontmatter Integration Tests', () {
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

    Widget createEditorApp(Note note, {EditorEditingStyle initialGlobalStyle = EditorEditingStyle.wysiwyg}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith((ref) => EditingStyleNotifier(prefs)..state = initialGlobalStyle),
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

    testWidgets('WYSIWYG mode displays FrontmatterPropertiesSection and hides raw frontmatter from body', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-wysiwyg-1',
        title: 'Project Plan',
        content: '---\ntitle: Project Plan\nauthor: Diana\ntags: [mobile]\n---\n# Heading\nBody text here.',
        createdAt: now,
        updatedAt: now,
        tags: ['mobile'],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();

      // Properties section is displayed expanded by default
      expect(find.byType(FrontmatterPropertiesSection), findsOneWidget);
      expect(find.text('PROPERTIES'), findsOneWidget);
      expect(find.text('Author'), findsOneWidget);
      expect(find.text('Diana'), findsOneWidget);

      // Main MarkdownEditor is rendered in WYSIWYG mode without raw YAML
      expect(find.byType(MarkdownEditor), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Heading'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Body text here.'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('overflow menu toggles Edit Markdown and switches to Markdown mode', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-toggle-1',
        title: 'Notes',
        content: '---\ntitle: Notes\nauthor: Alex\n---\n# Content\nParagraph.',
        createdAt: now,
        updatedAt: now,
        tags: [],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();

      // Open overflow menu
      final moreButton = find.byTooltip('More options');
      expect(moreButton, findsOneWidget);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // In WYSIWYG mode, overflow menu has "Edit Markdown" option
      final editMarkdownTile = find.text('Edit Markdown');
      expect(editMarkdownTile, findsOneWidget);

      // Tap "Edit Markdown"
      await tester.tap(editMarkdownTile);
      await tester.pumpAndSettle();

      // In Markdown mode:
      // 1. Properties section is no longer shown
      expect(find.byType(FrontmatterPropertiesSection), findsNothing);

      // 2. Raw Markdown and frontmatter are displayed in the text editor
      expect(find.textContaining('---'), findsWidgets);
      expect(find.textContaining('# Content'), findsOneWidget);

      // Open overflow menu again
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // In Markdown mode, overflow menu has "Edit Visually" option
      final editVisuallyTile = find.text('Edit Visually');
      expect(editVisuallyTile, findsOneWidget);

      // Tap "Edit Visually" to switch back to WYSIWYG
      await tester.tap(editVisuallyTile);
      await tester.pumpAndSettle();

      expect(find.byType(FrontmatterPropertiesSection), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('editing visual title synchronizes with frontmatter title', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-sync-title-1',
        title: 'Initial Title',
        content: '---\ntitle: Initial Title\nauthor: Jane\n---\n# Main\nText.',
        createdAt: now,
        updatedAt: now,
        tags: [],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();

      final titleField = find.widgetWithText(TextField, 'Initial Title');
      expect(titleField, findsOneWidget);

      // Edit visual title
      await tester.enterText(titleField, 'Revised Title');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      // Verify the saved/current content in repository has updated title: in frontmatter
      final savedNote = await repository.getNoteById('note-sync-title-1');
      expect(savedNote, isNotNull);
      expect(savedNote!.content, contains('title: Revised Title'));

      await finishTest(tester);
    });
  });
}
