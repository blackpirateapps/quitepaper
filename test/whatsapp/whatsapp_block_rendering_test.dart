import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/editor/application/rich_document_serializer.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/whatsapp_chat_component.dart';
import 'package:quitepaper/features/whatsapp_formatter/domain/whatsapp_format_options.dart';
import 'package:quitepaper/features/whatsapp_formatter/presentation/widgets/whatsapp_chat_card.dart';
import 'package:quitepaper/features/whatsapp_formatter/presentation/widgets/whatsapp_conversation_preview.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Block Rendering & SuperEditor Block Tests', () {
    const rawChatMarkdown = '''
```whatsapp
[21/10, 11:04 pm] Sam 3: Yeshh
[21/10, 11:04 pm] Sam 3: That's so sexyyy
[21/10, 11:14 pm] BlackPirate: Shes goat
```
''';

    testWidgets('Markdown preview renders WhatsApp chat as full styled card with colors and dividers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuietMarkdownPreview(
                markdownData: rawChatMarkdown,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is rendered
      expect(find.byType(WhatsAppChatCard), findsOneWidget);
      expect(find.byType(WhatsAppConversationPreview), findsOneWidget);

      // Senders and messages are present
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('3 messages'), findsOneWidget);
      expect(find.text('Sam 3'), findsOneWidget);
      expect(find.text('BlackPirate'), findsOneWidget);
      expect(find.text('Yeshh'), findsOneWidget);
      expect(find.text('Shes goat'), findsOneWidget);

      // Verify terracotta / coral accent color on sender name
      final senderTextWidget = tester.widget<Text>(find.text('Sam 3'));
      expect(senderTextWidget.style?.color, equals(AppColors.light.accent));
      expect(senderTextWidget.style?.fontWeight, equals(FontWeight.w600));

      // Verify date divider is present
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('Markdown preview renders wrapped comment syntax <!-- qp-whatsapp:start -->', (tester) async {
      const wrappedMarkdown = '''
<!-- qp-whatsapp:start -->
[21/10, 11:04 pm] Sam 3: Yeshh
[21/10, 11:14 pm] BlackPirate: Shes goat
<!-- qp-whatsapp:end -->
''';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuietMarkdownPreview(
                markdownData: wrappedMarkdown,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WhatsAppChatCard), findsOneWidget);
      expect(find.text('Sam 3'), findsOneWidget);
      expect(find.text('BlackPirate'), findsOneWidget);
    });

    test('SuperEditor deserialization and promotion treats WhatsApp chat as a single BlockNode', () {
      final doc = deserializeMarkdownToDocument(rawChatMarkdown);
      expect(doc.nodeCount, equals(1));

      // Promote into WhatsAppChatNode
      promoteWhatsAppChatNodes(doc);
      expect(doc.nodeCount, equals(1));
      expect(doc.getNodeAt(0), isA<WhatsAppChatNode>());

      final chatNode = doc.getNodeAt(0) as WhatsAppChatNode;
      expect(chatNode.rawText, contains('Sam 3: Yeshh'));
      expect(chatNode.rawText, contains('BlackPirate: Shes goat'));

      // Serializes back cleanly to ```whatsapp
      const serializer = WhatsAppChatNodeSerializer();
      final serialized = serializer.doSerialization(doc, chatNode);
      expect(serialized, contains('```whatsapp'));
      expect(serialized, contains('Sam 3: Yeshh'));
      expect(serialized, contains('```'));
    });

    test('WYSIWYG RichDocument parses and serializes WhatsAppChatBlock cleanly', () {
      final richDoc = const RichDocumentParser().parse(rawChatMarkdown.trim());
      expect(richDoc.blocks.length, equals(1));
      expect(richDoc.blocks.first, isA<WhatsAppChatBlock>());

      final block = richDoc.blocks.first as WhatsAppChatBlock;
      expect(block.rawText, contains('Sam 3: Yeshh'));

      final serialized = const RichDocumentSerializer().serialize(richDoc);
      expect(serialized, contains('```whatsapp'));
      expect(serialized, contains('Sam 3: Yeshh'));
      expect(serialized, contains('```'));
    });

    test('WhatsAppChatBlock JSON roundtrip preservation', () {
      const block = WhatsAppChatBlock(
        id: 'chat-uuid-1',
        rawText: '[21/10, 11:04 pm] Sam: Hi',
        options: WhatsAppFormatOptions(showSenderNames: true, preserveTimestamps: false),
      );

      final json = block.toJson();
      final revived = RichBlock.fromJson(json);

      expect(revived, isA<WhatsAppChatBlock>());
      final revivedChat = revived as WhatsAppChatBlock;
      expect(revivedChat.id, equals('chat-uuid-1'));
      expect(revivedChat.rawText, equals('[21/10, 11:04 pm] Sam: Hi'));
      expect(revivedChat.options?.preserveTimestamps, isFalse);
    });
  });
}
