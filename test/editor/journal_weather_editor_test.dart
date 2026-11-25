import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/frontmatter_editor_helper.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  for (final size in [const Size(1400, 900), const Size(550, 1200)]) {
    testWidgets(
      'weather retains pending Visual edits through saving and reopening at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final repository = DriftNotesRepository(db);
        final entry = await repository.getOrCreateJournalEntry(
          DateTime(2026, 11, 24),
        );
        await repository.saveNote(
          entry.copyWith(
            title: 'Weather reflection',
            content:
                '---\njournal: true\ndate: 2026-11-24\nlocation:\n  address: "Kolkata, India"\n  latitude: 22.57\n  longitude: 88.36\n---\n\nOriginal reflection.',
          ),
        );
        Widget app(Note note) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(prefs),
            editorEditingStyleProvider.overrideWith(
              (ref) =>
                  EditingStyleNotifier(prefs)
                    ..state = EditorEditingStyle.wysiwyg,
            ),
          ],
          child: MaterialApp(home: EditorScreen(note: note)),
        );
        await tester.pumpWidget(app((await repository.getNoteById(entry.id))!));
        await tester.pumpAndSettle();
        final response = Completer<http.Response>();
        var requests = 0;
        final client = MockClient((_) {
          requests++;
          return response.future;
        });
        addTearDown(client.close);
        await tester.ensureVisible(find.text('Fetch Weather'));
        await http.runWithClient(() async {
          await tester.tap(find.text('Fetch Weather'));
          await tester.pump();
        }, () => client);
        expect(requests, 1);
        final body = find
            .descendant(
              of: find.byType(RichTextEditor),
              matching: find.byType(EditableText),
            )
            .first;
        await tester.enterText(
          body,
          'Original reflection. Added during weather.',
        );
        // Complete before the 50ms Visual debounce publishes the body on its own.
        response.complete(
          http.Response(
            '{"current":{"temperature_2m":25,"weather_code":3}}',
            200,
          ),
        );
        await tester.pump();
        final canonical = tester
            .widget<MarkdownEditor>(find.byType(MarkdownEditor))
            .controller
            .text;
        expect(canonical, contains('Added during weather.'));
        expect(
          FrontmatterEditorHelper.parse(canonical).weather!.temperature,
          25,
        );
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
        final saved = (await repository.getNoteById(entry.id))!;
        expect(saved.content, contains('Added during weather.'));
        expect(
          FrontmatterEditorHelper.parse(saved.content).weather!.temperature,
          25,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(app(saved));
        await tester.pumpAndSettle();
        final reopened = tester
            .widget<MarkdownEditor>(find.byType(MarkdownEditor))
            .controller
            .text;
        expect(reopened, contains('Added during weather.'));
        expect(
          FrontmatterEditorHelper.parse(reopened).weather!.temperature,
          25,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
