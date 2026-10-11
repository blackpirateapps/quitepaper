import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/utils/link_launcher_helper.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/link_preview_card.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:super_editor/super_editor.dart';

/// A block [DocumentNode] that embeds a baked web-link preview as a rich card
/// inside SuperEditor.
///
/// Like [QuietAttachmentNode], this node represents a *link-form* reference —
/// a standalone `[title](http(s)://…)` paragraph that was immediately followed
/// by a `qp-link-preview` sentinel comment — and serializes back to exactly
/// that two-line baked form (see [LinkPreviewNodeSerializer]), keeping the
/// persisted Markdown byte-compatible with the Markdown preview and the other
/// editor surfaces.
@immutable
class LinkPreviewNode extends BlockNode {
  LinkPreviewNode({
    required this.id,
    required this.url,
    required this.title,
    this.description,
    this.siteName,
    this.thumbnailAssetId,
    required this.fetchedAt,
    super.metadata,
  }) {
    initAddToMetadata({NodeMetadata.blockType: const NamedAttribution('linkPreview')});
  }

  @override
  final String id;

  /// The previewed web URL (the Markdown link target).
  final String url;

  /// Fetched page title (the Markdown link text).
  final String title;

  /// Optional fetched page description / summary.
  final String? description;

  /// Optional site / publisher name.
  final String? siteName;

  /// Optional full `qp://asset/<id>` reference to the baked thumbnail image.
  final String? thumbnailAssetId;

  /// Timestamp at which the preview metadata was fetched.
  final DateTime fetchedAt;

  /// Rebuilds the shared-domain [LinkPreviewBlock] model this node mirrors.
  LinkPreviewBlock toBlock() => LinkPreviewBlock(
        id: id,
        url: url,
        title: title,
        description: description,
        siteName: siteName,
        thumbnailAssetId: thumbnailAssetId,
        fetchedAt: fetchedAt,
      );

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception(
        'LinkPreviewNode can only copy content from a UpstreamDownstreamNodeSelection.',
      );
    }
    return !selection.isCollapsed ? '[$title]($url)' : null;
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is LinkPreviewNode &&
        url == other.url &&
        title == other.title &&
        description == other.description &&
        siteName == other.siteName &&
        thumbnailAssetId == other.thumbnailAssetId &&
        fetchedAt == other.fetchedAt;
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return LinkPreviewNode(
      id: id,
      url: url,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: fetchedAt,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return LinkPreviewNode(
      id: id,
      url: url,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: fetchedAt,
      metadata: newMetadata,
    );
  }

  LinkPreviewNode copy() {
    return LinkPreviewNode(
      id: id,
      url: url,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: fetchedAt,
      metadata: Map.from(metadata),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkPreviewNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          title == other.title &&
          description == other.description &&
          siteName == other.siteName &&
          thumbnailAssetId == other.thumbnailAssetId &&
          fetchedAt == other.fetchedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      url.hashCode ^
      title.hashCode ^
      (description?.hashCode ?? 0) ^
      (siteName?.hashCode ?? 0) ^
      (thumbnailAssetId?.hashCode ?? 0) ^
      fetchedAt.hashCode;
}

/// Block type ids that must never be promoted to a preview card even when their
/// text happens to be a single link (headings, quotes, code blocks).
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

/// Returns the sole whole-paragraph `http(s)://` link in [node], or `null` if
/// [node] is not a plain paragraph consisting of exactly one such link.
({String url, String title})? _soleHttpLinkOf(ParagraphNode node) {
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
  final uri = link.plainTextUri;
  if (!uri.startsWith('http://') && !uri.startsWith('https://')) return null;

  return (url: uri, title: plain);
}

/// Walks [document] with a two-node lookahead and replaces every standalone
/// `[title](http(s)://…)` paragraph that is *immediately* followed by a
/// `qp-link-preview` sentinel-comment paragraph with a single [LinkPreviewNode]
/// (decoded via [decodeLinkPreview]), removing the now-consumed comment node so
/// the sentinel never renders as text.
///
/// This runs regardless of the Smart Web Links toggle so the sentinel is always
/// consumed; the component decides whether to render a card or a plain link.
void promoteLinkPreviewNodes(MutableDocument document) {
  final nodes = document.toList();
  final swaps = <({String linkId, String commentId, LinkPreviewBlock block})>[];

  var i = 0;
  while (i < nodes.length - 1) {
    final node = nodes[i];
    final nextNode = nodes[i + 1];

    if (node is! ParagraphNode) {
      i++;
      continue;
    }
    final link = _soleHttpLinkOf(node);
    if (link == null) {
      i++;
      continue;
    }

    if (nextNode is! ParagraphNode ||
        !isLinkPreviewComment(nextNode.text.toPlainText().trim())) {
      i++;
      continue;
    }

    final decoded = decodeLinkPreview(
      linkLine: '[${link.title}](${link.url})',
      commentLine: nextNode.text.toPlainText().trim(),
      id: node.id,
    );
    if (decoded == null) {
      i++;
      continue;
    }

    swaps.add((linkId: node.id, commentId: nextNode.id, block: decoded));
    // Skip the consumed comment node.
    i += 2;
  }

  for (final swap in swaps) {
    final block = swap.block;
    document.replaceNodeById(
      swap.linkId,
      LinkPreviewNode(
        id: swap.linkId,
        url: block.url,
        title: block.title,
        description: block.description,
        siteName: block.siteName,
        thumbnailAssetId: block.thumbnailAssetId,
        fetchedAt: block.fetchedAt,
      ),
    );
    document.deleteNode(swap.commentId);
  }
}

/// [ComponentBuilder] that renders [LinkPreviewNode]s as embedded preview cards
/// with a "remove from note" affordance.
class LinkPreviewComponentBuilder implements ComponentBuilder {
  LinkPreviewComponentBuilder({
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
    if (node is! LinkPreviewNode) {
      return null;
    }

    return LinkPreviewComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      url: node.url,
      title: node.title,
      description: node.description,
      siteName: node.siteName,
      thumbnailAssetId: node.thumbnailAssetId,
      fetchedAt: node.fetchedAt,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! LinkPreviewComponentViewModel) {
      return null;
    }

    final node = editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! LinkPreviewNode) {
      return null;
    }

    return LinkPreviewComponent(
      key: ValueKey('quiet_link_preview_${componentViewModel.nodeId}'),
      componentKey: componentContext.componentKey,
      node: node,
      editor: editor,
      noteId: noteId,
      showRemove: showRemove,
    );
  }
}

