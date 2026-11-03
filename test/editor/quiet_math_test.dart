import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_inline_math.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_block_node.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/math/quiet_math_parser.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_code_block_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_image_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_link_preview_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_table_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_task_component.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('QuietMathParser', () {
    test('parses single-line bracket block math', () {
      final parsed = QuietMathParser.parseBlockMath(r'\[ S_{17}=\frac{17}{2}(3+99) \]');
      expect(parsed, isNotNull);
      expect(parsed!.delimiterType, MathDelimiterType.brackets);
      expect(parsed.latex, r'S_{17}=\frac{17}{2}(3+99)');
    });

    test('parses single-line dollar block math', () {
      final parsed = QuietMathParser.parseBlockMath(r'$$ x = \frac{-b \pm \sqrt{b^2-4ac}}{2a} $$');
      expect(parsed, isNotNull);
      expect(parsed!.delimiterType, MathDelimiterType.dollars);
      expect(parsed.latex, r'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}');
    });

    test('parses multi-line block math', () {
      final text = "\\[\nS_{17}=\\frac{17}{2}(3+99)\n\\]";
      final parsed = QuietMathParser.parseBlockMath(text);
      expect(parsed, isNotNull);
      expect(parsed!.delimiterType, MathDelimiterType.brackets);
      expect(parsed.latex, r'S_{17}=\frac{17}{2}(3+99)');
    });

    test('repairs legacy CommonMark escaped underscores and asterisks', () {
      final corrupted = r'\[ S\_{17}=\frac{17}{2}(3+99) \times 102\*2 \]';
      final parsed = QuietMathParser.parseBlockMath(corrupted);
      expect(parsed, isNotNull);
      expect(parsed!.latex, r'S_{17}=\frac{17}{2}(3+99) \times 102*2');
    });

    test('finds inline math matches for \\( ... \\) and \$ ... \$', () {
      const line = r'Given \(n=17\) and $a=3$, compute \(l=99\)';
      final matches = QuietMathParser.findInlineMathMatches(line);
      expect(matches.length, 3);

      expect(matches[0].latex, 'n=17');
      expect(matches[0].isBracket, isTrue);

      expect(matches[1].latex, 'a=3');
      expect(matches[1].isBracket, isFalse);

      expect(matches[2].latex, 'l=99');
      expect(matches[2].isBracket, isTrue);
    });

    test('does not parse plain non-math dollar signs or brackets', () {
      expect(QuietMathParser.parseBlockMath('Just a normal paragraph [1]'), isNull);
      expect(QuietMathParser.parseBlockMath('It costs \$50 and \$100'), isNull);
    });
  });

  group('QuietMathBlockNode & Serialization', () {
    test('serializes bracket math block without escaping underscores or asterisks', () {
      final doc = MutableDocument(nodes: [
        QuietMathBlockNode(
          id: '1',
          latex: r'S_{17}=\frac{17}{2}(3+99)',
          delimiterType: MathDelimiterType.brackets,
        ),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietMathBlockNodeSerializer()],
      );

      expect(serialized, contains(r'\[ S_{17}=\frac{17}{2}(3+99) \]'));
      expect(serialized, isNot(contains(r'S\_')));
    });

    test('serializes dollar math block cleanly', () {
      final doc = MutableDocument(nodes: [
        QuietMathBlockNode(
          id: '1',
          latex: r'\boxed{867}',
          delimiterType: MathDelimiterType.dollars,
        ),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietMathBlockNodeSerializer()],
      );

      expect(serialized, contains(r'$$ \boxed{867} $$'));
    });

    test('serializes fenced codeBlock math', () {
      final doc = MutableDocument(nodes: [
        QuietMathBlockNode(
          id: '1',
          latex: r'E = mc^2',
          delimiterType: MathDelimiterType.codeFence,
        ),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietMathBlockNodeSerializer()],
      );

      expect(serialized, contains("```math\nE = mc^2\n```"));
    });
  });

  group('Roundtrip & Promotion: Screenshot Content', () {
    test('promotes and roundtrips the exact user screenshot note without losing or corrupting math', () {
      const userMarkdown = '''- \\(n=17\\)
- \\(a=3\\)
- \\(l=99\\)

\\[ S_{17}=\\frac{17}{2}(3+99) \\]

\\[ =\\frac{17}{2}\\times102 \\]

\\[ =17\\times51 \\]

\\[ \\boxed{867} \\]''';

      final normalized = normalizeMarkdownForSuperEditor(userMarkdown);
      final document = deserializeMarkdownToDocument(normalized);

      // Promotion pass
      promoteQuietMathBlockNodes(document);

      // Verify node types
      // First 3 should be ListItemNodes
      expect(document.getNodeAt(0), isA<ListItemNode>());
      expect(document.getNodeAt(1), isA<ListItemNode>());
      expect(document.getNodeAt(2), isA<ListItemNode>());

      // Remaining 4 should be QuietMathBlockNodes
      expect(document.getNodeAt(3), isA<QuietMathBlockNode>());
      expect(document.getNodeAt(4), isA<QuietMathBlockNode>());
      expect(document.getNodeAt(5), isA<QuietMathBlockNode>());
      expect(document.getNodeAt(6), isA<QuietMathBlockNode>());

      final mathNode1 = document.getNodeAt(3) as QuietMathBlockNode;
      expect(mathNode1.latex, r'S_{17}=\frac{17}{2}(3+99)');

      final mathNode4 = document.getNodeAt(6) as QuietMathBlockNode;
      expect(mathNode4.latex, r'\boxed{867}');

      // Serialize back to Markdown
      final serialized = serializeDocumentToMarkdown(
        document,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [
          QuietTaskNodeSerializer(),
          QuietImageNodeSerializer(),
          QuietAttachmentNodeSerializer(),
          LinkPreviewNodeSerializer(),
          QuietTableBlockNodeSerializer(),
          QuietCodeBlockNodeSerializer(),
          QuietMathBlockNodeSerializer(),
        ],
      );

      // Verify clean LaTeX roundtrip: no backslash before underscore!
      expect(serialized, contains(r'S_{17}'));
      expect(serialized, isNot(contains(r'S\_')));
      expect(serialized, contains(r'\boxed{867}'));
      expect(serialized, contains(r'\(n=17\)'));
    });

    test('recovers legacy corrupted notes where underscores were escaped as \\_', () {
      const corruptedMarkdown = r'\[ S\_{17}=\frac{17}{2}(3+99) \]';
      final normalized = normalizeMarkdownForSuperEditor(corruptedMarkdown);
      final document = deserializeMarkdownToDocument(normalized);
      promoteQuietMathBlockNodes(document);

      expect(document.first, isA<QuietMathBlockNode>());
      final mathNode = document.first as QuietMathBlockNode;
      expect(mathNode.latex, r'S_{17}=\frac{17}{2}(3+99)');
    });
  });

  group('Inline Math Folding', () {
    test('folds inactive inline math into placeholder when caret is outside', () {
      final rawText = AttributedText(r'Here is \(n=17\) in a sentence');
      final matches = QuietMathParser.findInlineMathMatches(rawText.toPlainText());

      // Caret is at offset 0 (outside the formula)
      final folded = foldInlineMathText(
        canonicalText: rawText,
        matches: matches,
        caretOffset: 0,
      );

      expect(folded.toPlainText(), 'Here is \uFFFC in a sentence');
      expect(folded.placeholders.containsKey(8), isTrue);
      final placeholder = folded.placeholders[8] as InlineMathPlaceholder;
      expect(placeholder.latex, 'n=17');
    });

    test('unfolds active inline math when caret is placed inside the formula', () {
      final rawText = AttributedText(r'Here is \(n=17\) in a sentence');
      final matches = QuietMathParser.findInlineMathMatches(rawText.toPlainText());

      // Caret is at offset 12 (inside `\(n=17\)`)
      final unfolded = foldInlineMathText(
        canonicalText: rawText,
        matches: matches,
        caretOffset: 12,
      );

      // When active, text remains raw so user can edit characters
      expect(unfolded.toPlainText(), r'Here is \(n=17\) in a sentence');
      expect(unfolded.placeholders.isEmpty, isTrue);
    });
  });

  group('QuietMathBlockComponent Widget Tests', () {
    testWidgets('renders LaTeX formula in display mode', (tester) async {
      final doc = MutableDocument(nodes: [
        QuietMathBlockNode(
          id: 'math1',
          latex: r'S_{17}=\frac{17}{2}(3+99)',
          delimiterType: MathDelimiterType.brackets,
        ),
      ]);
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: doc, composer: composer);

      final viewModel = QuietMathBlockComponentViewModel(
        nodeId: 'math1',
        latex: r'S_{17}=\frac{17}{2}(3+99)',
        delimiterType: MathDelimiterType.brackets,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuietMathBlockComponent(
                key: const ValueKey('component_key'),
                viewModel: viewModel,
                editor: editor,
                node: doc.getNodeAt(0) as QuietMathBlockNode,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Default state shows delimiter label
      expect(find.text(r'\[ \]'), findsOneWidget);

      // Tapping the card opens Edit Mode
      await tester.tap(find.byType(QuietMathBlockComponent));
      await tester.pumpAndSettle();

      // Edit Mode displays the TextField and Done button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Entering new text and tapping Done commits the update
      await tester.enterText(find.byType(TextField), r'\boxed{867}');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Node in editor document updated
      final updatedNode = doc.getNodeAt(0) as QuietMathBlockNode;
      expect(updatedNode.latex, r'\boxed{867}');
    });
  });

  group('QuietSuperEditor Widget Integration', () {
    testWidgets('loads and renders notes with math syntax', (tester) async {
      const markdown = '''- \\(n=17\\)
- \\(a=3\\)

\\[ S_{17}=\\frac{17}{2}(3+99) \\]''';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuietSuperEditor(
                initialMarkdown: markdown,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Editor should render with QuietMathBlockComponent
      expect(find.byType(QuietMathBlockComponent), findsOneWidget);
    });
  });
}
