import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_image_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioUri1 = 'qp://asset/11111111-1111-4111-8111-111111111111';
  const audioUri2 = 'qp://asset/22222222-2222-4222-8222-222222222222';

  group('Super Editor Audio Attachment & Markdown Tests', () {
    test('deserializes standalone audio asset link to QuietAttachmentNode', () {
      final markdown = '# Journal Entry\n\n'
          '[Morning Reflection]($audioUri1)\n\n'
          'Some thoughts after the meeting.';

      final doc = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(markdown));
      promoteQuietAttachmentNodes(doc);

      expect(doc.nodeCount, equals(3));
      expect(doc.getNodeAt(0), isA<ParagraphNode>());
      expect((doc.getNodeAt(0) as ParagraphNode).text.toPlainText(), equals('Journal Entry'));

      expect(doc.getNodeAt(1), isA<QuietAttachmentNode>());
      final audioNode = doc.getNodeAt(1) as QuietAttachmentNode;
      expect(audioNode.displayText, equals('Morning Reflection'));
      expect(audioNode.uri, equals(audioUri1));

      expect(doc.getNodeAt(2), isA<ParagraphNode>());
    });

    test('serializes QuietAttachmentNode back to Markdown link format', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('Before audio')),
        QuietAttachmentNode(
          id: 'a1',
          uri: audioUri1,
          displayText: 'Ideas for Quiet Paper',
        ),
        ParagraphNode(id: 'p2', text: AttributedText('After audio')),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietAttachmentNodeSerializer()],
      );

      expect(serialized, contains('Before audio'));
      expect(serialized, contains('[Ideas for Quiet Paper]($audioUri1)'));
      expect(serialized, contains('After audio'));
      // Verifies no temporary paths or binary leak
      expect(serialized, isNot(contains('/tmp/')));
      expect(serialized, isNot(contains('.m4a')));
    });

    test('consecutive audio blocks round trip cleanly', () {
      final markdown = '[First Memo]($audioUri1)\n\n'
          '[Second Memo]($audioUri2)';

      final doc = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(markdown));
      promoteQuietAttachmentNodes(doc);

      final audioNodes = doc.whereType<QuietAttachmentNode>().toList();
      expect(audioNodes.length, equals(2));
      expect(audioNodes[0].displayText, equals('First Memo'));
      expect(audioNodes[0].uri, equals(audioUri1));
      expect(audioNodes[1].displayText, equals('Second Memo'));
      expect(audioNodes[1].uri, equals(audioUri2));

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietAttachmentNodeSerializer()],
      );

      expect(serialized, contains('[First Memo]($audioUri1)'));
      expect(serialized, contains('[Second Memo]($audioUri2)'));
    });

    test('insertAttachment places QuietAttachmentNode at cursor', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('Intro note')),
        ParagraphNode(id: 'empty_p', text: AttributedText('')),
      ]);

      final composer = MutableDocumentComposer(
        initialSelection: DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: 'empty_p',
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
      );

      final editor = createDefaultDocumentEditor(
        document: doc,
        composer: composer,
      );

      final controller = QuietSuperEditorController();
      controller.attach(editor, composer);

      controller.insertAttachment(
        uri: audioUri1,
        displayText: 'Voice Memo · 10:30 AM',
      );

      final attachments = doc.whereType<QuietAttachmentNode>().toList();
      expect(attachments.length, equals(1));
      expect(attachments.first.displayText, equals('Voice Memo · 10:30 AM'));
      expect(attachments.first.uri, equals(audioUri1));

      // Replaces empty paragraph and adds trailing paragraph
      expect(doc.nodeCount, equals(3));
      expect(doc.getNodeAt(1), isA<QuietAttachmentNode>());
      expect(doc.getNodeAt(2), isA<ParagraphNode>());

      controller.dispose();
    });

    test('renaming node updates displayText without mutating URI or UUID', () {
      final doc = MutableDocument(nodes: [
        QuietAttachmentNode(
          id: 'audio_node_1',
          uri: audioUri1,
          displayText: 'Original Memo Name',
        ),
      ]);

      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(
        document: doc,
        composer: composer,
      );

      final existingNode = doc.getNodeById('audio_node_1') as QuietAttachmentNode;

      // Rename by replacing node
      editor.execute([
        ReplaceNodeRequest(
          existingNodeId: existingNode.id,
          newNode: QuietAttachmentNode(
            id: existingNode.id,
            uri: existingNode.uri,
            displayText: 'Renamed Memo',
          ),
        ),
      ]);

      final updatedNode = doc.getNodeById('audio_node_1') as QuietAttachmentNode;
      expect(updatedNode.displayText, equals('Renamed Memo'));
      expect(updatedNode.uri, equals(audioUri1));
    });
  });
}
