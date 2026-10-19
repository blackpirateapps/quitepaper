import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/utils/link_launcher_helper.dart';
import 'package:quitepaper/core/web_clipper/link_fetch_diagnostics.dart';
import 'package:quitepaper/core/web_clipper/link_preview_baker.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/link_preview_card.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:super_editor/super_editor.dart';

import 'link_preview_debug_card.dart';
import 'link_preview_loading_card.dart';

/// The lifecycle state of a web link preview embedded inside SuperEditor.
enum LinkPreviewStatus {
  /// The preview was successfully baked and contains rich card metadata.
  loaded,

  /// The preview's description, metadata, or thumbnail is currently being fetched.
  loading,

  /// The preview fetch failed; holds detailed [LinkFetchDiagnostics].
  failed,
}

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
    this.status = LinkPreviewStatus.loaded,
    this.diagnostics,
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

  /// The current resolution status of this preview (loaded, loading, failed).
  final LinkPreviewStatus status;

  /// Detailed telemetry explaining why link fetching failed, if [status] == [LinkPreviewStatus.failed].
  final LinkFetchDiagnostics? diagnostics;

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

  LinkPreviewNode copyWith({
    String? id,
    String? url,
    String? title,
    String? description,
    String? siteName,
    String? thumbnailAssetId,
    DateTime? fetchedAt,
    LinkPreviewStatus? status,
    LinkFetchDiagnostics? diagnostics,
    bool clearDiagnostics = false,
    Map<String, dynamic>? metadata,
  }) {
    return LinkPreviewNode(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      siteName: siteName ?? this.siteName,
      thumbnailAssetId: thumbnailAssetId ?? this.thumbnailAssetId,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      status: status ?? this.status,
      diagnostics: clearDiagnostics ? null : (diagnostics ?? this.diagnostics),
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

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
        fetchedAt == other.fetchedAt &&
        status == other.status &&
        diagnostics == other.diagnostics;
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
      status: status,
      diagnostics: diagnostics,
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
      status: status,
      diagnostics: diagnostics,
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
      status: status,
      diagnostics: diagnostics,
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
          fetchedAt == other.fetchedAt &&
          status == other.status &&
          diagnostics == other.diagnostics;

  @override
  int get hashCode =>
      id.hashCode ^
      url.hashCode ^
      title.hashCode ^
      (description?.hashCode ?? 0) ^
      (siteName?.hashCode ?? 0) ^
      (thumbnailAssetId?.hashCode ?? 0) ^
      fetchedAt.hashCode ^
      status.hashCode ^
      (diagnostics?.hashCode ?? 0);
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
  final trimmed = plain.trim();
  if (trimmed.isEmpty) return null;

  final spans = node.text.getAttributionSpansByFilter((a) => a is LinkAttribution);
  if (spans.length != 1) return null;

  final span = spans.first;
  // The link must cover the whole paragraph (or the trimmed text).
  final startOffset = plain.indexOf(trimmed);
  final endOffset = startOffset + trimmed.length - 1;
  final coversAll = (span.start == 0 && span.end == plain.length - 1) ||
      (span.start == startOffset && span.end == endOffset);
  if (!coversAll) return null;

  final link = span.attribution as LinkAttribution;
  final uri = link.plainTextUri;
  if (!uri.startsWith('http://') && !uri.startsWith('https://')) return null;

  return (url: uri, title: trimmed);
}

/// Walks [document] with a two-node lookahead and replaces every standalone
/// `[title](http(s)://…)` paragraph that is *immediately* followed by a
/// `qp-link-preview` sentinel-comment paragraph with a single [LinkPreviewNode]
/// (decoded via [decodeLinkPreview]), removing the now-consumed comment node so
/// the sentinel never renders as text.
///
/// If [promoteUnbaked] is true, standalone lone-line web URLs without a sentinel
/// comment are also promoted to a [LinkPreviewNode] in [LinkPreviewStatus.loading]
/// state so the loading animation can display while metadata is fetched.
void promoteLinkPreviewNodes(MutableDocument document, {bool promoteUnbaked = false}) {
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

  // Defensively remove any orphan sentinel comments so raw JSON is never shown.
  for (final node in document.toList()) {
    if (node is ParagraphNode && isLinkPreviewComment(node.text.toPlainText().trim())) {
      document.deleteNode(node.id);
    }
  }

  if (promoteUnbaked) {
    for (final node in document.toList()) {
      if (node is! ParagraphNode) continue;
      final link = _soleHttpLinkOf(node);
      if (link == null) continue;

      document.replaceNodeById(
        node.id,
        LinkPreviewNode(
          id: node.id,
          url: link.url,
          title: link.title,
          fetchedAt: DateTime.now(),
          status: LinkPreviewStatus.loading,
        ),
      );
    }
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
      status: node.status,
      diagnostics: node.diagnostics,
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
    this.status = LinkPreviewStatus.loaded,
    this.diagnostics,
  });

  String url;
  String title;
  String? description;
  String? siteName;
  String? thumbnailAssetId;
  DateTime fetchedAt;
  LinkPreviewStatus status;
  LinkFetchDiagnostics? diagnostics;

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
      status: status,
      diagnostics: diagnostics,
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
          fetchedAt == other.fetchedAt &&
          status == other.status &&
          diagnostics == other.diagnostics;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      url.hashCode ^
      title.hashCode ^
      (description?.hashCode ?? 0) ^
      (siteName?.hashCode ?? 0) ^
      (thumbnailAssetId?.hashCode ?? 0) ^
      fetchedAt.hashCode ^
      status.hashCode ^
      (diagnostics?.hashCode ?? 0);
}