/// View model backing a [LinkPreviewComponent].
class LinkPreviewComponentViewModel extends SingleColumnLayoutComponentViewModel {
  LinkPreviewComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required this.url,
    required this.title,
    this.description,
    this.siteName,
    this.thumbnailAssetId,
    required this.fetchedAt,
  });

  String url;
  String title;
  String? description;
  String? siteName;
  String? thumbnailAssetId;
  DateTime fetchedAt;

  @override
  LinkPreviewComponentViewModel copy() {
    return LinkPreviewComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      url: url,
      title: title,
      description: description,
      siteName: siteName,
      thumbnailAssetId: thumbnailAssetId,
      fetchedAt: fetchedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is LinkPreviewComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          url == other.url &&
          title == other.title &&
          description == other.description &&
          siteName == other.siteName &&
          thumbnailAssetId == other.thumbnailAssetId &&
          fetchedAt == other.fetchedAt;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      url.hashCode ^
      title.hashCode ^
      (description?.hashCode ?? 0) ^
      (siteName?.hashCode ?? 0) ^
      (thumbnailAssetId?.hashCode ?? 0) ^
      fetchedAt.hashCode;
}

/// A document component that renders a [LinkPreviewNode] as an embedded
/// [LinkPreviewCard] (when Smart Web Links are enabled) or a plain inline link
/// (when they are disabled). The card's whole-surface tap opens the link; its
/// overflow menu removes the node and tombstones the baked thumbnail.
class LinkPreviewComponent extends ConsumerWidget {
  const LinkPreviewComponent({
    super.key,
    required this.componentKey,
    required this.node,
    required this.editor,
    this.noteId,
    this.showRemove = true,
  });

  final GlobalKey componentKey;
  final LinkPreviewNode node;
  final Editor editor;
  final String? noteId;
  final bool showRemove;

  Future<void> _remove(WidgetRef ref) async {
    editor.execute([DeleteNodeRequest(nodeId: node.id)]);
    final assetUri = node.thumbnailAssetId;
    if (assetUri != null && assetUri.trim().isNotEmpty) {
      final id = QuietPaperUri.tryParse(assetUri)?.resourceId ??
          (assetUri.startsWith('qp://asset/')
              ? assetUri.substring('qp://asset/'.length)
              : null);
      if (id != null && id.isNotEmpty) {
        try {
          await ref.read(attachmentServiceProvider).deleteAttachment(id);
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartWebLinks = ref.watch(smartWebLinksProvider);

    final Widget child;
    if (!smartWebLinks) {
      final colors = context.appColors;
      final label = node.title.trim().isNotEmpty ? node.title.trim() : node.url;
      child = Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => LinkLauncherHelper.handleLinkTap(context, node.url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: colors.accent.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    } else {
      child = LinkPreviewCard(
        block: node.toBlock(),
        readOnly: !showRemove,
        onRemove: showRemove ? () => _remove(ref) : null,
      );
    }

    return BoxComponent(
      key: componentKey,
      child: child,
    );
  }
}

/// Serializes a [LinkPreviewNode] back to its canonical two-line baked form —
/// the visible Markdown link (`[title](url)`) followed by the `qp-link-preview`
/// sentinel comment — guaranteeing a blank line before any following node so
/// the block round-trips cleanly through [deserializeMarkdownToDocument].
class LinkPreviewNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<LinkPreviewNode> {
  const LinkPreviewNodeSerializer();

  @override
  String doSerialization(
    Document document,
    LinkPreviewNode node, {
    NodeSelection? selection,
  }) {
    final buffer = StringBuffer('[${node.title}](${node.url})');
    buffer.writeln();
    buffer.write(encodeLinkPreviewComment(node.toBlock()));
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }
    return buffer.toString();
  }
}


