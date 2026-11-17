import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_text_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_checklist_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_editor_surface.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_code_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
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

    Widget createEditorApp(Note note, {EditorEditingStyle initialGlobalStyle = EditorEditingStyle.wysiwyg, bool autoFocusBody = false}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          editorEditingStyleProvider.overrideWith((ref) => EditingStyleNotifier(prefs)..state = initialGlobalStyle),
        ],
        child: MaterialApp(
          home: EditorScreen(note: note, autoFocusBody: autoFocusBody),
        ),
      );
    }

    Future<void> finishTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    }

    for (final code in [false, true]) {
      testWidgets('Active Visual ${code ? "code" : "paragraph"} switches to a live Markdown field', (tester) async {
        final now = DateTime.now();
        final note = Note(id: 'active-mode-$code', title: 'Mode',
          content: code ? 'Before\n```dart\nprint(1)\n```' : '',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note));
        await tester.pumpAndSettle();
        final active = find.descendant(of: find.byType(code ? RichCodeBlock : RichTextEditor), matching: find.byType(EditableText));
        await tester.enterText(active, code ? 'print(1)x' : 'mode probe');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit Markdown'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RichTextEditor), findsNothing);
        final body = find.descendant(of: find.byType(MarkdownEditor), matching: find.byType(EditableText));
        final editor = tester.widget<EditableText>(body);
        expect(editor.controller.text, contains(code ? 'print(1)x' : 'mode probe'));
        expect(editor.focusNode.hasPrimaryFocus, isTrue);
        expect(tester.getTopLeft(body).dy, lessThan(600));
        final text = '${editor.controller.text}!';
        tester.testTextInput.updateEditingValue(TextEditingValue(text: text,
          selection: TextSelection.collapsed(offset: text.length)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        expect((await repository.getNoteById(note.id))!.content, text);
        await finishTest(tester);
      });
    }

    testWidgets('Empty Visual Math insertion connects input and selects the formula', (tester) async {
      final now = DateTime.now();
      final note = Note(id: 'visual-math-input', title: 'Math', content: '',
        createdAt: now, updatedAt: now, tags: []);
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RichTextEditor), matching: find.byType(EditableText)));
      await tester.tap(find.byTooltip('Insert...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math Formula'));
      await tester.pumpAndSettle();
      final formulaField = find.descendant(of: find.byType(RichCodeBlock), matching: find.byType(EditableText));
      final formula = tester.widget<EditableText>(formulaField);
      expect(formula.focusNode.hasPrimaryFocus, isTrue);
      expect(formula.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 8));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'x',
        selection: TextSelection.collapsed(offset: 1), composing: TextRange(start: 0, end: 1)));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(formulaField).controller.value.composing, const TextRange(start: 0, end: 1));
      await tester.pump(const Duration(milliseconds: 800));
      final doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
      expect(doc.blocks.whereType<CodeBlock>().single.code, 'x');
      expect(tester.takeException(), isNull);
      await finishTest(tester);
    });

    for (final mixed in [false, true]) {
      testWidgets('Visual Tag keeps its caret after the marker with mixed=$mixed', (tester) async {
        final now = DateTime.now();
        final note = Note(id: 'visual-tag-$mixed', title: 'Tags',
          content: mixed ? '**Before**\n- [ ] task\nTail ' : '',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note));
        await tester.pumpAndSettle();
        final body = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == (mixed ? 'Tail ' : ''));
        await tester.tap(body);
        await tester.pumpAndSettle();
        final editor = tester.widget<EditableText>(body);
        editor.controller.selection = TextSelection.collapsed(offset: editor.controller.text.length);
        await tester.tap(find.byTooltip('Insert...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tag').last);
        await tester.pumpAndSettle();
        final prefix = mixed ? 'Tail #' : '#';
        final target = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == prefix);
        final updated = tester.widget<EditableText>(target);
        expect(updated.focusNode.hasPrimaryFocus, isTrue);
        expect(updated.controller.selection.extentOffset, prefix.length);
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '${prefix}nativeaudit',
          selection: TextSelection.collapsed(offset: prefix.length + 11)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        final doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, '${prefix}nativeaudit');
        if (mixed) expect(doc.blocks.first.spans.first.attributes.isBold, isTrue);
        expect(tester.takeException(), isNull);
        await finishTest(tester);
      });
    }

    for (final mixed in [false, true]) {
      testWidgets('Visual Link Note keeps the query after brackets and completes with mixed=$mixed', (tester) async {
        final now = DateTime.now();
        final reference = Note(id: 'reference-$mixed', title: 'Other note', content: 'Reference',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(reference);
        final note = Note(id: 'visual-note-link-$mixed', title: 'Links',
          content: mixed ? '**Before**\n- [ ] task\nTail ' : '',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note));
        await tester.pumpAndSettle();
        final body = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == (mixed ? 'Tail ' : ''));
        await tester.tap(body);
        await tester.pumpAndSettle();
        final editor = tester.widget<EditableText>(body);
        editor.controller.selection = TextSelection.collapsed(offset: editor.controller.text.length);
        await tester.tap(find.byTooltip('Insert...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link Note').last);
        await tester.pumpAndSettle();
        final prefix = mixed ? 'Tail [[' : '[[';
        final target = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == prefix);
        final updated = tester.widget<EditableText>(target);
        expect(updated.focusNode.hasPrimaryFocus, isTrue);
        expect(updated.controller.selection.extentOffset, prefix.length);
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '${prefix}Other',
          selection: TextSelection.collapsed(offset: prefix.length + 5)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        var doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, '${prefix}Other');
        expect(find.text('Other note'), findsOneWidget);
        await tester.tap(find.text('Other note'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, contains('qp://note/${reference.id}'));
        expect(doc.blocks.last.plainText, isNot(contains('[[')));
        if (mixed) expect(doc.blocks.first.spans.first.attributes.isBold, isTrue);
        expect(tester.takeException(), isNull);
        await finishTest(tester);
      });
    }

    for (final mixed in [false]) {
      testWidgets('CL-04 checklist Tag keeps its caret after the marker with mixed=$mixed', (tester) async {
        final now = DateTime.now();
        final note = Note(id: 'checklist-tag-$mixed', title: 'Tags',
          content: '- [ ] Task ',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note));
        await tester.pumpAndSettle();
        final body = find.descendant(of: find.byType(RichChecklistEditor), matching: find.byType(EditableText));
        await tester.tap(body);
        await tester.pumpAndSettle();
        final editor = tester.widget<EditableText>(body);
        editor.controller.selection = TextSelection.collapsed(offset: editor.controller.text.length);
        await tester.tap(find.byTooltip('Insert...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tag').last);
        await tester.pumpAndSettle();
        const prefix = 'Task #';
        final target = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == prefix);
        final updated = tester.widget<EditableText>(target);
        expect(updated.focusNode.hasPrimaryFocus, isTrue);
        expect(updated.controller.selection.extentOffset, prefix.length);
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '${prefix}nativeaudit',
          selection: TextSelection.collapsed(offset: prefix.length + 11)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        final doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, '${prefix}nativeaudit');
        if (mixed) expect(doc.blocks.first.spans.first.attributes.isBold, isTrue);
        expect(tester.takeException(), isNull);
        await finishTest(tester);
      });
    }

    for (final mixed in [false]) {
      testWidgets('CL-04 checklist Link Note keeps the query after brackets and completes with mixed=$mixed', (tester) async {
        final now = DateTime.now();
        final reference = Note(id: 'reference-$mixed', title: 'Other note', content: 'Reference',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(reference);
        final note = Note(id: 'checklist-note-link-$mixed', title: 'Links',
          content: '- [ ] Task ',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note));
        await tester.pumpAndSettle();
        final body = find.descendant(of: find.byType(RichChecklistEditor), matching: find.byType(EditableText));
        await tester.tap(body);
        await tester.pumpAndSettle();
        final editor = tester.widget<EditableText>(body);
        editor.controller.selection = TextSelection.collapsed(offset: editor.controller.text.length);
        await tester.tap(find.byTooltip('Insert...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link Note').last);
        await tester.pumpAndSettle();
        const prefix = 'Task [[';
        final target = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == prefix);
        final updated = tester.widget<EditableText>(target);
        expect(updated.focusNode.hasPrimaryFocus, isTrue);
        expect(updated.controller.selection.extentOffset, prefix.length);
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '${prefix}Other',
          selection: TextSelection.collapsed(offset: prefix.length + 5)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        var doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, '${prefix}Other');
        expect(find.text('Other note'), findsOneWidget);
        await tester.tap(find.text('Other note'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        doc = RichDocument.fromJson(jsonDecode((await repository.getNoteById(note.id))!.content) as Map<String, dynamic>);
        expect(doc.blocks.last.plainText, contains('qp://note/${reference.id}'));
        expect(doc.blocks.last.plainText, isNot(contains('[[')));
        if (mixed) expect(doc.blocks.first.spans.first.attributes.isBold, isTrue);
        expect(tester.takeException(), isNull);
        await finishTest(tester);
      });
    }

    testWidgets('CL-10 structured checklist insertion autosaves at the task caret', (tester) async {
      final now = DateTime.now();
      final note = Note(id: 'checklist-paste', title: 'Paste', content: '- [ ] Alpha\n- [ ] Neighbor',
        createdAt: now, updatedAt: now, tags: []);
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();
      final body = find.descendant(of: find.byType(RichChecklistEditor), matching: find.byType(EditableText)).first;
      await tester.tap(body);
      final editor = tester.widget<EditableText>(body);
      editor.controller.selection = const TextSelection.collapsed(offset: 5);
      tester.widget<RichEditorSurface>(find.byType(RichEditorSurface)).controller
        .insertMarkdownSnippet('\n- [ ] Beta\n- [x] Gamma');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      final saved = (await repository.getNoteById(note.id))!.content;
      final doc = RichDocument.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      expect(const RichDocumentSerializer().serialize(doc), '- [ ] Alpha\n- [ ] Beta\n- [x] Gamma\n- [ ] Neighbor');
      final active = tester.widgetList<EditableText>(find.byType(EditableText)).where((f) => f.focusNode.hasFocus).single;
      expect(active.controller.text, 'Gamma');
      expect(active.controller.selection.extentOffset, 5);
      await finishTest(tester);
    });

    testWidgets('Visual Math inserts into saved rich JSON without corrupting it', (tester) async {
      final now = DateTime.now();
      final note = Note(id: 'visual-math-json', title: 'Math', content: '',
        createdAt: now, updatedAt: now, tags: []);
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();
      final body = find.descendant(of: find.byType(RichTextEditor), matching: find.byType(EditableText));
      await tester.enterText(body, 'Math existing body');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      expect(jsonDecode((await repository.getNoteById(note.id))!.content), isA<Map<String, dynamic>>());
      await tester.tap(find.byTooltip('Insert...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math Formula'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      final saved = (await repository.getNoteById(note.id))!;
      final doc = RichDocument.fromJson(jsonDecode(saved.content) as Map<String, dynamic>);
      expect(doc.blocks.first.plainText, 'Math existing body');
      expect(doc.blocks.whereType<CodeBlock>().single.language, 'math');
      expect(tester.takeException(), isNull);
      await finishTest(tester);
    });

    for (final fenced in [false, true]) {
      testWidgets('Markdown toolbar history restores input focus with code=$fenced', (tester) async {
        final now = DateTime.now();
        final note = Note(id: 'markdown-history-$fenced', title: 'History', content: '',
          createdAt: now, updatedAt: now, tags: []);
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.markdown));
        await tester.pumpAndSettle();
        final body = find.descendant(of: find.byType(MarkdownEditor), matching: find.byType(EditableText));
        final text = fenced ? '```dart\nhistory probe\n```' : 'history probe';
        await tester.enterText(body, text);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Undo'));
        await tester.pumpAndSettle();
        var editor = tester.widget<EditableText>(body);
        expect(editor.focusNode.hasPrimaryFocus, isTrue);
        expect(editor.controller.selection.isValid, isTrue);
        await tester.tap(find.byTooltip('Redo'));
        await tester.pumpAndSettle();
        editor = tester.widget<EditableText>(body);
        expect(editor.focusNode.hasPrimaryFocus, isTrue);
        expect(editor.controller.text, text);
        expect(editor.controller.selection.extentOffset, text.length);
        tester.testTextInput.updateEditingValue(TextEditingValue(text: '${text}x',
          selection: TextSelection.collapsed(offset: text.length + 1)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        expect((await repository.getNoteById(note.id))!.content, '${text}x');
        expect(tester.takeException(), isNull);
        await finishTest(tester);
      });
    }

    testWidgets('Markdown first code insertion keeps the field and accepts immediate typing', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'markdown-code-insertion', title: 'Markdown code', content: '',
        createdAt: now, updatedAt: now, tags: [],
      );
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.markdown));
      await tester.pumpAndSettle();
      final body = find.descendant(of: find.byType(MarkdownEditor), matching: find.byType(EditableText));
      await tester.tap(body);
      await tester.pump();
      final originalState = tester.state<EditableTextState>(body);
      await tester.tap(find.byTooltip('Insert...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code Block'));
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(body), same(originalState));
      final editor = tester.widget<EditableText>(body);
      expect(editor.focusNode.hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      final value = editor.controller.value;
      expect(value.text, contains('```'));
      expect(value.selection.isValid, isTrue);
      final typed = value.text.replaceRange(value.selection.start, value.selection.end, 'print');
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: typed, selection: TextSelection.collapsed(offset: value.selection.start + 5),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      expect(editor.controller.text, typed);
      expect((await repository.getNoteById(note.id))!.content, typed);
      expect(tester.takeException(), isNull);
      await finishTest(tester);
    });

    testWidgets('Visual code insertion focuses, types, saves and restores code history', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'visual-code-insertion', title: 'Code', content: '',
        createdAt: now, updatedAt: now, tags: [],
      );
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MarkdownEditor), matching: find.byType(EditableText)));
      await tester.pump();
      await tester.tap(find.byTooltip('Insert...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code Block'));
      await tester.pumpAndSettle();
      final codeField = find.descendant(of: find.byType(RichCodeBlock), matching: find.byType(EditableText));
      final code = tester.widget<EditableText>(codeField);
      expect(code.focusNode.hasPrimaryFocus, isTrue);
      expect(code.controller.selection, const TextSelection.collapsed(offset: 0));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'print', selection: TextSelection.collapsed(offset: 5),
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(codeField).controller.text, 'print');
      await tester.pump(const Duration(milliseconds: 800));
      final saved = (await repository.getNoteById(note.id))!;
      final doc = RichDocument.fromJson(jsonDecode(saved.content) as Map<String, dynamic>);
      expect(doc.blocks.whereType<CodeBlock>().single.code, 'print');
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(codeField).controller.text, isEmpty);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      final restored = tester.widget<EditableText>(codeField);
      expect(restored.controller.text, 'print');
      expect(restored.controller.selection, const TextSelection.collapsed(offset: 5));
      expect(restored.focusNode.hasPrimaryFocus, isTrue);
      await tester.tap(find.text('Plain Text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dart'));
      await tester.pumpAndSettle();
      final afterLanguage = tester.widget<EditableText>(codeField);
      expect(afterLanguage.focusNode.hasPrimaryFocus, isTrue);
      expect(afterLanguage.controller.selection, const TextSelection.collapsed(offset: 5));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'printx',
        selection: TextSelection.collapsed(offset: 6)));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      final languageSave = (await repository.getNoteById(note.id))!;
      final languageDoc = RichDocument.fromJson(jsonDecode(languageSave.content) as Map<String, dynamic>);
      final languageBlock = languageDoc.blocks.whereType<CodeBlock>().single;
      expect(languageBlock.language, 'dart');
      expect(languageBlock.code, 'printx');
      await tester.tap(find.text('dart'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final afterCancel = tester.widget<EditableText>(codeField);
      expect(afterCancel.focusNode.hasPrimaryFocus, isTrue);
      expect(afterCancel.controller.selection, const TextSelection.collapsed(offset: 6));
      expect(tester.takeException(), isNull);
      await finishTest(tester);
    });

    testWidgets('Visual toolbar undo and redo retain a live body input and save history', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'visual-toolbar-history', title: 'History', content: '',
        createdAt: now, updatedAt: now, tags: [],
      );
      await repository.saveNote(note);
      await tester.pumpWidget(createEditorApp(note));
      await tester.pumpAndSettle();
      final body = find.descendant(of: find.byType(MarkdownEditor), matching: find.byType(EditableText));
      await tester.enterText(body, 'undo probe');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<EditableText>(body).controller.text, isEmpty);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final restored = tester.widget<EditableText>(body);
      expect(restored.controller.text, 'undo probe');
      expect(restored.focusNode.hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.getTopLeft(body).dy, lessThan(600));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'undo probe!', selection: TextSelection.collapsed(offset: 11),
      ));
      await tester.pumpAndSettle();
      // Keyboard history must operate on the same snapshots as the toolbar.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(body).controller.text, 'undo probe');
      final saved = (await repository.getNoteById(note.id))!;
      expect(const RichDocumentSerializer().serialize(
        RichDocument.fromJson(jsonDecode(saved.content) as Map<String, dynamic>)), 'undo probe');
      await finishTest(tester);
    });

    for (final style in [EditorEditingStyle.wysiwyg, EditorEditingStyle.markdown]) {
      for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
        testWidgets('${style.label} title submission on ${platform.name} keeps body input connected', (tester) async {
          final now = DateTime.now();
          final note = Note(
            id: 'new-${style.name}-note',
            title: '',
            content: '',
            createdAt: now,
            updatedAt: now,
            tags: [],
          );
          await repository.saveNote(note);
          await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: style, autoFocusBody: true));
          await tester.pumpAndSettle();

          final titleField = find.byWidgetPredicate(
            (widget) => widget is TextField && widget.decoration?.hintText == 'Title',
          );
          await tester.enterText(titleField, 'My new note');
          if (platform == TargetPlatform.linux) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.testTextInput.receiveAction(TextInputAction.next);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final bodyField = find.descendant(
            of: find.byType(MarkdownEditor),
            matching: find.byType(EditableText),
          );
          final body = tester.widget<EditableText>(bodyField);
          expect(body.focusNode.hasPrimaryFocus, isTrue);
          expect(body.controller.selection, const TextSelection.collapsed(offset: 0));
          expect(tester.state<EditableTextState>(bodyField).renderEditable.showCursor.value, isTrue);
          expect(tester.testTextInput.hasAnyClients, isTrue);

          if (platform == TargetPlatform.linux) {
            expect(
              await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b'),
              isFalse,
              reason: 'Printable keys must reach the Linux native text input',
            );
          }

          // Use the existing input connection, without tapping or refocusing the body.
          tester.testTextInput.updateEditingValue(const TextEditingValue(
            text: 'Body text',
            selection: TextSelection.collapsed(offset: 9),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          expect(body.controller.text, 'Body text');

          if (platform == TargetPlatform.linux && style == EditorEditingStyle.wysiwyg) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            tester.testTextInput.updateEditingValue(const TextEditingValue(
              text: 'Body text\n',
              selection: TextSelection.collapsed(offset: 10),
            ));
          }
          await tester.pump(const Duration(milliseconds: 100));
          expect(body.controller.text, 'Body text\n');
          tester.testTextInput.updateEditingValue(const TextEditingValue(
            text: 'Body text\nNext line',
            selection: TextSelection.collapsed(offset: 19),
          ));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 800));
          expect(body.controller.text, 'Body text\nNext line');
          final saved = (await repository.getNoteById(note.id))!;
          expect(saved.title, 'My new note');
          final markdown = RichDocument.isJson(saved.content)
              ? const RichDocumentSerializer().serialize(RichDocument.fromJson(jsonDecode(saved.content) as Map<String, dynamic>))
              : saved.content;
          expect(markdown.trim(), 'Body text\nNext line');
          if (platform == TargetPlatform.linux) {
            await tester.tap(titleField);
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
            await tester.pump();
            expect(body.focusNode.hasPrimaryFocus, isTrue);
            expect(body.controller.selection, const TextSelection.collapsed(offset: 0));
            expect(body.controller.text, 'Body text\nNext line');
          }
          await finishTest(tester);
        }, variant: TargetPlatformVariant({platform}));
      }
    }

    for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
      testWidgets('Super Editor title submission on ${platform.name} shows body caret and accepts typing', (tester) async {
        final now = DateTime.now();
        final note = Note(
          id: 'new-super-note',
          title: '',
          content: '',
          createdAt: now,
          updatedAt: now,
          tags: [],
        );
        await repository.saveNote(note);
        await tester.pumpWidget(createEditorApp(note, initialGlobalStyle: EditorEditingStyle.superEditor));
        await tester.pumpAndSettle();

        final titleField = find.byWidgetPredicate(
          (widget) => widget is TextField && widget.decoration?.hintText == 'Title',
        );
        final divider = find.byKey(const ValueKey('super-editor-title-divider'));
        final bodyHint = find.text('Start writing...', findRichText: true);
        expect(divider, findsOneWidget);
        expect(bodyHint, findsOneWidget);
        expect(tester.getBottomLeft(titleField).dy, lessThanOrEqualTo(tester.getTopLeft(divider).dy));
        expect(tester.getBottomLeft(divider).dy, lessThanOrEqualTo(tester.getTopLeft(bodyHint).dy));

        await tester.enterText(titleField, 'My new note');
        // Both desktop Enter and the mobile Next key submit this single-line field
        // through the platform text input action.
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final body = tester.widget<QuietSuperEditor>(find.byType(QuietSuperEditor));
        expect(body.focusNode!.hasFocus, isTrue);
        final controller = body.controller!;
        expect(controller.composer!.selection, DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: controller.editor!.document.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ));
        expect(find.byKey(DocumentKeys.caret), findsWidgets);
        expect(bodyHint, findsOneWidget);

        final imeState = tester.state<SuperEditorImeInteractorState>(find.byType(SuperEditorImeInteractor));
        expect(imeState.isAttachedToIme, isTrue);
        final imeClient = imeState.imeClient;
        final imeValue = imeClient.currentTextEditingValue!;
        final insertionOffset = imeValue.selection.extentOffset;
        imeClient.updateEditingValueWithDeltas([
          TextEditingDeltaInsertion(
            oldText: imeValue.text,
            textInserted: 'Body text',
            insertionOffset: insertionOffset,
            selection: TextSelection.collapsed(offset: insertionOffset + 'Body text'.length),
            composing: TextRange.empty,
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 800));
        expect(bodyHint, findsNothing);
        final saved = (await repository.getNoteById(note.id))!;
        expect(saved.title, 'My new note');
        expect(saved.content.trim(), 'Body text');
        expect(saved.content, isNot(contains('Start writing...')));
        expect(saved.content, isNot(contains('---')));

        final typedValue = imeClient.currentTextEditingValue!;
        imeClient.updateEditingValueWithDeltas([
          TextEditingDeltaDeletion(
            oldText: typedValue.text,
            deletedRange: TextRange(start: insertionOffset, end: typedValue.selection.extentOffset),
            selection: TextSelection.collapsed(offset: insertionOffset),
            composing: TextRange.empty,
          ),
        ]);
        await tester.pump(const Duration(milliseconds: 800));
        expect(bodyHint, findsOneWidget);
        expect((await repository.getNoteById(note.id))!.content.trim(), isEmpty);

        await finishTest(tester);
      }, variant: TargetPlatformVariant({platform}));
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
      expect(find.byType(RichTextEditor), findsOneWidget);
      expect(find.textContaining('Heading'), findsWidgets);
      expect(find.textContaining('Body text here.'), findsWidgets);

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
