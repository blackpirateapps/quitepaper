import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';
import '../../../../whatsapp_formatter/application/whatsapp_parser.dart';
import '../../../../whatsapp_formatter/presentation/widgets/whatsapp_chat_card.dart';

/// A block [DocumentNode] that embeds a WhatsApp conversation as an editorial card
/// inside SuperEditor.
@immutable
class WhatsAppChatNode extends BlockNode {
  WhatsAppChatNode({
    required this.id,
    required this.rawText,
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution('whatsappChat')});
  }

  @override
  final String id;

  /// The raw or formatted WhatsApp chat content.
  final String rawText;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception(
        'WhatsAppChatNode can only copy content from a UpstreamDownstreamNodeSelection.',
      );
    }
    return !selection.isCollapsed ? '```whatsapp\n$rawText\n```' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is WhatsAppChatNode && rawText == other.rawText;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return WhatsAppChatNode(
      id: id,
      rawText: rawText,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return WhatsAppChatNode(
      id: id,
      rawText: rawText,
      metadata: newMetadata,
    );
  }

  WhatsAppChatNode copy() {
    return WhatsAppChatNode(
      id: id,
      rawText: rawText,
      metadata: Map.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppChatNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rawText == other.rawText;

  @override
  int get hashCode => id.hashCode ^ rawText.hashCode;
}

/// [ComponentBuilder] that renders [WhatsAppChatNode]s as an embedded card inside SuperEditor.
class WhatsAppChatComponentBuilder implements ComponentBuilder {
  WhatsAppChatComponentBuilder({
    required this.editor,
    this.showRemove = true,
  });

  final Editor editor;
  final bool showRemove;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! WhatsAppChatNode) {
      return null;
    }

    return WhatsAppChatComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      rawText: node.rawText,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! WhatsAppChatComponentViewModel) {
      return null;
    }

    final node = editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! WhatsAppChatNode) {
      return null;
    }

    return WhatsAppChatComponent(
      key: ValueKey('whatsapp_chat_${componentViewModel.nodeId}'),
      componentKey: componentContext.componentKey,
      node: node,
      editor: editor,
      showRemove: showRemove,
    );
  }
}

/// View model backing a [WhatsAppChatComponent].
class WhatsAppChatComponentViewModel extends SingleColumnLayoutComponentViewModel {
  WhatsAppChatComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.rawText,
  });

  String rawText;

  @override
  WhatsAppChatComponentViewModel copy() {
    return WhatsAppChatComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      rawText: rawText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is WhatsAppChatComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          rawText == other.rawText;

  @override
  int get hashCode => Object.hash(super.hashCode, nodeId, rawText);
}

/// A document component rendering [WhatsAppChatNode] as [WhatsAppChatCard] inside SuperEditor.
class WhatsAppChatComponent extends ConsumerStatefulWidget {
  const WhatsAppChatComponent({
    super.key,
    required this.componentKey,
    required this.node,
    required this.editor,
    this.showRemove = true,
  });

  final GlobalKey componentKey;
  final WhatsAppChatNode node;
  final Editor editor;
  final bool showRemove;

  @override
  ConsumerState<WhatsAppChatComponent> createState() => _WhatsAppChatComponentState();
}

class _WhatsAppChatComponentState extends ConsumerState<WhatsAppChatComponent> {
  void _remove() {
    widget.editor.execute([
      DeleteNodeRequest(nodeId: widget.node.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return BoxComponent(
      key: widget.componentKey,
      child: WhatsAppChatCard(
        source: widget.node.rawText,
        readOnly: !widget.showRemove,
        onRemove: widget.showRemove ? _remove : null,
      ),
    );
  }
}

/// Serializes [WhatsAppChatNode] back to standard Markdown code block with language `whatsapp`.
class WhatsAppChatNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<WhatsAppChatNode> {
  const WhatsAppChatNodeSerializer();

  @override
  String doSerialization(
    Document document,
    WhatsAppChatNode node, {
    NodeSelection? selection,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('```whatsapp');
    buffer.writeln(node.rawText.trim());
    buffer.write('```');

    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// Scans [document] and promotes any code paragraphs or sentinel-wrapped blocks
/// containing WhatsApp conversations into [WhatsAppChatNode]s.
void promoteWhatsAppChatNodes(MutableDocument document) {
  final nodes = document.toList();
  final promotions = <({String nodeId, String rawText, List<String> absorbedIds})>[];

  // 1. Scan for code blocks containing WhatsApp chats or language whatsapp
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    if (node is! ParagraphNode) continue;

    final blockType = node.getMetadataValue(NodeMetadata.blockType);
    final isCode = blockType is NamedAttribution && blockType.id == 'code';
    final text = node.text.toPlainText().trim();

    if (isCode) {
      if (WhatsAppParser.isWhatsAppChat(text) ||
          text.contains('### ') ||
          text.contains('**') ||
          text.startsWith('{"') ||
          text.startsWith('<!-- qp-options:')) {
        promotions.add((
          nodeId: node.id,
          rawText: text,
          absorbedIds: const [],
        ));
        continue;
      }
    }

    // Check for comment wrapper: <!-- qp-whatsapp:start -->
    if (text.startsWith('<!-- qp-whatsapp:start') || text.startsWith('<!-- qp-whatsapp-chat:start')) {
      final absorbedIds = <String>[];
      final buffer = StringBuffer();
      int j = i + 1;
      while (j < nodes.length) {
        final nextNode = nodes[j];
        if (nextNode is ParagraphNode) {
          final nextText = nextNode.text.toPlainText().trim();
          absorbedIds.add(nextNode.id);
          if (nextText.startsWith('<!-- qp-whatsapp:end') || nextText.startsWith('<!-- qp-whatsapp-chat:end')) {
            break;
          }
          buffer.writeln(nextNode.text.toPlainText());
        }
        j++;
      }
      promotions.add((
        nodeId: node.id,
        rawText: buffer.toString().trim(),
        absorbedIds: absorbedIds,
      ));
      i = j;
    }
  }

  for (final promo in promotions) {
    document.replaceNodeById(
      promo.nodeId,
      WhatsAppChatNode(
        id: promo.nodeId,
        rawText: promo.rawText,
      ),
    );
    for (final absorbedId in promo.absorbedIds) {
      document.deleteNode(absorbedId);
    }
  }
}
