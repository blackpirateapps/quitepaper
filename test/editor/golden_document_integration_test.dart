import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/semantic_editor_controller.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';
import 'package:quitepaper/features/editor/presentation/widgets/visual_document_editor.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('Golden Document Integration Fixture Tests (Section 51)', () {
    const goldenMarkdown = '''---
title: Semantic Editor Test
author: Dr. Watson
tags:
  - test
  - editor
---

# Main Heading

## Secondary Heading

Plain paragraph with **bold**, *italic*, ~~strike~~, `inline code`, [link](https://example.com), and [[Another Note]].

- First item
- Second item

1. Ordered one
2. Ordered two

- [ ] Unchecked
- [x] Checked

> Quote

---

```dart
final value = 42;
print(value);
```

| A | B |
|---|---|
| 1 | 2 |''';

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

    test('parses golden document completely and verifies all semantic block types', () {
      final doc = SemanticMarkdownParser.parse(goldenMarkdown, stripFrontmatter: false);

      expect(doc.hasFrontmatter, isTrue);
      expect(doc.frontmatter?.title, equals('Semantic Editor Test'));
      expect(doc.frontmatter?.author, equals('Dr. Watson'));

      // Check blocks
      expect(doc.blocks.any((b) => b is HeadingBlock && b.level == 1 && b.plainText == 'Main Heading'), isTrue);
      expect(doc.blocks.any((b) => b is HeadingBlock && b.level == 2 && b.plainText == 'Secondary Heading'), isTrue);
      expect(doc.blocks.any((b) => b is ParagraphBlock && b.plainText.contains('Plain paragraph with bold')), isTrue);
      expect(doc.blocks.any((b) => b is ListItemBlock && b.plainText == 'First item'), isTrue);
      expect(doc.blocks.any((b) => b is ListItemBlock && b.plainText == 'Second item'), isTrue);
      expect(doc.blocks.any((b) => b is OrderedListItemBlock && b.number == 1 && b.plainText == 'Ordered one'), isTrue);
      expect(doc.blocks.any((b) => b is OrderedListItemBlock && b.number == 2 && b.plainText == 'Ordered two'), isTrue);
      expect(doc.blocks.any((b) => b is ChecklistItemBlock && !b.checked && b.plainText == 'Unchecked'), isTrue);
      expect(doc.blocks.any((b) => b is ChecklistItemBlock && b.checked && b.plainText == 'Checked'), isTrue);
      expect(doc.blocks.any((b) => b is QuoteBlock && b.plainText == 'Quote'), isTrue);
      expect(doc.blocks.any((b) => b is HorizontalRuleBlock), isTrue);
      expect(doc.blocks.any((b) => b is CodeBlock && b.language == 'dart'), isTrue);
      expect(doc.blocks.any((b) => b is TableBlock), isTrue);
    });

    test('mode switching between WYSIWYG and Markdown mode is 100% lossless and source-preserving', () {
      // 1. Initial parse into SemanticDocument
      final doc = SemanticMarkdownParser.parse(goldenMarkdown, stripFrontmatter: true);

      // 2. Initial markdown is untouched
      expect(doc.canonicalMarkdown, equals(goldenMarkdown));

      // 3. Controller holds exact canonical markdown
      final ctrl = SemanticEditorController(initialMarkdown: goldenMarkdown, stripFrontmatter: true);
      expect(ctrl.markdown, equals(goldenMarkdown));

      // 4. Switching modes does not alter canonical markdown
      final markdownModeDoc = SemanticMarkdownParser.parse(ctrl.markdown, stripFrontmatter: false);
      expect(markdownModeDoc.canonicalMarkdown, equals(goldenMarkdown));
    });

    testWidgets('renders complete golden document inside EditorScreen in WYSIWYG mode', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'golden-note-1',
        title: 'Semantic Editor Test',
        content: goldenMarkdown,
        createdAt: now,
        updatedAt: now,
        tags: ['test', 'editor'],
      );
      await repository.saveNote(note);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(prefs),
            editorEditingStyleProvider.overrideWith((ref) => EditingStyleNotifier(prefs)..state = EditorEditingStyle.wysiwyg),
          ],
          child: MaterialApp(
            home: EditorScreen(note: note),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify FrontmatterPropertiesSection
      expect(find.byType(FrontmatterPropertiesSection), findsOneWidget);
      expect(find.text('Dr. Watson'), findsOneWidget);

      // Verify VisualDocumentEditor
      expect(find.byType(VisualDocumentEditor), findsOneWidget);

      // Verify headings
      expect(find.widgetWithText(TextField, 'Main Heading'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Secondary Heading'), findsOneWidget);

      // Verify checklist icons
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      // Verify code block
      expect(find.text('dart'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    });
  });
}
