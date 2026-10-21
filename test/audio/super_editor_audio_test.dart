import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/audio/application/audio_transcript_markdown_helper.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_attachment_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_image_component.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

class _TestAppDatabase implements AppDatabase {
  @override
  Future<AttachmentEntity?> getAttachment(String id) async => AttachmentEntity(
        id: id,
        fileName: 'recording.m4a',
        mimeType: 'audio/mp4',
        byteSize: 100,
        sha256: 'abc',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAttachmentService implements AttachmentService {
  _TestAttachmentService({this.onDelete});
  final void Function(String id)? onDelete;

  @override
  final AppDatabase database = _TestAppDatabase();

  @override
  Future<void> deleteAttachment(String assetId, {bool enqueueSync = true}) async {
    onDelete?.call(assetId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

    test('serializes and deserializes QuietAttachmentNode with transcript', () {
      final doc = MutableDocument(nodes: [
        QuietAttachmentNode(
          id: 'audio1',
          uri: audioUri1,
          displayText: 'Audio: 2026-04-19 14:32',
          transcript: 'First line of spoken audio.\nSecond line of spoken audio.',
          transcriptLanguage: 'en',
          isTranscriptEdited: false,
        ),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietAttachmentNodeSerializer()],
      );

      expect(serialized, contains('[Audio: 2026-04-19 14:32]($audioUri1?transcript=1&lang=en&edited=0)'));
      expect(serialized, contains('> First line of spoken audio.'));
      expect(serialized, contains('> Second line of spoken audio.'));

      // Now deserialize back
      final deserialized = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized));
      promoteQuietAttachmentNodes(deserialized);

      expect(deserialized.nodeCount, equals(1));
      final node = deserialized.first as QuietAttachmentNode;
      expect(node.displayText, equals('Audio: 2026-04-19 14:32'));
      expect(node.uri, equals(audioUri1));
      expect(node.transcript, equals('First line of spoken audio.\nSecond line of spoken audio.'));
      expect(node.transcriptLanguage, equals('en'));
      expect(node.isTranscriptEdited, isFalse);
    });

    test('serializes and deserializes manually edited transcript (edited=1)', () {
      final doc = MutableDocument(nodes: [
        QuietAttachmentNode(
          id: 'audio1',
          uri: audioUri1,
          displayText: 'Audio: 2026-04-19 14:32',
          transcript: 'User corrected transcript line.',
          transcriptLanguage: 'en',
          isTranscriptEdited: true,
        ),
      ]);

      final serialized = serializeDocumentToMarkdown(
        doc,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [QuietAttachmentNodeSerializer()],
      );

      expect(serialized, contains('[Audio: 2026-04-19 14:32]($audioUri1?transcript=1&lang=en&edited=1)'));
      expect(serialized, contains('> User corrected transcript line.'));

      final deserialized = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(serialized));
      promoteQuietAttachmentNodes(deserialized);

      expect(deserialized.nodeCount, equals(1));
      final node = deserialized.first as QuietAttachmentNode;
      expect(node.transcript, equals('User corrected transcript line.'));
      expect(node.isTranscriptEdited, isTrue);
    });

    test('deserializes multiple consecutive audio blocks with transcripts', () {
      final markdown = '[First Memo]($audioUri1?transcript=1&lang=en&edited=0)\n'
          '> Audio one transcript.\n\n'
          '[Second Memo]($audioUri2?transcript=1&lang=es&edited=1)\n'
          '> Audio dos transcripción.';

      final doc = deserializeMarkdownToDocument(normalizeMarkdownForSuperEditor(markdown));
      promoteQuietAttachmentNodes(doc);

      final audioNodes = doc.whereType<QuietAttachmentNode>().toList();
      expect(audioNodes.length, equals(2));
      expect(audioNodes[0].displayText, equals('First Memo'));
      expect(audioNodes[0].uri, equals(audioUri1));
      expect(audioNodes[0].transcript, equals('Audio one transcript.'));
      expect(audioNodes[0].transcriptLanguage, equals('en'));
      expect(audioNodes[0].isTranscriptEdited, isFalse);

      expect(audioNodes[1].displayText, equals('Second Memo'));
      expect(audioNodes[1].uri, equals(audioUri2));
      expect(audioNodes[1].transcript, equals('Audio dos transcripción.'));
      expect(audioNodes[1].transcriptLanguage, equals('es'));
      expect(audioNodes[1].isTranscriptEdited, isTrue);
    });

    test('Visual mode RichDocumentParser and RichDocumentSerializer round trip with transcript', () {
      final markdown = '# Note With Voice\n\n'
          '[Audio Journal]($audioUri1?transcript=1&lang=en&edited=1)\n'
          '> Captured reflection here.\n'
          '> Second sentence.\n\n'
          'Final paragraph.';

      final doc = const RichDocumentParser().parse(markdown);
      final audioBlock = doc.blocks.whereType<AttachmentBlock>().first;
      expect(audioBlock.name, equals('Audio Journal'));
      expect(audioBlock.uri, equals(audioUri1));
      expect(audioBlock.transcript, equals('Captured reflection here.\nSecond sentence.'));
      expect(audioBlock.transcriptLanguage, equals('en'));
      expect(audioBlock.isTranscriptEdited, isTrue);

      final reserialized = const RichDocumentSerializer().serialize(doc);
      expect(reserialized, contains('[Audio Journal]($audioUri1?transcript=1&lang=en&edited=1)'));
      expect(reserialized, contains('> Captured reflection here.'));
      expect(reserialized, contains('> Second sentence.'));

      // Round-trip parse again
      final doc2 = const RichDocumentParser().parse(reserialized);
      final audioBlock2 = doc2.blocks.whereType<AttachmentBlock>().first;
      expect(audioBlock2.name, equals('Audio Journal'));
      expect(audioBlock2.transcript, equals('Captured reflection here.\nSecond sentence.'));
      expect(audioBlock2.isTranscriptEdited, isTrue);
    });

    test('AudioTranscriptMarkdownHelper preview blockquote stripper removes companion blockquotes', () {
      final markdown = '# Meeting Notes\n\n'
          '[Audio Memo]($audioUri1?transcript=1&lang=en&edited=0)\n'
          '> Transcript line 1\n'
          '> Transcript line 2\n\n'
          '> Standalone user blockquote\n\n'
          'Body text';

      final stripped = AudioTranscriptMarkdownHelper.stripTranscriptBlockquotesForPreview(markdown);
      expect(stripped, contains('[Audio Memo]($audioUri1?transcript=1&lang=en&edited=0)'));
      expect(stripped, isNot(contains('> Transcript line 1')));
      expect(stripped, isNot(contains('> Transcript line 2')));
      expect(stripped, contains('> Standalone user blockquote'));
      expect(stripped, contains('Body text'));
    });

    testWidgets('clicking cross on QuietAttachmentComponent deletes node and calls deleteAttachment on AttachmentService', (tester) async {
      String? deletedAssetId;
      final mockAttachmentService = _TestAttachmentService(onDelete: (id) => deletedAssetId = id);

      final doc = MutableDocument(nodes: [
        QuietAttachmentNode(
          id: 'audio_node_1',
          uri: audioUri1,
          displayText: 'Audio Recording',
        ),
      ]);
      final editor = createDefaultDocumentEditor(document: doc, composer: MutableDocumentComposer());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentServiceProvider.overrideWithValue(mockAttachmentService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuietAttachmentComponent(
                componentKey: GlobalKey(),
                node: doc.getNodeAt(0) as QuietAttachmentNode,
                editor: editor,
                showRemove: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(PhosphorIconsRegular.x), findsOneWidget);

      await tester.tap(find.byIcon(PhosphorIconsRegular.x));
      await tester.pump();

      expect(doc.nodeCount, equals(0));
      expect(deletedAssetId, equals('11111111-1111-4111-8111-111111111111'));
    });

    testWidgets('clicking remove button on RichAttachmentBlock calls deleteAttachment on AttachmentService', (tester) async {
      String? deletedAssetId;
      final mockAttachmentService = _TestAttachmentService(onDelete: (id) => deletedAssetId = id);

      final block = AttachmentBlock(
        id: 'b1',
        uri: audioUri1,
        name: 'Voice Memo',
        kind: AttachmentBlockKind.file,
      );
      final doc = RichDocument(blocks: [block]);
      final controller = RichDocumentController(
        initialMarkdown: const RichDocumentSerializer().serialize(doc),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attachmentServiceProvider.overrideWithValue(mockAttachmentService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RichAttachmentBlock(
                block: block,
                blockIndex: 0,
                controller: controller,
                readOnly: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      expect(deletedAssetId, equals('11111111-1111-4111-8111-111111111111'));
    });
  });
}
