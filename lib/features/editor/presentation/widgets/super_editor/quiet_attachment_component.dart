import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_attachment_card.dart';
import 'package:quitepaper/core/documents/presentation/quiet_document_card.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

/// A block [DocumentNode] that embeds a Quiet Paper document or generic file
/// attachment as a rich card inside SuperEditor.
///
/// Unlike [ImageNode] (which is reserved for `![alt](url)` image syntax), this
/// node represents a *link-form* reference — `[name](qp://document/<UUID>)` or
/// `[name](qp://asset/<UUID>)` — and always serializes back to that exact link
/// form (see [QuietAttachmentNodeSerializer]). That keeps the persisted
/// Markdown byte-compatible with the Markdown preview, cloud sync, and the
/// other editor surfaces.
@immutable
class QuietAttachmentNode extends BlockNode {
  QuietAttachmentNode({
    required this.id,
    required this.uri,
    required this.displayText,
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution('quietAttachment')});
  }

  @override
  final String id;

  /// The canonical `qp://document/<UUID>` or `qp://asset/<UUID>` URI.
  final String uri;

  /// The Markdown link display text (e.g. the document title or file name).
  final String displayText;

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception(
        'QuietAttachmentNode can only copy content from a UpstreamDownstreamNodeSelection.',
      );
    }
    return !selection.isCollapsed ? '[$displayText]($uri)' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is QuietAttachmentNode && uri == other.uri && displayText == other.displayText;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      metadata: newMetadata,
    );
  }

  QuietAttachmentNode copy() {
    return QuietAttachmentNode(
      id: id,
      uri: uri,
      displayText: displayText,
      metadata: Map.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietAttachmentNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri &&
          displayText == other.displayText;

  @override
  int get hashCode => id.hashCode ^ uri.hashCode ^ displayText.hashCode;
}

/// Block type ids that must never be promoted to an attachment card even when
/// their text happens to be a single link (headings, quotes, code blocks).
const Set<String> _nonPromotableBlockTypes = {
  'header1',
  'header2',
  'header3',
  'header4',
  'header5',
  'header6',
  'blockquote',
  'code',
};

/// Returns the sole whole-paragraph `qp://document|asset` link in [node], or
/// `null` if [node] is not a plain paragraph consisting of exactly one such
/// link. Used to decide whether a deserialized paragraph should become an
/// embedded attachment card.
({String uri, String text})? _soleQuietLinkOf(ParagraphNode node) {
  final blockType = node.getMetadataValue(NodeMetadata.blockType);
  if (blockType is NamedAttribution && _nonPromotableBlockTypes.contains(blockType.id)) {
    return null;
  }

  final plain = node.text.toPlainText();
  if (plain.trim().isEmpty) return null;

  final spans = node.text.getAttributionSpansByFilter((a) => a is LinkAttribution);
  if (spans.length != 1) return null;

  final span = spans.first;
  // The link must cover the whole paragraph (end offset is inclusive).
  if (span.start != 0 || span.end != plain.length - 1) return null;

  final link = span.attribution as LinkAttribution;
  final qp = QuietPaperUri.tryParse(link.plainTextUri);
  if (qp == null || !(qp.isDocument || qp.isAsset)) return null;

  return (uri: link.plainTextUri, text: plain);
}

/// Walks [document] and replaces every paragraph that is exactly a single
/// `[name](qp://document|asset/<UUID>)` link with a [QuietAttachmentNode], so
/// link-form documents and generic files render as embedded cards instead of
/// inline hyperlinks. Image-syntax references (`![alt](qp://asset/...)`) are
/// left as [ImageNode]s and handled by the image component.
void promoteQuietAttachmentNodes(MutableDocument document) {
  final swaps = <({String id, String uri, String text})>[];
  for (final node in document) {
    if (node is! ParagraphNode) continue;
    final link = _soleQuietLinkOf(node);
    if (link == null) continue;
    swaps.add((id: node.id, uri: link.uri, text: link.text));
  }

  for (final swap in swaps) {
    document.replaceNodeById(
      swap.id,
      QuietAttachmentNode(id: swap.id, uri: swap.uri, displayText: swap.text),
    );
  }
}

/// [ComponentBuilder] that renders [QuietAttachmentNode]s as embedded document
/// or file cards with a "remove from note" affordance.
class QuietAttachmentComponentBuilder implements ComponentBuilder {
  QuietAttachmentComponentBuilder({
    required this.editor,
    this.noteId,
    this.showRemove = true,
  });

  final Editor editor;
  final String? noteId;
  final bool showRemove;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! QuietAttachmentNode) {
      return null;
    }

    return QuietAttachmentComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      uri: node.uri,
      displayText: node.displayText,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! QuietAttachmentComponentViewModel) {
      return null;
    }

    final node = editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! QuietAttachmentNode) {
      return null;
    }

    return QuietAttachmentComponent(
      key: ValueKey('quiet_attachment_${componentViewModel.nodeId}'),
      componentKey: componentContext.componentKey,
      node: node,
      editor: editor,
      noteId: noteId,
      showRemove: showRemove,
    );
  }
}

