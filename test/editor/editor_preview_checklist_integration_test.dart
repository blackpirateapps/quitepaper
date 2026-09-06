import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/default_settings_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/domain/default_settings.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorScreen Preview Checklist Integration Tests', () {
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
      bool initialPreviewMode = true,
      DefaultSettings defaultSettings = const DefaultSettings(),
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith(
            (ref) => EditingStyleNotifier(prefs)..state = EditorEditingStyle.markdown,
          ),
          defaultSettingsProvider.overrideWith(
            (ref) => DefaultSettingsNotifier(prefs)..state = defaultSettings,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: EditorScreen(
            note: note,
            initialPreviewMode: initialPreviewMode,
          ),
        ),
      );
    }

    Future<void> finishTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('Tapping checkbox in preview mode toggles state, updates note content, and updates Phosphor icon', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-preview-check-1',
        title: 'Checklist Note',
        content: '# Checklist\n\n- [ ] Ship release build\n- [x] Write tests',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialPreviewMode: true));
      await tester.pumpAndSettle();

      // In preview mode: one unchecked, one checked
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      // Tap the unchecked item
      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      // Both should now be checked
      expect(find.byIcon(PhosphorIconsRegular.square), findsNothing);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNWidgets(2));

      // Switch back to edit mode to verify markdown text in the editor
      final editToggleBtn = find.byTooltip('Edit note');
      expect(editToggleBtn, findsOneWidget);
      await tester.tap(editToggleBtn);
      await tester.pumpAndSettle();

      // Verify the content controller contains `- [x] Ship release build`
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
        textFields.any((tf) =>
            tf.controller?.text.contains('- [x] Ship release build') == true),
        isTrue,
      );

      await finishTest(tester);
    });

    testWidgets('Undo action reverts checkbox toggle performed in preview mode', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-preview-undo-1',
        title: 'Undo Checklist Note',
        content: '- [ ] Item to undo',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(note, initialPreviewMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);

      // Tap to check
      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      // Tap Undo in app bar
      final undoBtn = find.byTooltip('Undo');
      if (undoBtn.evaluate().isNotEmpty) {
        await tester.tap(undoBtn);
        await tester.pumpAndSettle();

        // Should be reverted back to unchecked
        expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
        expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);
      }

      await finishTest(tester);
    });

    testWidgets('When interactiveChecklistsInPreview is false, tapping checkbox does not toggle', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-preview-disabled-1',
        title: 'Disabled Preview Checklist',
        content: '- [ ] Should stay unchecked',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(createEditorApp(
        note,
        initialPreviewMode: true,
        defaultSettings: const DefaultSettings(interactiveChecklistsInPreview: false),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);

      // Tap the checkbox
      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      // Should still be unchecked
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);

      await finishTest(tester);
    });
  });
}
