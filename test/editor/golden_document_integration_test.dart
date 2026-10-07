import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/frontmatter_properties_section.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_editor_surface.dart';
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
| --- | --- |
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

    test('parses golden document completely and verifies all rich block types', () {
      final doc = const RichDocumentParser().parse(goldenMarkdown);

      // Check blocks
      expect(doc.blocks.any((b) => b is HeadingBlock && b.level == 1 && b.plainText == 'Main Heading'), isTrue);
      expect(doc.blocks.any((b) => b is HeadingBlock && b.level == 2 && b.plainText == 'Secondary Heading'), isTrue);
      expect(doc.blocks.any((b) => b is ParagraphBlock && b.plainText.contains('Plain paragraph with bold')), isTrue);
      expect(doc.blocks.any((b) => b is BulletedListItemBlock && b.plainText == 'First item'), isTrue);
      expect(doc.blocks.any((b) => b is BulletedListItemBlock && b.plainText == 'Second item'), isTrue);
      expect(doc.blocks.any((b) => b is OrderedListItemBlock && b.order == 1 && b.plainText == 'Ordered one'), isTrue);
      expect(doc.blocks.any((b) => b is OrderedListItemBlock && b.order == 2 && b.plainText == 'Ordered two'), isTrue);
      expect(doc.blocks.any((b) => b is ChecklistItemBlock && !b.isChecked && b.plainText == 'Unchecked'), isTrue);
      expect(doc.blocks.any((b) => b is ChecklistItemBlock && b.isChecked && b.plainText == 'Checked'), isTrue);
      expect(doc.blocks.any((b) => b is QuoteBlock && b.plainText == 'Quote'), isTrue);
      expect(doc.blocks.any((b) => b is HorizontalRuleBlock), isTrue);
      expect(doc.blocks.any((b) => b is CodeBlock && b.language == 'dart'), isTrue);
      expect(doc.blocks.any((b) => b is TableBlock), isTrue);
    });

    test('mode switching between Visual and Markdown mode is 100% lossless and source-preserving', () {
      // 1. Initial parse into RichDocument
      final doc = const RichDocumentParser().parse(goldenMarkdown);

      // 2. Controller holds and serializes markdown
      final ctrl = RichDocumentController(initialMarkdown: goldenMarkdown, stripFrontmatter: true);
      expect(ctrl.toMarkdown().trim(), equals(goldenMarkdown.trim()));

      // 3. Serializer round trips with rich document
      final roundTripDoc = const RichDocumentParser().parse(ctrl.toMarkdown());
      expect(roundTripDoc.blocks.length, equals(doc.blocks.length));
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

      // Verify RichEditorSurface
      expect(find.byType(RichEditorSurface), findsOneWidget);

      // Verify headings
      expect(find.textContaining('Main Heading'), findsWidgets);
      expect(find.textContaining('Secondary Heading'), findsWidgets);

      // Verify checklist icons
      expect(find.byIcon(PhosphorIconsRegular.square), findsWidgets);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsWidgets);

      // Verify code block
      expect(find.text('dart'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    });
  });
}