/// View model backing a [QuietAttachmentComponent].
class QuietAttachmentComponentViewModel extends SingleColumnLayoutComponentViewModel {
  QuietAttachmentComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.uri,
    required this.displayText,
  });

  String uri;
  String displayText;

  @override
  QuietAttachmentComponentViewModel copy() {
    return QuietAttachmentComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      uri: uri,
      displayText: displayText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietAttachmentComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          uri == other.uri &&
          displayText == other.displayText;

  @override
  int get hashCode => super.hashCode ^ nodeId.hashCode ^ uri.hashCode ^ displayText.hashCode;
}

/// A document component that renders a [QuietAttachmentNode] as an embedded
/// [QuietDocumentCard] or [QuietAttachmentCard]. Tapping the card opens it
/// (handled by the cards themselves); a small corner control removes the block
/// from the note.
class QuietAttachmentComponent extends StatelessWidget {
  const QuietAttachmentComponent({
    super.key,
    required this.componentKey,
    required this.node,
    required this.editor,
    this.noteId,
    this.showRemove = true,
  });

  final GlobalKey componentKey;
  final QuietAttachmentNode node;
  final Editor editor;
  final String? noteId;
  final bool showRemove;

  void _remove() {
    editor.execute([DeleteNodeRequest(nodeId: node.id)]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final qp = QuietPaperUri.tryParse(node.uri);

    final Widget card;
    if (qp != null && qp.isDocument) {
      card = QuietDocumentCard(
        documentId: qp.resourceId,
        title: node.displayText,
        uriString: node.uri,
      );
    } else if (qp != null && qp.isAsset) {
      card = QuietAttachmentCard(
        attachmentId: qp.resourceId,
        title: node.displayText,
        uriString: node.uri,
      );
    } else {
      card = _FallbackAttachmentCard(displayText: node.displayText, uri: node.uri);
    }

    return BoxComponent(
      key: componentKey,
      child: Stack(
        children: [
          card,
          if (showRemove)
            Positioned(
              top: 2,
              right: 4,
              child: Tooltip(
                message: 'Remove from note',
                child: Material(
                  color: colors.surface,
                  shape: CircleBorder(side: BorderSide(color: colors.divider, width: 0.8)),
                  elevation: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _remove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(PhosphorIconsRegular.x, size: 13, color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Minimal fallback card shown when a [QuietAttachmentNode]'s URI can't be
/// resolved to a known resource type.
class _FallbackAttachmentCard extends StatelessWidget {
  const _FallbackAttachmentCard({required this.displayText, required this.uri});

  final String displayText;
  final String uri;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.paperclip, size: 20, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayText.isNotEmpty ? displayText : uri,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Serializes a [QuietAttachmentNode] back to its canonical Markdown link form
/// (`[name](qp://...)`), guaranteeing a blank line before any following node so
/// the block round-trips cleanly through [deserializeMarkdownToDocument].
class QuietAttachmentNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<QuietAttachmentNode> {
  const QuietAttachmentNodeSerializer();

  @override
  String doSerialization(
    Document document,
    QuietAttachmentNode node, {
    NodeSelection? selection,
  }) {
    final buffer = StringBuffer('[${node.displayText}](${node.uri})');
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }
    return buffer.toString();
  }
}
