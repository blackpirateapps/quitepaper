import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_image_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_table_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

class _MockTypographyNotifier extends TypographySettingsNotifier {
  _MockTypographyNotifier(TypographySettings settings) : super(null) {
    state = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SuperEditor Markdown Serialization Tests', () {
    test('deserializes and serializes task items correctly', () {
      const markdown = '''# Tasks

- [ ] Buy groceries
- [x] Clean desk
''';

      final doc = deserializeMarkdownToDocument(markdown);
      expect(doc.nodeCount, equals(3));

      expect(doc.getNodeAt(0), isA<ParagraphNode>());
      expect((doc.getNodeAt(0) as ParagraphNode).text.toPlainText(), equals('Tasks'));

      expect(doc.getNodeAt(1), isA<TaskNode>());
      final task1 = doc.getNodeAt(1) as TaskNode;
      expect(task1.text.toPlainText(), equals('Buy groceries'));
      expect(task1.isComplete, isFalse);

      expect(doc.getNodeAt(2), isA<TaskNode>());
      final task2 = doc.getNodeAt(2) as TaskNode;
      expect(task2.text.toPlainText(), equals('Clean desk'));
      expect(task2.isComplete, isTrue);

      final serialized = serializeDocumentToMarkdown(doc);
      expect(serialized, contains('- [ ] Buy groceries'));
      expect(serialized, contains('- [x] Clean desk'));
    });

    test('toggling task completion serializes updated markdown', () {
      const markdown = '- [ ] Incomplete task\n';
      final doc = deserializeMarkdownToDocument(markdown);
      final task = doc.getNodeAt(0) as TaskNode;
      expect(task.isComplete, isFalse);

      doc.replaceNodeById(task.id, task.copyTaskWith(isComplete: true));
      final serialized = serializeDocumentToMarkdown(doc);
      expect(serialized, contains('- [x] Incomplete task'));
    });

    test('QuietImageNodeSerializer and normalizeMarkdown round trips perfectly', () {
      final customSerializers = [
        const QuietImageNodeSerializer(),
        const QuietTableBlockNodeSerializer(),
      ];

      // Test Case 1: Heading -> Image -> Paragraph
      const md1 = '# Heading\n![Alt](https://example.com/pic.png)\nSome text';
      final doc1 = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(md1));
      expect(doc1.nodeCount, equals(3));
      expect(doc1.getNodeAt(0), isA<ParagraphNode>());
      expect(doc1.getNodeAt(1), isA<ImageNode>());
      expect(doc1.getNodeAt(2), isA<ParagraphNode>());

      final serialized1 = serializeDocumentToMarkdown(
        doc1,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: customSerializers,
      );
      final doc1Re = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized1));
      expect(doc1Re.nodeCount, equals(3));
      expect(doc1Re.getNodeAt(1), isA<ImageNode>());
      expect((doc1Re.getNodeAt(1) as ImageNode).imageUrl, equals('https://example.com/pic.png'));