/// A document component that renders a [LinkPreviewNode] as an embedded
/// [LinkPreviewCard] (when loaded), an animated [LinkPreviewLoadingCard] (when loading),
/// a detailed [LinkPreviewDebugCard] (when failed and debug setting is enabled),
/// or a calm inline link (when Smart Web Links or debug mode is disabled).
class LinkPreviewComponent extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<LinkPreviewComponent> createState() =>
      _LinkPreviewComponentState();
}

class _LinkPreviewComponentState extends ConsumerState<LinkPreviewComponent> {
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    if (widget.node.status == LinkPreviewStatus.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _executeFetch());
    }
  }

  @override
  void didUpdateWidget(LinkPreviewComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.status == LinkPreviewStatus.loading &&
        (oldWidget.node.status != LinkPreviewStatus.loading ||
            oldWidget.node.url != widget.node.url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _executeFetch());
    }
  }

  Future<void> _executeFetch() async {
    if (!ref.read(smartWebLinksProvider)) return;
    if (_isFetching) return;
    _isFetching = true;

    try {
      final baker = ref.read(linkPreviewBakerProvider);
      final result = await baker.bakeUrlWithDiagnostics(
        widget.node.url,
        noteId: widget.noteId,
      );

      if (!mounted) return;
      if (widget.editor.document.getNodeById(widget.node.id) == null) return;

      if (result.isSuccess && result.block != null) {
        final block = result.block!;
        final oldThumb = widget.node.thumbnailAssetId;
        if (oldThumb != null && oldThumb != block.thumbnailAssetId) {
          _tombstoneAsset(oldThumb);
        }

        final successNode = widget.node.copyWith(
          title: block.title,
          description: block.description,
          siteName: block.siteName,
          thumbnailAssetId: block.thumbnailAssetId,
          fetchedAt: block.fetchedAt,
          status: LinkPreviewStatus.loaded,
          diagnostics: result.diagnostics,
        );

        widget.editor.execute([
          ReplaceNodeRequest(
            existingNodeId: widget.node.id,
            newNode: successNode,
          ),
        ]);
      } else {
        final failedNode = widget.node.copyWith(
          status: LinkPreviewStatus.failed,
          diagnostics: result.diagnostics,
        );

        widget.editor.execute([
          ReplaceNodeRequest(
            existingNodeId: widget.node.id,
            newNode: failedNode,
          ),
        ]);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _triggerRefresh() async {
    final loadingNode = widget.node.copyWith(
      status: LinkPreviewStatus.loading,
      clearDiagnostics: true,
    );

    widget.editor.execute([
      ReplaceNodeRequest(
        existingNodeId: widget.node.id,
        newNode: loadingNode,
      ),
    ]);
  }

  Future<void> _tombstoneAsset(String? assetUri) async {
    if (assetUri == null || assetUri.trim().isEmpty) return;
    final id = QuietPaperUri.tryParse(assetUri)?.resourceId ??
        (assetUri.startsWith('qp://asset/')
            ? assetUri.substring('qp://asset/'.length)
            : null);
    if (id != null && id.isNotEmpty) {
      try {
        await ref.read(attachmentServiceProvider).deleteAttachment(id);
      } catch (_) {}
    }
  }

  Future<void> _remove() async {
    widget.editor.execute([DeleteNodeRequest(nodeId: widget.node.id)]);
    await _tombstoneAsset(widget.node.thumbnailAssetId);
  }

  void _convertToPlainLink() {
    final text = widget.node.title.isNotEmpty ? widget.node.title : widget.node.url;
    final paragraphNode = ParagraphNode(
      id: widget.node.id,
      text: AttributedText(
        text,
        AttributedSpans(
          attributions: [
            SpanMarker(
              attribution: LinkAttribution.fromUri(Uri.parse(widget.node.url)),
              offset: 0,
              markerType: SpanMarkerType.start,
            ),
            SpanMarker(
              attribution: LinkAttribution.fromUri(Uri.parse(widget.node.url)),
              offset: text.length - 1,
              markerType: SpanMarkerType.end,
            ),
          ],
        ),
      ),
    );
    widget.editor.execute([
      ReplaceNodeRequest(
        existingNodeId: widget.node.id,
        newNode: paragraphNode,
      ),
    ]);
  }

  Widget _buildPlainLink(BuildContext context, AppColors colors) {
    final label = widget.node.title.trim().isNotEmpty
        ? widget.node.title.trim()
        : widget.node.url;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => LinkLauncherHelper.handleLinkTap(context, widget.node.url),
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
  }

  @override
  Widget build(BuildContext context) {
    final smartWebLinks = ref.watch(smartWebLinksProvider);
    final colors = context.appColors;

    final Widget child;
    if (!smartWebLinks) {
      child = _buildPlainLink(context, colors);
    } else if (widget.node.status == LinkPreviewStatus.loading) {
      child = LinkPreviewLoadingCard(
        url: widget.node.url,
        title: widget.node.title,
      );
    } else if (widget.node.status == LinkPreviewStatus.failed) {
      final debugEnabled = ref.watch(linkPreviewDebugProvider);
      if (debugEnabled && widget.node.diagnostics != null) {
        child = LinkPreviewDebugCard(
          diagnostics: widget.node.diagnostics!,
          onRetry: _triggerRefresh,
          onConvertToLink: _convertToPlainLink,
          onRemove: widget.showRemove ? _remove : null,
        );
      } else {
        child = _buildPlainLink(context, colors);
      }
    } else {
      child = LinkPreviewCard(
        block: widget.node.toBlock(),
        readOnly: !widget.showRemove,
        onRemove: widget.showRemove ? _remove : null,
        onRefresh: _triggerRefresh,
      );
    }

    return BoxComponent(
      key: widget.componentKey,
      child: child,
    );
  }
}

/// Serializes a [LinkPreviewNode] back to its canonical two-line baked form —
/// the visible Markdown link (`[title](url)`) followed by the `qp-link-preview`
/// sentinel comment. If the preview is still loading or failed, it serializes
/// as a plain link without the sentinel comment to preserve pristine markdown.
class LinkPreviewNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<LinkPreviewNode> {
  const LinkPreviewNodeSerializer();

  @override
  String doSerialization(
    Document document,
    LinkPreviewNode node, {
    NodeSelection? selection,
  }) {
    if (node.status != LinkPreviewStatus.loaded) {
      final text = node.title.isNotEmpty ? node.title : node.url;
      final buffer = StringBuffer('[$text](${node.url})');
      final nodeIndex = document.getNodeIndexById(node.id);
      if (nodeIndex != document.nodeCount - 1) {
        buffer.writeln();
        buffer.writeln();
      }
      return buffer.toString();
    }

    final buffer = StringBuffer('[${node.title}](${node.url})');
    buffer.writeln();
    buffer.write(encodeLinkPreviewComment(node.toBlock()));
    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }
}


