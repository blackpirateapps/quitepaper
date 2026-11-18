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
}
