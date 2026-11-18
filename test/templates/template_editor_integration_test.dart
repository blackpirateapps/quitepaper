import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/editor_provider.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/templates/application/template_providers.dart';
import 'package:quitepaper/features/templates/application/template_service.dart';
import 'package:quitepaper/features/templates/data/template_repository.dart';
import 'package:quitepaper/features/templates/presentation/widgets/template_dialogs.dart';
import 'template_domain_test.dart' show richFixture;
import 'template_save_race_test.dart' show GatedNotes;

void main() {
  late AppDatabase db;
  late DriftNotesRepository notes;
  late TemplateRepository repo;
  late TemplateService service;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    notes = DriftNotesRepository(db);
    repo = TemplateRepository(db);
    service = TemplateService(repository: repo, notes: notes);
  });
  tearDown(() => db.close());
  Widget app(Note note, EditorEditingStyle style) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(notes),
      templateServiceProvider.overrideWithValue(service),
      sharedPreferencesProvider.overrideWithValue(prefs),
      editorEditingStyleProvider.overrideWith(
        (ref) => EditingStyleNotifier(prefs)..state = style,
      ),
    ],
    child: MaterialApp(home: EditorScreen(note: note)),
  );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final fail in [false, true]) {
    testWidgets('route Back awaits queued save; failure=$fail', (tester) async {
      final note = Note(
        id: 'exit-source',
        title: 'Source',
        content: 'Original',
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
      );
      final gated = GatedNotes(db);
      await gated.saveNote(note);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(gated),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditorScreen(note: note),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditorScreen)),
      );
      final notifier = container.read(
        editorProviderFamily(EditorParams(note)).notifier,
      );
      gated.gate();
      notifier.updateContent('First');
      final saving = notifier.saveNow();
      await tester.pump();
      expect(gated.entered!.isCompleted, true);
      notifier.updateContent('Latest irreplaceable edit');
      gated.fail = fail;
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(EditorScreen), findsOneWidget);
      gated.release!.complete();
      await settle(tester);
      await saving;
      if (fail) {
        expect(find.byType(EditorScreen), findsOneWidget);
        expect(notifier.state.isDirty, true);
        gated.fail = false;
        await tester.binding.handlePopRoute();
        await settle(tester);
      }
      expect(find.byType(EditorScreen), findsNothing);
      expect(
        (await notes.getNoteById(note.id))!.content,
        'Latest irreplaceable edit',
      );
      await finish(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final style in EditorEditingStyle.values) {
    for (final rich in [false, true]) {
      testWidgets(
        'instantiated ${rich ? 'rich JSON' : 'Markdown'} opens in ${style.name} without mutating canonical storage',
        (tester) async {
          final content = rich
              ? jsonEncode(
                  const RichDocumentParser().parse(richFixture).toJson(),
                )
              : richFixture;
          final now = DateTime.utc(2026);
          final source = Note(
            id: 'source',
            title: 'Source',
            content: content,
            createdAt: now,
            updatedAt: now,
          );
          await notes.saveNote(source);
          final template = (await tester.runAsync(
            () => service.saveNoteAsTemplate(
              noteId: source.id,
              name: 'Structured',
              flush: () async {},
            ),
          ))!;
          final note = (await tester.runAsync(
            () => service.instantiate(template.id),
          ))!;
          await tester.pumpWidget(app(note, style));
          await settle(tester);
          expect(tester.takeException(), isNull);
          if (style == EditorEditingStyle.superEditor) {
            expect(find.byType(QuietSuperEditor), findsOneWidget);
            expect(
              tester
                  .widget<QuietSuperEditor>(find.byType(QuietSuperEditor))
                  .initialMarkdown,
              isNot(contains('quietpaper:rich_document')),
            );
          } else if (style == EditorEditingStyle.wysiwyg) {
            expect(find.byType(RichTextEditor), findsWidgets);
          } else {
            expect(
              tester
                  .widget<MarkdownEditor>(find.byType(MarkdownEditor))
                  .controller
                  .text,
              isNot(contains('quietpaper:rich_document')),
            );
          }
          expect((await notes.getNoteById(note.id))!.content, content);
          expect((await repo.getUserTemplate(template.id))!.content, content);
          await finish(tester);
          expect((await notes.getNoteById(note.id))!.content, content);
        },
      );
    }
  }
  testWidgets(
    'save editor snapshot, instantiate, edit new note; source and template stay independent',
    (tester) async {
      final now = DateTime.utc(2026);
      final source = Note(
        id: 'source',
        title: 'Source',
        content: 'Original',
        createdAt: now,
        updatedAt: now,
      );
      await notes.saveNote(source);
      await tester.pumpWidget(app(source, EditorEditingStyle.wysiwyg));
      await settle(tester);
      final field = find
          .descendant(
            of: find.byType(RichTextEditor),
            matching: find.byType(EditableText),
          )
          .first;
      await tester.enterText(field, 'Newest formatted content');
      // Menu interaction intentionally starts before the 50 ms visual debounce.
      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      expect(find.text('Save as Template'), findsOneWidget);
      await tester.tap(find.text('Save as Template'));
      await settle(tester);
      expect(find.byType(TemplateNameDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(TemplateNameDialog),
          matching: find.byType(TextField),
        ),
        'Reusable',
      );
      await tester.tap(find.text('Save Template'));
      await settle(tester);
      final template = (await repo.getUserTemplates()).single;
      expect(template.content, contains('Newest formatted content'));
      expect(find.text('Template saved'), findsOneWidget);
      final preserved = await notes.getNoteById(source.id);
      await finish(tester);
      final newNote = (await tester.runAsync(
        () => service.instantiate(template.id),
      ))!;
      await tester.pumpWidget(app(newNote, EditorEditingStyle.wysiwyg));
      await settle(tester);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(RichTextEditor),
              matching: find.byType(EditableText),
            )
            .first,
        'Changed new note',
      );
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(
        (await notes.getNoteById(newNote.id))!.content,
        contains('Changed new note'),
      );
      expect(await notes.getNoteById(source.id), preserved);
      expect(
        (await repo.getUserTemplate(template.id))!.content,
        template.content,
      );
      await finish(tester);
    },
  );
  for (final kind in [
    'trash',
    'journal',
    'protected',
    'unpersisted',
    'readOnly',
    'unlockedProtected',
  ]) {
    testWidgets('Save as Template hidden for $kind source', (tester) async {
      final now = DateTime.utc(2026);
      final note = Note(
        id: 'source',
        title: 'Source',
        content: kind == 'protected'
            ? '<!-- quiet-paper-encrypted-note-v1: data -->'
            : 'Body',
        isTrashed: kind == 'trash',
        journalDate: kind == 'journal' ? '2026-11-18' : null,
        createdAt: now,
        updatedAt: now,
      );
      if (kind != 'unpersisted') await notes.saveNote(note);
      await tester.pumpWidget(app(note, EditorEditingStyle.markdown));
      await settle(tester);
      final context = tester.element(find.byType(EditorScreen));
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(
        editorProviderFamily(EditorParams(note)).notifier,
      );
      if (kind == 'readOnly') notifier.setReadOnly(true);
      if (kind == 'unlockedProtected') {
        await tester.runAsync(
          () => notifier.setPasswordProtection(password: 'secret-password'),
        );
      }
      await tester.pumpAndSettle();
      if (find.byTooltip('More options').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('More options'));
        await settle(tester);
      }
      expect(find.text('Save as Template'), findsNothing);
      await finish(tester);
    });
  }
}
