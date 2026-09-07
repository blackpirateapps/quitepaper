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
  group('WYSIWYG Backspace Autocomplete Tests', () {
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
      List<Tag>? mockTags,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith(
            (ref) => EditingStyleNotifier(prefs)..state = EditorEditingStyle.wysiwyg,
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

    testWidgets('Typing [[ and pressing backspace removes one bracket and keeps cursor after [', (tester) async {
      final now = DateTime.now();
      final targetNote = Note(
        id: 'target-1',
        title: 'Project Roadmap',
        content: 'Milestones',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(targetNote);

      final currentNote = Note(
        id: 'test-1',
        title: 'Note 1',
        content: 'Refer to ',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(currentNote);

      await tester.pumpWidget(createEditorApp(currentNote));
      await tester.pumpAndSettle();

      final blockField = find.byType(TextField).last;
      await tester.tap(blockField);
      await tester.pumpAndSettle();

      // Step 1: Type [
      await tester.enterText(blockField, 'Refer to [');
      await tester.pumpAndSettle();

      // Step 2: Type second [ -> popup opens
      await tester.enterText(blockField, 'Refer to [[');
      await tester.pumpAndSettle();

      expect(find.byType(NoteLinkInlineMenu), findsOneWidget);

      // Step 3: Press backspace immediately -> removes one bracket, leaves [, cursor after [
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.controller?.text, equals('Refer to ['));
      expect(textField.controller?.selection.baseOffset, equals(10));
      expect(find.byType(NoteLinkInlineMenu), findsNothing);

      await finishTest(tester);
    });

    testWidgets('Typing #a and pressing backspace leaves # with cursor after #', (tester) async {
      final now = DateTime.now();
      final currentNote = Note(
        id: 'test-2',
        title: 'Note 2',
        content: 'Hello ',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(currentNote);

      final availableTags = [
        Tag(
          id: 't-1',
          name: 'apple',
          color: 'red',
          createdAt: now,
          updatedAt: now,
          noteCount: 1,
        ),
      ];

      await tester.pumpWidget(createEditorApp(currentNote, mockTags: availableTags));
      await tester.pumpAndSettle();

      final blockField = find.byType(TextField).last;
      await tester.tap(blockField);
      await tester.pumpAndSettle();

      // Step 1: Type #
      await tester.enterText(blockField, 'Hello #');
      await tester.pumpAndSettle();

      // Step 2: Type a -> popup opens
      await tester.enterText(blockField, 'Hello #a');
      await tester.pumpAndSettle();

      expect(find.byType(TagInlineMenu), findsOneWidget);

      // Step 3: Press backspace -> deletes 'a' and leaves # with cursor after #
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.controller?.text, equals('Hello #'));
      expect(textField.controller?.selection.baseOffset, equals(7));
      expect(find.byType(TagInlineMenu), findsNothing);

      await finishTest(tester);
    });
  });
}
