import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_code_block_component.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuietCodeBlock Promotion & Serialization Tests', () {
    test('promotes code block language from markdown fences', () {
      const markdown = '''
# Heading

```dart
void main() {
  print('Hello');
}
```

Paragraph between code blocks.

```python
def hello():
    return "world"
```
''';

      final doc = deserializeMarkdownToDocument(markdown);
      promoteQuietCodeBlockNodes(doc, markdown);

      final codeNodes = [for (int i = 0; i < doc.nodeCount; i++) doc.getNodeAt(i)!]
          .whereType<ParagraphNode>()
          .where((n) => n.metadata[NodeMetadata.blockType] == codeAttribution)
          .toList();

      expect(codeNodes.length, 2);
      expect(codeNodes[0].metadata['language'], 'dart');
      expect(codeNodes[1].metadata['language'], 'python');
      expect(codeNodes[0].text.toPlainText(), contains('void main()'));
      expect(codeNodes[1].text.toPlainText(), contains('def hello()'));
    });

    test('promotes code block without language as empty language', () {
      const markdown = '''
```
plain text code
```
''';

      final doc = deserializeMarkdownToDocument(markdown);
      promoteQuietCodeBlockNodes(doc, markdown);

      final codeNode = doc.first as ParagraphNode;
      expect(codeNode.metadata[NodeMetadata.blockType], codeAttribution);
      expect(codeNode.metadata['language'], isNull);
    });

    test('QuietCodeBlockNodeSerializer serializes code blocks with language', () {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(
            id: 'code1',
            text: AttributedText('print("hello");\n'),
            metadata: {
              NodeMetadata.blockType: codeAttribution,
              'language': 'dart',
            },
          ),
          ParagraphNode(
            id: 'p1',
            text: AttributedText('A paragraph below code.'),
          ),
        ],
      );

      const serializer = QuietCodeBlockNodeSerializer();
      final serializedCode = serializer.serialize(doc, doc.getNodeAt(0)!);
      expect(serializedCode, contains('```dart'));
      expect(serializedCode, contains('print("hello");'));
      expect(serializedCode, contains('```'));

      // Non-code paragraph must return null
      final nonCodeSerialized = serializer.serialize(doc, doc.getNodeAt(1)!);
      expect(nonCodeSerialized, isNull);
    });

    test('Full Markdown round-trip preserves code content and language fences', () {
      const originalMarkdown = '''# Welcome

```dart
void main() {
  print('Quiet Paper');
}
```

Some intervening text.

```json
{
  "key": "value"
}
```''';

      final doc = deserializeMarkdownToDocument(originalMarkdown);
      promoteQuietCodeBlockNodes(doc, originalMarkdown);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [
          QuietCodeBlockNodeSerializer(),
        ],
      );

      expect(serialized, contains('```dart\nvoid main()'));
      expect(serialized, contains('```json\n{\n  "key": "value"\n}\n```'));
      expect(serialized, contains('Some intervening text.'));
    });
  });

  group('Code Block Creation via Space and Enter Reactions', () {
    test('handleCodeBlockFenceNewlineRequest converts ```dart on Enter into code block', () {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(
            id: 'n1',
            text: AttributedText('```dart'),
          ),
        ],
      );
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'n1',
            nodePosition: TextNodePosition(offset: 7),
          ),
        ),
      );
      final editor = createDefaultDocumentEditor(
        document: doc,
        composer: composer,
      );

      // Register the request handler in editor
      editor.requestHandlers.insert(0, handleCodeBlockFenceNewlineRequest);

      // Execute newline request as if Enter was pressed
      editor.execute([
        InsertNewlineAtCaretRequest('new_1'),
      ]);

      final node = doc.getNodeById('n1') as ParagraphNode;
      expect(node.metadata[NodeMetadata.blockType], codeAttribution);
      expect(node.metadata['language'], 'dart');
      expect(node.text.toPlainText(), '');
    });

    test('CodeBlockConversionReaction pattern matches ``` and ```lang + space', () {
      const reaction = CodeBlockConversionReaction();
      expect(reaction.pattern.hasMatch('``` '), isTrue);
      expect(reaction.pattern.hasMatch('```dart '), isTrue);
      expect(reaction.pattern.hasMatch('~~~python '), isTrue);
      expect(reaction.pattern.hasMatch('```not a match'), isFalse);
    });
  });

  group('QuietCodeBlockComponent Widget Tests', () {
    Widget buildEditorWrapper({
      required String markdown,
      ValueChanged<String>? onChanged,
      QuietSuperEditorController? controller,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuietSuperEditor(
                initialMarkdown: markdown,
                onChanged: onChanged ?? (_) {},
                controller: controller,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders QuietCodeBlockComponent with language pill, copy button, and line numbers', (tester) async {
      const markdown = '''```dart
void main() {
  print('Hello');
}
```''';

      await tester.pumpWidget(buildEditorWrapper(markdown: markdown));
      await tester.pumpAndSettle();

      // Verify custom code block component is rendered
      expect(find.byType(QuietCodeBlockComponent), findsOneWidget);

      // Verify language pill shows DART
      expect(find.text('DART'), findsOneWidget);

      // Verify line numbers in gutter are rendered
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify code body text is visible in SuperText rich text
      expect(
        find.textContaining('void main()', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('copy button copies code block text to clipboard', (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          return null;
        },
      );

      const markdown = '''```python
x = 42
print(x)
```''';

      await tester.pumpWidget(buildEditorWrapper(markdown: markdown));
      await tester.pumpAndSettle();

      // Find copy button tooltip
      final copyButton = find.byTooltip('Copy Code');
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump();

      expect(clipboardText, contains('x = 42'));
      expect(clipboardText, contains('print(x)'));

      await tester.pump(const Duration(milliseconds: 1700));
    });

    testWidgets('controller can insert code block and update language', (tester) async {
      final controller = QuietSuperEditorController();
      addTearDown(controller.dispose);
      String lastSaved = '';

      await tester.pumpWidget(buildEditorWrapper(
        markdown: 'A regular paragraph',
        controller: controller,
        onChanged: (val) => lastSaved = val,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(QuietCodeBlockComponent), findsNothing);

      // Place caret in the paragraph and convert to code block
      final doc = controller.editor!.document;
      controller.composer!.setSelectionWithReason(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: doc.first.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );
      controller.insertCodeBlock(language: 'json');
      await tester.pumpAndSettle();

      expect(find.byType(QuietCodeBlockComponent), findsOneWidget);
      expect(find.text('JSON'), findsOneWidget);
      expect(lastSaved, contains('```json'));

      // Test setCodeBlockLanguage updates language
      controller.setCodeBlockLanguage(doc.first.id, 'rust');
      await tester.pumpAndSettle();

      expect(find.text('RUST'), findsOneWidget);
      expect(lastSaved, contains('```rust'));
    });
  });
}
