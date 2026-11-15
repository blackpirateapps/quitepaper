import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_block_node.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_inline_math.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_parser.dart';
import 'package:super_editor/super_editor.dart';

Future<void> mountEditor(
  WidgetTester tester,
  QuietSuperEditorController controller, {
  String markdown = '',
  ValueChanged<String>? onChanged,
  bool toolbar = false,
  FocusNode? focusNode,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              if (toolbar)
                FormattingToolbar(
                  controller: TextEditingController(),
                  superController: controller,
                  isTopDocked: true,
                  focusNode: focusNode,
                  onTagPressed: () {},
                ),
              Expanded(
                child: QuietSuperEditor(
                  controller: controller,
                  focusNode: focusNode,
                  initialMarkdown: markdown,
                  onChanged: onChanged ?? (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<QuietMathBlockNode> formulas(QuietSuperEditorController controller) =>
    controller.editor!.document.whereType<QuietMathBlockNode>().toList();

void selectText(
  QuietSuperEditorController controller,
  TextNode node,
  int offset,
) {
  controller.editor!.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset),
        ),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);
}

void main() {
  for (final path in ['load', 'controller paste', 'native paste']) {
    testWidgets('math and raw smart tables survive $path together', (
      tester,
    ) async {
      const table =
          '| A | B |\n| --- | --- |\n| 2 | =A2*3 |\n'
          '<!-- quiet-paper-table:v99 {"unknown":true} -->';
      const latex =
          r'a_i &= b_i * c_i'
          '\n\n'
          r'd_j &= \{x_j\}';
      const inline = r'Inline \(a_i * b_i\) after.';
      const source = 'Before\n\n\\[\n$latex\n\\]\n\n$table\n\n$inline\n\nTail';
      final controller = QuietSuperEditorController();
      var saved = '';
      await mountEditor(
        tester,
        controller,
        markdown: path == 'load' ? source : '',
        onChanged: (value) => saved = value,
      );
      if (path != 'load') {
        final first = controller.editor!.document.first as TextNode;
        selectText(controller, first, 0);
        if (path == 'controller paste') {
          controller.insertSnippet(source);
        } else {
          controller.editor!.execute([
            PasteEditorRequest(
              content: source,
              pastePosition: controller.composer!.selection!.extent,
            ),
          ]);
        }
        await tester.pumpAndSettle();
      }
      void expectContent() {
        final document = controller.editor!.document;
        expect(formulas(controller).single.latex, latex);
        expect(
          document
              .whereType<TableBlockNode>()
              .single
              .metadata[quietTableSourceKey],
          table,
        );
        expect(
          document.whereType<TextNode>().map((node) => node.text.toPlainText()),
          contains(inline),
        );
      }

      expectContent();
      final tail = controller.editor!.document.last as TextNode;
      selectText(controller, tail, tail.text.length);
      controller.insertSnippet(' edited');
      await tester.pumpAndSettle();
      expect(saved, contains(table));
      expect(saved, contains(latex));
      await tester.pumpWidget(const SizedBox());
      await mountEditor(tester, controller, markdown: saved);
      expectContent();
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'folding multiple inline formulas preserves offsets and surrounding styles',
    () {
      final text = AttributedText(r'Given $a_i$ and \(b_j\), finish.');
      text.addAttribution(
        boldAttribution,
        SpanRange(text.length - 7, text.length - 1),
      );
      final matches = QuietMathParser.findInlineMathMatches(text.toPlainText());
      final folded = foldInlineMathText(
        canonicalText: text,
        matches: matches,
        caretOffset: null,
      );
      expect(folded.length, text.length);
      expect(folded.placeholders.keys, matches.map((m) => m.start));
      expect(
        folded.toPlainText().replaceAll('\u200B', ''),
        'Given \uFFFC and \uFFFC, finish.',
      );
      expect(
        folded.hasAttributionAt(text.length - 1, attribution: boldAttribution),
        isTrue,
      );
    },
  );

  for (final prefix in ['', '- ', '1. ']) {
    testWidgets(
      'cursor after folded math keeps canonical offsets in "$prefix"',
      (tester) async {
        final controller = QuietSuperEditorController();
        var saved = '';
        const text = r'Given $a_i$ and \(b_j\), finish.';
        await mountEditor(
          tester,
          controller,
          markdown: '$prefix$text',
          onChanged: (value) => saved = value,
        );
        final node = controller.editor!.document.first as TextNode;
        final layout = controller.editor!.context
            .find<DocumentLayoutEditable>(Editor.layoutKey)
            .documentLayout;
        final component = layout.getComponentByNodeId(node.id)!;
        expect(
          (component.getEndPosition() as TextNodePosition).offset,
          node.text.length,
        );
        final endOffset = component.getOffsetForPosition(node.endPosition);
        final hit =
            component.getPositionAtOffset(endOffset) as TextNodePosition;
        expect(hit.offset, node.text.length);
        selectText(controller, node, hit.offset);
        controller.insertSnippet(' Added');
        await tester.pumpAndSettle();
        expect(
          (controller.editor!.document.getNodeById(node.id) as TextNode).text
              .toPlainText(),
          '$text Added',
        );
        expect(tester.takeException(), isNull);
        expect(saved, isNot(contains('\u200B')));
      },
    );
  }

  for (final markdown in [
    r'\[ x_i = \{y_i\} \]',
    r'$$ x_i = \{y_i\} $$',
    '```latex\nx_i = \\{y_i\\}\n```',
  ]) {
    testWidgets('native paste recognizes math in $markdown', (tester) async {
      final controller = QuietSuperEditorController();
      await mountEditor(tester, controller);
      final node = controller.editor!.document.first as TextNode;
      selectText(controller, node, 0);
      controller.editor!.execute([
        PasteEditorRequest(
          content: markdown,
          pastePosition: controller.composer!.selection!.extent,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(formulas(controller).single.latex, r'x_i = \{y_i\}');
      controller.undo();
      await tester.pumpAndSettle();
      expect(formulas(controller), isEmpty);
      controller.redo();
      await tester.pumpAndSettle();
      expect(formulas(controller).single.latex, r'x_i = \{y_i\}');
    });
  }

  testWidgets('display math preserves TeX and internal blank lines on load', (
    tester,
  ) async {
    final controller = QuietSuperEditorController();
    const latex =
        r'\begin{aligned}'
        '\n'
        r'a_i &= b_i * c_i \\'
        '\n\n'
        r'd_j &= \{x_j\} + \text{a * b * c}'
        '\n'
        r'\end{aligned}';
    await mountEditor(
      tester,
      controller,
      markdown: 'Before\n\\[\n$latex\n\\]\nAfter\n\$\$ x_i * y_i \$\$',
    );

    expect(formulas(controller).map((n) => n.latex), [latex, r'x_i * y_i']);
    expect(find.byType(QuietMathBlockComponent), findsNWidgets(2));
  });

  testWidgets(
    'editing a neighboring paragraph preserves multiline math on reload',
    (tester) async {
      final controller = QuietSuperEditorController();
      const latex =
          r'\begin{matrix} a_i & b_i \\'
          '\n\n'
          r'c_i & d_i \end{matrix}';
      var saved = '';
      await mountEditor(
        tester,
        controller,
        markdown: 'Before\n\$\$\n$latex\n\$\$\nAfter',
        onChanged: (value) => saved = value,
      );
      final after = controller.editor!.document.last as TextNode;
      selectText(controller, after, after.text.length);
      controller.insertSnippet(' edited');
      await tester.pumpAndSettle();
      expect(saved, contains(latex));
      expect(saved, isNot(contains('\u200B')));
      await tester.pumpWidget(const SizedBox());
      final reloaded = QuietSuperEditorController();
      await mountEditor(tester, reloaded, markdown: saved);
      expect(formulas(reloaded).single.latex, latex);
    },
  );

  testWidgets(
    'math menu keeps the insertion anchor when focus clears the selection',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final focus = FocusNode();
      final controller = QuietSuperEditorController();
      await mountEditor(
        tester,
        controller,
        markdown: 'First\n\nLast',
        toolbar: true,
        focusNode: focus,
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      final first = controller.editor!.document.first as TextNode;
      selectText(controller, first, first.text.length);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Insert Options (Table, Link, Media)'));
      await tester.pumpAndSettle();
      expect(controller.composer!.selection, isNull);
      await tester.tap(find.text('Math Formula'));
      await tester.pumpAndSettle();
      expect(
        controller.editor!.document.getNodeAt(1),
        isA<QuietMathBlockNode>(),
      );
      final input = find.descendant(
        of: find.byType(QuietMathBlockComponent),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    },
  );

  testWidgets(
    'math fence Enter creates a formula editor with a valid selection',
    (tester) async {
      final controller = QuietSuperEditorController();
      await mountEditor(tester, controller);
      final node = controller.editor!.document.first as TextNode;
      selectText(controller, node, 0);
      controller.insertSnippet(r'$$');
      controller.editor!.execute([InsertNewlineAtCaretRequest()]);
      await tester.pumpAndSettle();
      expect(formulas(controller), hasLength(1));
      expect(
        find.descendant(
          of: find.byType(QuietMathBlockComponent),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unfinished display delimiters leave subsequent paragraphs editable',
    (tester) async {
      final controller = QuietSuperEditorController();
      await mountEditor(
        tester,
        controller,
        markdown: '\\[\nUnfinished\n\nFollowing paragraph\n\n\$\$ x=1 \$\$',
      );
      expect(formulas(controller).single.latex, 'x=1');
      expect(
        controller.editor!.document.whereType<TextNode>().any(
          (node) => node.text.toPlainText() == 'Following paragraph',
        ),
        isTrue,
      );
    },
  );

  testWidgets('math pasted inside a code block stays literal', (tester) async {
    final controller = QuietSuperEditorController();
    await mountEditor(tester, controller, markdown: '```text\nexample\n```');
    final node = controller.editor!.document.first as TextNode;
    selectText(controller, node, node.text.length);
    controller.insertSnippet(r'\[ x_i = y_i \]');
    await tester.pumpAndSettle();
    expect(formulas(controller), isEmpty);
    expect(
      (controller.editor!.document.first as TextNode).text.toPlainText(),
      contains(r'\[ x_i = y_i \]'),
    );
  });

  testWidgets(
    'plus menu inserts an editable formula without a body selection',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = QuietSuperEditorController();
      await mountEditor(tester, controller, toolbar: true);
      expect(controller.composer!.selection, isNull);

      await tester.tap(find.byTooltip('Insert Options (Table, Link, Media)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math Formula'));
      await tester.pumpAndSettle();

      expect(formulas(controller), hasLength(1));
      final input = find.descendant(
        of: find.byType(QuietMathBlockComponent),
        matching: find.byType(TextField),
      );
      expect(input, findsOneWidget);
      await tester.enterText(input, r'E=mc^2');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(formulas(controller).single.latex, r'E=mc^2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'math paste survives blank paragraph deletion, history and reload',
    (tester) async {
      final controller = QuietSuperEditorController();
      var saved = '';
      await mountEditor(
        tester,
        controller,
        onChanged: (value) => saved = value,
      );
      controller.insertSnippet(
        'Intro\n\n\n\n\\[ x_i = \\frac{a_i}{b_i} \\]\n\n\n\nTail',
      );
      await tester.pumpAndSettle();
      expect(formulas(controller).single.latex, r'x_i = \frac{a_i}{b_i}');

      final document = controller.editor!.document;
      final tail = document.whereType<ParagraphNode>().lastWhere(
        (n) => n.text.toPlainText() == 'Tail',
      );
      selectText(controller, tail, 0);
      controller.editor!.execute([InsertNewlineAtCaretRequest()]);
      controller.editor!.execute([
        DeleteUpstreamAtBeginningOfNodeRequest(
          document.getNodeById(controller.selectedNodeId!)!,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(formulas(controller).single.latex, r'x_i = \frac{a_i}{b_i}');
      controller.undo();
      await tester.pumpAndSettle();
      expect(formulas(controller), hasLength(1));
      controller.redo();
      await tester.pumpAndSettle();
      expect(formulas(controller), hasLength(1));

      await tester.pumpWidget(const SizedBox());
      await mountEditor(tester, QuietSuperEditorController(), markdown: saved);
      expect(find.byType(QuietMathBlockComponent), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fenced math paste replaces the selected text', (tester) async {
    final controller = QuietSuperEditorController();
    await mountEditor(tester, controller, markdown: 'Replace me');
    final node = controller.editor!.document.first as TextNode;
    controller.composer!.setSelectionWithReason(
      DocumentSelection(
        base: DocumentPosition(
          nodeId: node.id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
        extent: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: node.text.length),
        ),
      ),
    );
    controller.insertSnippet('```math\na_i = b_i\n```');
    await tester.pumpAndSettle();
    expect(formulas(controller).single.latex, r'a_i = b_i');
    expect(
      controller.editor!.document.whereType<TextNode>().any(
        (n) => n.text.toPlainText().contains('Replace me'),
      ),
      isFalse,
    );
    controller.undo();
    await tester.pumpAndSettle();
    expect(formulas(controller), isEmpty);
    expect(
      (controller.editor!.document.first as TextNode).text.toPlainText(),
      'Replace me',
    );
    controller.redo();
    await tester.pumpAndSettle();
    expect(formulas(controller).single.latex, r'a_i = b_i');
  });

  testWidgets('math syntax inside ordinary code remains literal', (
    tester,
  ) async {
    final controller = QuietSuperEditorController();
    const code =
        r'\[ a_i * b_i \]'
        '\n'
        r'\(x_i\)'
        '\n'
        r'$$ y_i $$';
    await mountEditor(tester, controller, markdown: '```text\n$code\n```');
    expect(formulas(controller), isEmpty);
    final node = controller.editor!.document.whereType<ParagraphNode>().single;
    expect(node.text.toPlainText(), '$code\n');
    expect(node.metadata['language'], 'text');
  });
}
