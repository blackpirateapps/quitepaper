import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_horizontal_rule_component.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:super_editor/super_editor.dart';

class _MockTypographyNotifier extends TypographySettingsNotifier {
  _MockTypographyNotifier(TypographySettings settings) : super(null) {
    state = settings;
  }
}

class _TestDocumentLayout extends Fake implements DocumentLayout {
  _TestDocumentLayout({this.positionNearestOffset});
  final DocumentPosition? positionNearestOffset;

  @override
  DocumentPosition? getDocumentPositionNearestToOffset(Offset offset) => positionNearestOffset;
}

class _TestScroller extends Fake implements DocumentScroller {}

Widget _buildTestApp({
  required String markdown,
  required ValueChanged<String> onChanged,
  QuietSuperEditorController? controller,
  FocusNode? focusNode,
}) {
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
          initialMarkdown: markdown,
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuietDivider Component & Invariant Tests', () {
    testWidgets('initializes document ending with --- with an editable trailing paragraph', (tester) async {
      const markdown = 'Header\n\n---';
      final controller = QuietSuperEditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestApp(
          markdown: markdown,
          controller: controller,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final doc = controller.editor!.document;
      expect(doc.nodeCount, equals(3));
      expect(doc.getNodeAt(0), isA<ParagraphNode>());
      expect(doc.getNodeAt(1), isA<HorizontalRuleNode>());
      expect(doc.getNodeAt(2), isA<ParagraphNode>());
      expect((doc.getNodeAt(2) as ParagraphNode).text.toPlainText(), isEmpty);
    });

    testWidgets('renders QuietHorizontalRuleComponent for HorizontalRuleNode', (tester) async {
      const markdown = 'Hello\n\n---\n\nWorld';
      await tester.pumpWidget(
        _buildTestApp(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietHorizontalRuleComponent), findsOneWidget);
    });

    test('serializes document with HorizontalRuleNode and empty ParagraphNode cleanly', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: '1', text: AttributedText('Section 1')),
        HorizontalRuleNode(id: '2'),
        ParagraphNode(id: '3', text: AttributedText('')),
      ]);

      final markdown = serializeDocumentToMarkdown(doc);
      expect(markdown, contains('Section 1'));
      expect(markdown, contains('---'));
    });
  });

  group('QuietDivider Keyboard Actions Unit Tests', () {
    late MutableDocument document;
    late MutableDocumentComposer composer;
    late Editor editor;
    late SuperEditorContext editContext;

    setUp(() {
      document = MutableDocument(nodes: [
        ParagraphNode(id: '1', text: AttributedText('Above')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      composer = MutableDocumentComposer();
      editor = createDefaultDocumentEditor(document: document, composer: composer);

      // Select the horizontal rule node
      composer.setSelectionWithReason(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'hr1',
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );

      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final layout = _TestDocumentLayout();
      final scroller = _TestScroller();

      editContext = SuperEditorContext(
        editorFocusNode: focusNode,
        editor: editor,
        document: document,
        composer: composer,
        getDocumentLayout: () => layout,
        scroller: scroller,
        commonOps: CommonEditorOperations(
          editor: editor,
          document: document,
          composer: composer,
          documentLayoutResolver: () => layout,
        ),
      );
    });

    test('Enter on terminal divider inserts empty paragraph and focuses it', () {
      expect(document.nodeCount, equals(2));

      final instruction = handleDividerKeyboardActions(
        editContext: editContext,
        keyEvent: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );

      expect(instruction, equals(ExecutionInstruction.haltExecution));
      expect(document.nodeCount, equals(3));
      expect(document.getNodeAt(2), isA<ParagraphNode>());
      expect((document.getNodeAt(2) as ParagraphNode).text.toPlainText(), isEmpty);
      expect(composer.selection?.extent.nodeId, equals(document.getNodeAt(2)!.id));
      expect(composer.selection?.extent.nodePosition, equals(const TextNodePosition(offset: 0)));
    });

    test('ArrowDown on terminal divider inserts empty paragraph and focuses it', () {
      expect(document.nodeCount, equals(2));

      final instruction = handleDividerKeyboardActions(
        editContext: editContext,
        keyEvent: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );

      expect(instruction, equals(ExecutionInstruction.haltExecution));
      expect(document.nodeCount, equals(3));
      expect(document.getNodeAt(2), isA<ParagraphNode>());
      expect(composer.selection?.extent.nodeId, equals(document.getNodeAt(2)!.id));
      expect(composer.selection?.extent.nodePosition, equals(const TextNodePosition(offset: 0)));
    });

    test('ArrowRight on terminal divider inserts empty paragraph and focuses it', () {
      expect(document.nodeCount, equals(2));

      final instruction = handleDividerKeyboardActions(
        editContext: editContext,
        keyEvent: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
      );

      expect(instruction, equals(ExecutionInstruction.haltExecution));
      expect(document.nodeCount, equals(3));
      expect(document.getNodeAt(2), isA<ParagraphNode>());
      expect(composer.selection?.extent.nodeId, equals(document.getNodeAt(2)!.id));
      expect(composer.selection?.extent.nodePosition, equals(const TextNodePosition(offset: 0)));
    });

    test('Typing printable character on divider inserts paragraph with character', () {
      expect(document.nodeCount, equals(2));

      final instruction = handleDividerKeyboardActions(
        editContext: editContext,
        keyEvent: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: 'a',
          timeStamp: Duration.zero,
        ),
      );

      expect(instruction, equals(ExecutionInstruction.haltExecution));
      expect(document.nodeCount, equals(3));
      expect(document.getNodeAt(2), isA<ParagraphNode>());
      expect((document.getNodeAt(2) as ParagraphNode).text.toPlainText(), equals('a'));
      expect(composer.selection?.extent.nodeId, equals(document.getNodeAt(2)!.id));
      expect(composer.selection?.extent.nodePosition, equals(const TextNodePosition(offset: 1)));
    });

    test('ArrowDown on non-terminal divider continues execution to step to next node', () {
      // Add a node after the divider
      document.insertNodeAfter(
        existingNodeId: 'hr1',
        newNode: ParagraphNode(id: '3', text: AttributedText('Below')),
      );
      expect(document.nodeCount, equals(3));

      final instruction = handleDividerKeyboardActions(
        editContext: editContext,
        keyEvent: const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );

      expect(instruction, equals(ExecutionInstruction.continueExecution));
      // No extra paragraph inserted
      expect(document.nodeCount, equals(3));
    });
  });

  group('QuietDividerTapHandler Unit Tests', () {
    test('tapping terminal divider inserts an empty paragraph and places caret', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(id: '1', text: AttributedText('Above')),
        HorizontalRuleNode(id: 'hr1'),
      ]);
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final layout = _TestDocumentLayout(
        positionNearestOffset: const DocumentPosition(
          nodeId: 'hr1',
          nodePosition: UpstreamDownstreamNodePosition.downstream(),
        ),
      );
      final scroller = _TestScroller();

      final editContext = SuperEditorContext(
        editorFocusNode: focusNode,
        editor: editor,
        document: document,
        composer: composer,
        getDocumentLayout: () => layout,
        scroller: scroller,
        commonOps: CommonEditorOperations(
          editor: editor,
          document: document,
          composer: composer,
          documentLayoutResolver: () => layout,
        ),
      );

      final tapHandler = QuietDividerTapHandler(editContext: editContext);
      final result = tapHandler.onTap(
        DocumentTapDetails(
          documentLayout: layout,
          layoutOffset: const Offset(100, 50),
          globalOffset: const Offset(100, 50),
        ),
      );

      expect(result, equals(TapHandlingInstruction.halt));
      expect(document.nodeCount, equals(3));
      expect(document.getNodeAt(2), isA<ParagraphNode>());
      expect((document.getNodeAt(2) as ParagraphNode).text.toPlainText(), isEmpty);
      expect(composer.selection?.extent.nodeId, equals(document.getNodeAt(2)!.id));
      expect(composer.selection?.extent.nodePosition, equals(const TextNodePosition(offset: 0)));
    });
  });
}