      // Test Case 2: Paragraph -> Image -> Paragraph
      const md2 = 'First paragraph\n\n![Alt](https://example.com/pic.png)\n\nSecond paragraph';
      final doc2 = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(md2));
      final serialized2 = serializeDocumentToMarkdown(
        doc2,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: customSerializers,
      );
      final doc2Re = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized2));
      expect(doc2Re.nodeCount, equals(3));
      expect(doc2Re.getNodeAt(1), isA<ImageNode>());

      // Test Case 3: Consecutive Images
      final doc3 = MutableDocument(nodes: [
        ImageNode(id: '1', imageUrl: 'https://example.com/pic1.png'),
        ImageNode(id: '2', imageUrl: 'https://example.com/pic2.png'),
      ]);
      final serialized3 = serializeDocumentToMarkdown(
        doc3,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: customSerializers,
      );
      final doc3Re = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized3));
      expect(doc3Re.nodeCount, equals(2));
      expect(doc3Re.getNodeAt(0), isA<ImageNode>());
      expect(doc3Re.getNodeAt(1), isA<ImageNode>());

      // Test Case 4: Table followed by text
      const md4 = '| Col 1 | Col 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |\nSome text';
      final doc4 = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(md4));
      expect(doc4.nodeCount, equals(2));
      expect(doc4.getNodeAt(0), isA<TableBlockNode>());
      expect(doc4.getNodeAt(1), isA<ParagraphNode>());

      final serialized4 = serializeDocumentToMarkdown(
        doc4,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: customSerializers,
      );
      final doc4Re = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized4));
      expect(doc4Re.nodeCount, equals(2));
      expect(doc4Re.getNodeAt(0), isA<TableBlockNode>());
      expect(doc4Re.getNodeAt(1), isA<ParagraphNode>());
    });
  });

  group('QuietSuperEditor Widget Tests', () {
    Widget buildTestWidget({
      required String markdown,
      required ValueChanged<String> onChanged,
      bool stripFrontmatter = false,
    }) {
      return ProviderScope(
        overrides: [
          typographySettingsProvider.overrideWith(
            (ref) => _MockTypographyNotifier(const TypographySettings()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Scaffold(
            body: QuietSuperEditor(
              initialMarkdown: markdown,
              onChanged: onChanged,
              stripFrontmatter: stripFrontmatter,
            ),
          ),
        ),
      );
    }

    testWidgets('renders SuperEditor and displays initial markdown content', (tester) async {
      const markdown = '# Hello World\n\nThis is a super editor note.';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietSuperEditor), findsOneWidget);
      expect(find.byType(SuperEditor), findsOneWidget);
      expect(find.text('Hello World', findRichText: true), findsOneWidget);
      expect(find.text('This is a super editor note.', findRichText: true), findsOneWidget);
    });

    testWidgets('renders task nodes with QuietTaskComponent and toggles checkboxes', (tester) async {
      const markdown = '- [ ] First task\n- [x] Second task';
      String? updatedMarkdown;

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (val) {
            updatedMarkdown = val;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietTaskComponent), findsNWidgets(2));
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);
      expect(find.text('First task', findRichText: true), findsOneWidget);
      expect(find.text('Second task', findRichText: true), findsOneWidget);

      // Tap unchecked box
      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNWidgets(2));
      expect(updatedMarkdown, contains('- [x] First task'));
    });

    testWidgets('renders table block node with QuietTableComponent and shows table view', (tester) async {
      const markdown = '| Col 1 | Col 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietTableComponent), findsOneWidget);
      expect(find.text('Col 1', findRichText: true), findsOneWidget);
      expect(find.text('Cell 1', findRichText: true), findsOneWidget);
      expect(find.text('Edit', findRichText: true), findsOneWidget);
    });

    testWidgets('deletes table block node when trash icon is tapped', (tester) async {
      const markdown = '| Col 1 | Col 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |';
      String? updatedMarkdown;

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (val) {
            updatedMarkdown = val;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietTableComponent), findsOneWidget);

      await tester.tap(find.byIcon(PhosphorIconsRegular.trash));
      await tester.pumpAndSettle();

      expect(find.byType(QuietTableComponent), findsNothing);
      expect(updatedMarkdown, isNot(contains('Col 1')));
    });

    testWidgets('renders image node via QuietImageComponentBuilder', (tester) async {
      const markdown = '![Alt](https://example.com/pic.png)';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImageComponent), findsOneWidget);
    });

    testWidgets('preserves ImageNode across edit -> preview -> edit toggle cycle', (tester) async {
      String currentMarkdown = '# My Note\n\n![Image](https://example.com/pic.png)\n\nCaption text';
      bool isPreview = false;
      final controller = QuietSuperEditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ProviderScope(
              overrides: [
                typographySettingsProvider.overrideWith(
                  (ref) => _MockTypographyNotifier(const TypographySettings()),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
                home: Scaffold(
                  body: isPreview
                      ? Text('Preview: $currentMarkdown')
                      : QuietSuperEditor(
                          initialMarkdown: currentMarkdown,
                          controller: controller,
                          onChanged: (val) {
                            currentMarkdown = val;
                          },
                        ),
                  floatingActionButton: IconButton(
                    icon: const Icon(Icons.toggle_off),
                    onPressed: () => setState(() => isPreview = !isPreview),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImageComponent), findsOneWidget);

      // Modify document so onChanged serializes document to currentMarkdown
      controller.insertSnippet(' edited');
      await tester.pumpAndSettle();

      // Toggle to preview
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ImageComponent), findsNothing);

      // Toggle back to edit
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ImageComponent), findsOneWidget);
    });

    testWidgets('preserves frontmatter prefix when stripFrontmatter is true', (tester) async {
      const frontmatter = '---\ntitle: Test Note\ntags:\n  - sample\n---\n';
      const body = 'Actual body text here.';
      const full = '$frontmatter$body';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: full,
          stripFrontmatter: true,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actual body text here.', findRichText: true), findsOneWidget);
      // Frontmatter should be stripped from visible document
      expect(find.text('title: Test Note', findRichText: true), findsNothing);
    });

    testWidgets('frontmatter-only change refreshes preserved prefix without clobbering next body edit', (tester) async {
      const body = 'Journal body line.';
      const oldFm = '---\nmood: 5\n---\n';
      const newFm = '---\nmood: 8\n---\n';
      final controller = QuietSuperEditorController();
      addTearDown(controller.dispose);

      String emitted = '';
      String current = '$oldFm$body';
      late StateSetter rebuild;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ProviderScope(
              overrides: [
                typographySettingsProvider.overrideWith(
                  (ref) => _MockTypographyNotifier(const TypographySettings()),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
                home: Scaffold(
                  body: QuietSuperEditor(
                    initialMarkdown: current,
                    controller: controller,
                    stripFrontmatter: true,
                    onChanged: (val) => emitted = val,
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Journal body line.', findRichText: true), findsOneWidget);

      // Simulate the Properties card mutating only the frontmatter metadata.
      current = '$newFm$body';
      rebuild(() {});
      await tester.pumpAndSettle();

      // The body document must survive (no rebuild), and a subsequent body edit
      // must re-prepend the NEW prefix rather than the stale one.
      expect(find.text('Journal body line.', findRichText: true), findsOneWidget);

      controller.insertSnippet(' edited');
      await tester.pumpAndSettle();

      expect(emitted, startsWith(newFm));
      expect(emitted, isNot(contains('mood: 5')));
      expect(emitted, contains('Journal body line.'));
    });

    testWidgets('attaches QuietSuperEditorController and provides caret overlay with accent color', (tester) async {
      final controller = QuietSuperEditorController();
      addTearDown(controller.dispose);
      const markdown = 'Editable text in super editor';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            typographySettingsProvider.overrideWith(
              (ref) => _MockTypographyNotifier(const TypographySettings()),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [AppColors.dark],
            ),
            home: Scaffold(
              body: QuietSuperEditor(
                initialMarkdown: markdown,
                controller: controller,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isAttached, isTrue);
      expect(find.byType(SuperEditor), findsOneWidget);
    });
  });

  group('QuietSuperEditorController Unit Tests', () {
    test('attaches, toggles bold, and manages headings', () {
      final doc = deserializeMarkdownToDocument('Hello world\n');
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: doc, composer: composer);
      final controller = QuietSuperEditorController();

      controller.attach(editor, composer);
      expect(controller.isAttached, isTrue);

      final node = doc.first as TextNode;
      composer.setSelectionWithReason(
        DocumentSelection(
          base: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 0)),
          extent: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 5)),
        ),
      );

      expect(controller.isBoldActive, isFalse);
      controller.toggleBold();
      expect(controller.isBoldActive, isTrue);

      controller.setHeadingLevel(2);
      expect(controller.activeHeadingLevel, equals(2));

      controller.convertHeadingToParagraph();
      expect(controller.activeHeadingLevel, isNull);

      controller.toggleChecklist();
      expect(controller.isChecklistActive, isTrue);

      controller.detach();
      expect(controller.isAttached, isFalse);
      controller.dispose();
    });

    test('can undo and redo operations via controller', () {
      final doc = deserializeMarkdownToDocument('Initial text\n');
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(
        document: doc,
        composer: composer,
        isHistoryEnabled: true,
      );
      final controller = QuietSuperEditorController();

      controller.attach(editor, composer);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      controller.insertSnippet(' more');
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.canUndo, isTrue);

      controller.dispose();
    });

    test('insertSnippet with image markdown creates ImageNode', () {
      final doc = deserializeMarkdownToDocument('Hello world\n');
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: doc, composer: composer);
      final controller = QuietSuperEditorController();
      controller.attach(editor, composer);

      final node = doc.first as TextNode;
      composer.setSelectionWithReason(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 5)),
        ),
      );

      controller.insertSnippet('![Alt](https://example.com/pic.png)');
      expect(doc.any((n) => n is ImageNode), isTrue);
      final imageNode = doc.firstWhere((n) => n is ImageNode) as ImageNode;
      expect(imageNode.imageUrl, equals('https://example.com/pic.png'));
      controller.dispose();
    });
  });
}

