import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/email_import/application/email_import_gateway.dart';
import 'package:quitepaper/features/email_import/application/email_input.dart';
import 'package:quitepaper/features/email_import/presentation/email_import_launcher.dart';
import 'email_import_screen_test.dart' show FakeEmailGateway;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/email_import/application/email_editor_bridge.dart';
import 'package:quitepaper/features/email_import/domain/note_import_source.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

class _NoSync implements SyncEngine {
  @override
  void triggerSyncDebounced() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final style in EditorEditingStyle.values) {
    testWidgets('confirmed append updates live $style without stale autosave', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final repo = DriftNotesRepository(db);
      final note = Note(
        id: 'editor-email',
        title: 'Existing title',
        content: 'Existing **bold**',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await repo.saveNote(note);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repo),
            sharedPreferencesProvider.overrideWithValue(prefs),
            editorEditingStyleProvider.overrideWith(
              (ref) => EditingStyleNotifier(prefs)..state = style,
            ),
          ],
          child: MaterialApp(home: EditorScreen(note: note)),
        ),
      );
      await tester.pumpAndSettle();
      final bridge = EmailEditorBridge.active!;
      final current = (await bridge.prepare())!;
      String? firstId;
      DocumentSelection? selection;
      if (style == EditorEditingStyle.superEditor) {
        final controller = tester
            .widget<QuietSuperEditor>(find.byType(QuietSuperEditor))
            .controller!;
        firstId = controller.editor!.document.first.id;
        controller.composer!.setSelectionWithReason(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: firstId,
              nodePosition: const TextNodePosition(offset: 3),
            ),
          ),
        );
        selection = controller.composer!.selection;
      }
      const addition =
          '\n\n---\n\n# Imported\n\n## Email Details\n\nFrom: Sender\n\n---\n\nEmail body';
      var content = '${current.content}$addition';
      if (current.isRichText) {
        final doc = RichDocument.fromJson(
          jsonDecode(current.content) as Map<String, dynamic>,
        );
        content = jsonEncode(
          doc
              .copyWith(
                blocks: [
                  ...doc.blocks,
                  ...const RichDocumentParser().parse(addition).blocks,
                ],
              )
              .toJson(),
        );
      }
      final source = NoteImportSource(
        fingerprint: 'email',
        importedAt: DateTime.utc(2026),
        subject: 'Imported',
        sender: 'Sender',
      );
      final saved = current.copyWith(
        content: content,
        updatedAt: DateTime.now(),
        importSources: [source],
      );
      await repo.saveNote(saved);
      bridge.accept(saved);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 900));
      final loaded = (await repo.getNoteById(note.id))!;
      expect(loaded.markdownContent, contains('Existing **bold**'));
      expect(loaded.markdownContent, contains('Email body'));
      expect(loaded.importSources, [source]);
      if (style == EditorEditingStyle.superEditor) {
        final controller = tester
            .widget<QuietSuperEditor>(find.byType(QuietSuperEditor))
            .controller!;
        expect(controller.editor!.document.first.id, firstId);
        expect(controller.composer!.selection, selection);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      await db.close();
      expect(EmailEditorBridge.active, isNull);
    });
  }
  testWidgets(
    'email metadata, structure and references survive Visual to Markdown to Super and reopen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final repo = DriftNotesRepository(db);
      final source = NoteImportSource(
        fingerprint: 'roundtrip',
        importedAt: DateTime.utc(2026),
        subject: 'Email',
        sender: 'Sender',
      );
      final note = Note(
        id: 'roundtrip',
        title: 'Email',
        content:
            '## Email Details\n\nFrom: Sender\n\n---\n\nParagraph **bold**\n\n- First\n- Second\n\n> Reply\n\n| Item | Value |\n| --- | --- |\n| Total | 12 |\n\n[Site](https://example.test)\n\n![Local](qp://asset/11111111-1111-4111-8111-111111111111)\n\n[Original email (.eml)](qp://asset/22222222-2222-4222-8222-222222222222)',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        importSources: [source],
      );
      await repo.saveNote(note);
      Widget app(Note value, EditorEditingStyle style) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith(
            (ref) => EditingStyleNotifier(prefs)..state = style,
          ),
        ],
        child: MaterialApp(home: EditorScreen(note: value)),
      );
      await tester.pumpWidget(app(note, EditorEditingStyle.wysiwyg));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Markdown'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Editor style ('));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Super Editor'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<QuietSuperEditor>(find.byType(QuietSuperEditor))
          .controller!;
      controller.insertSnippet('Continued writing');
      await tester.pumpAndSettle();
      await EmailEditorBridge.active!.prepare();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      final saved = (await repo.getNoteById(note.id))!;
      for (final text in [
        'Email Details',
        'From: Sender',
        'Paragraph',
        'First',
        'Second',
        'Reply',
        'Total',
        'https://example.test',
        'qp://asset/11111111-1111-4111-8111-111111111111',
        'qp://asset/22222222-2222-4222-8222-222222222222',
        'Continued writing',
      ]) {
        expect(saved.markdownContent, contains(text));
      }
      expect(saved.importSources, [source]);
      await tester.pumpWidget(app(saved, EditorEditingStyle.superEditor));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      await db.close();
    },
  );
  testWidgets(
    'canceling a partially committed append reconciles the hidden editor',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final repo = DriftNotesRepository(db);
      final gateway = FakeEmailGateway();
      final note = Note(
        id: 'partial',
        title: 'Existing',
        content: 'Original',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await repo.saveNote(note);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repo),
            sharedPreferencesProvider.overrideWithValue(prefs),
            syncEngineProvider.overrideWithValue(_NoSync()),
            emailImportGatewayProvider.overrideWithValue(gateway),
            editorEditingStyleProvider.overrideWith(
              (ref) =>
                  EditingStyleNotifier(prefs)
                    ..state = EditorEditingStyle.markdown,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: EditorScreen(note: note),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final request = EmailImportRequest(
        inputs: const [
          EmailInput(path: 'first.eml'),
          EmailInput(path: 'second.eml'),
        ],
      );
      final operation = EmailImportLauncher.open(
        tester.element(find.byType(EditorScreen)),
        request,
        openSavedNote: false,
      );
      await tester.pumpAndSettle();
      // Simulate the first completed transaction while the next item awaits review.
      final updated = note.copyWith(
        content: 'Original\n\nCommitted email section',
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(updated);
      request.committedNoteIds.add(note.id);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await operation;
      expect(
        (await EmailEditorBridge.active!.prepare())!.content,
        updated.content,
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect((await repo.getNoteById(note.id))!.content, updated.content);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      await db.close();
    },
  );
}
