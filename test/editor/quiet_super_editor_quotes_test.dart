import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/quiet_super_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_blockquote_component.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:super_editor/super_editor.dart';

class _MockTypographyNotifier extends TypographySettingsNotifier {
  _MockTypographyNotifier(TypographySettings settings) : super(null) {
    state = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuietBlockquoteComponentBuilder Unit Tests', () {
    const builder = QuietBlockquoteComponentBuilder();

    test('ignores non-paragraph and non-blockquote nodes', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('Regular paragraph')),
        HorizontalRuleNode(id: 'hr1'),
      ]);

      expect(builder.createViewModel(document, document.getNodeAt(0)!), isNull);
      expect(builder.createViewModel(document, document.getNodeAt(1)!), isNull);
    });

    test('correctly sets isFirstInBlock and isLastInBlock for single blockquote', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('Normal before')),
        ParagraphNode(
          id: 'q1',
          text: AttributedText('Single quote'),
          metadata: const {'blockType': blockquoteAttribution},
        ),
        ParagraphNode(id: 'p2', text: AttributedText('Normal after')),
      ]);

      final vm = builder.createViewModel(document, document.getNodeAt(1)!) as QuietBlockquoteComponentViewModel?;
      expect(vm, isNotNull);
      expect(vm!.isFirstInBlock, isTrue);
      expect(vm.isLastInBlock, isTrue);
    });

    test('correctly sets boundary flags across contiguous blockquote run', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(
          id: 'q1',
          text: AttributedText('First quote line'),
          metadata: const {'blockType': blockquoteAttribution},
        ),
        ParagraphNode(
          id: 'q2',
          text: AttributedText('Middle quote line'),
          metadata: const {'blockType': blockquoteAttribution},
        ),
        ParagraphNode(
          id: 'q3',
          text: AttributedText('Last quote line'),
          metadata: const {'blockType': blockquoteAttribution},
        ),
      ]);

      final vm1 = builder.createViewModel(document, document.getNodeAt(0)!) as QuietBlockquoteComponentViewModel?;
      final vm2 = builder.createViewModel(document, document.getNodeAt(1)!) as QuietBlockquoteComponentViewModel?;
      final vm3 = builder.createViewModel(document, document.getNodeAt(2)!) as QuietBlockquoteComponentViewModel?;

      expect(vm1!.isFirstInBlock, isTrue);
      expect(vm1.isLastInBlock, isFalse);

      expect(vm2!.isFirstInBlock, isFalse);
      expect(vm2.isLastInBlock, isFalse);

      expect(vm3!.isFirstInBlock, isFalse);
      expect(vm3.isLastInBlock, isTrue);
    });
  });

  group('QuietBlockquotePlugin Command Tests', () {
    test('non-empty blockquote continues with blockquote attribution on newline', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(
          id: 'q1',
          text: AttributedText('Line one'),
          metadata: const {'blockType': blockquoteAttribution},
        ),
      ]);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'q1',
            nodePosition: TextNodePosition(offset: 8),
          ),
        ),
      );
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: composer,
      );

      final plugin = QuietBlockquotePlugin();
      plugin.attach(editor);

      editor.execute([
        InsertNewlineAtCaretRequest('q2'),
      ]);

      expect(document.nodeCount, equals(2));
      final node1 = document.getNodeAt(0) as ParagraphNode;
      final node2 = document.getNodeAt(1) as ParagraphNode;

      expect(node1.getMetadataValue('blockType'), equals(blockquoteAttribution));
      expect(node2.getMetadataValue('blockType'), equals(blockquoteAttribution));
      expect(node1.text.toPlainText(), equals('Line one'));
      expect(node2.text.toPlainText(), isEmpty);
      expect(composer.selection!.extent.nodeId, equals('q2'));
      expect((composer.selection!.extent.nodePosition as TextNodePosition).offset, equals(0));
    });

    test('empty blockquote converts to standard paragraph on newline', () {
      final document = MutableDocument(nodes: [
        ParagraphNode(
          id: 'q1',
          text: AttributedText(''),
          metadata: const {'blockType': blockquoteAttribution},
        ),
      ]);
      final composer = MutableDocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'q1',
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: composer,
      );

      final plugin = QuietBlockquotePlugin();
      plugin.attach(editor);

      editor.execute([
        InsertNewlineAtCaretRequest('q2'),
      ]);

      expect(document.nodeCount, equals(1));
      final node = document.getNodeAt(0) as ParagraphNode;
      expect(node.getMetadataValue('blockType'), isNot(equals(blockquoteAttribution)));
      expect(node.getMetadataValue('blockType'), equals(paragraphAttribution));
    });
  });

  group('QuietSuperEditor Blockquote Widget Tests', () {
    Widget buildTestWidget({
      required String markdown,
      required ValueChanged<String> onChanged,
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
            ),
          ),
        ),
      );
    }

    testWidgets('renders QuietBlockquoteComponent with 3.5px accent bar', (tester) async {
      const markdown = '> She loathes everybody and everything that reminds of her past.\n\n'
          '> The lady and her pet dog that went missing were recovered.';

      await tester.pumpWidget(
        buildTestWidget(
          markdown: markdown,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final quoteFinder = find.byType(QuietBlockquoteComponent);
      expect(quoteFinder, findsNWidgets(2));

      // Verify CustomPaint with accent bar is present in both components
      final customPaintFinder = find.descendant(
        of: quoteFinder.first,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsWidgets);

      // Verify text rendered
      expect(find.text('She loathes everybody and everything that reminds of her past.', findRichText: true), findsOneWidget);
      expect(find.text('The lady and her pet dog that went missing were recovered.', findRichText: true), findsOneWidget);
    });
  });
}
